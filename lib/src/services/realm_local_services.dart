import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:E3InspectionsMultiTenant/src/services/sync_service.dart';
import 'package:get/utils.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:realm/realm.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
//import 'package:E3InspectionsMultiTenant/src/services/change_tracker.dart';
//import 'package:wakelock_plus/wakelock_plus.dart';
import '../bloc/images_bloc.dart';
//import '../bloc/notificationcontroller.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/users_bloc.dart';
import '../models/exteriorelements.dart';
import '../models/realm/realm_schemas.dart';
import '../models/success_response.dart';
import '../ui/section.dart';

class RealmLocalServices with ChangeNotifier {
  late Realm realm;
  bool showAll = true;
  static bool offlineModeOn = false;
  bool isWaiting = false;
  String loggedInUser;
  String company;
  SyncService syncService;
  StreamSubscription? _channelSubscription;
  WebSocketChannel? _currentChannel;
  //ChangeTracker? changeTracker;

  // Message queue for handling multiple server messages
  final List<Map<String, dynamic>> _messageQueue = [];
  final List<Map<String, dynamic>> _failedMessages = [];
  bool _isProcessingQueue = false;
  int _maxRetries = 3;

  final Map<String, Map<String, dynamic>> _pendingOutgoing = {};
  final Map<String, Timer> _debounceTimers = {};
  final Duration _debounceDuration = Duration(milliseconds: 500);

  // Queue to serialize unsynced-data Realm writes and avoid lost updates
  final List<Map<String, dynamic>> _unsyncedQueue = [];
  bool _isProcessingUnsyncedQueue = false;

  RealmLocalServices(this.loggedInUser, this.company, this.syncService) {
    SharedPreferences.getInstance().then((value) {
      var configValue = value.getString('appSync') ?? 'true';
      if (configValue == 'false') {
        offlineModeOn = true;
      } else {
        offlineModeOn = false;
      }
    });

    realm = Realm(
      Configuration.local([
        Project.schema,
        Child.schema,
        SubProject.schema,
        Location.schema,
        Section.schema,
        VisualSection.schema,
        DeckImage.schema,
        InvasiveSection.schema,
        ConclusiveSection.schema,
        LocationForm.schema,
        DynamicVisualSection.schema,
        Question.schema,
        UnsyncedData.schema,
      ]),
    );
    debugPrint("Realm database path: ${realm.config.path}");
    // Prepare change tracker (start when listenForRealmChanges is called)
    // changeTracker = ChangeTracker(realm, syncService);
    // listenForRealmChanges();
  }
  void registerToChannelStream(WebSocketChannel channel) {
    // Only listen if this is a new channel
    if (_currentChannel == channel && _channelSubscription != null) {
      debugPrint("Already listening to this channel stream.");
      return;
    }
    // Cancel previous subscription if exists
    _channelSubscription?.cancel();
    _currentChannel = channel;

    _channelSubscription = channel.stream.listen(
      (message) {
        debugPrint("Received message: $message");
        final response = jsonDecode(message);
        final messageId = response['messageId'] as String;

        if (response['status'] == 'success') {
          //remove from the unsynced datas
          final existingData = realm.find<UnsyncedData>(
            ObjectId.fromHexString(messageId),
          );
          if (existingData != null) {
            realm.write(() {
              realm.delete(existingData);
            });
          }
        } else if (response['servermessage'] == 'sync_ack') {
          final List syncedIds = response['syncedIds'];
          realm.write(() {
            for (final id in syncedIds) {
              final entry = realm.find<UnsyncedData>(
                ObjectId.fromHexString(id),
              );
              if (entry != null) realm.delete(entry);
            }
          });
          debugPrint('🗑️ Deleted synced entries from Realm.');
        } else if (response['servermessage'] == 'sync_with_server') {
          // Queue the message for processing instead of processing immediately
          _queueServerMessage(response);
        } else {
          debugPrint("Failed to sync object: ${response['message']}");
          //add this to unsynced data
          final failedData = syncService.pendingMessages[messageId];
          if (failedData != null) {
            //saveUnsyncedData(jsonDecode(failedData));
          }
        }
        syncService.pendingMessages.remove(messageId);
      },
      onError: (error) {
        // If needed, retry everything in pendingMessages
        for (final data in syncService.pendingMessages.values) {
          //saveUnsyncedData(jsonDecode(data));
        }
        syncService.pendingMessages.clear();
      },
      onDone: () {
        debugPrint("WebSocket connection closed");
        syncService.isWebSocketConnected = false;
      },
      cancelOnError: true, // Ensure subscription is cancelled on error
    );
  }

  // Queue server messages for asynchronous processing
  void _queueServerMessage(Map<String, dynamic> message) {
    // Add timestamp for monitoring
    message['timestamp'] = DateTime.now().millisecondsSinceEpoch;
    message['queuedAt'] = DateTime.now().toIso8601String();

    _messageQueue.add(message);
    debugPrint(
      "Queued message ${message['messageId']}, queue size: ${_messageQueue.length}",
    );

    // Start processing if not already processing
    if (!_isProcessingQueue) {
      _processMessageQueue();
    }
  }

  // Process messages from queue asynchronously
  Future<void> _processMessageQueue() async {
    if (_isProcessingQueue) return;

    _isProcessingQueue = true;
    debugPrint("Started processing message queue");

    try {
      while (_messageQueue.isNotEmpty) {
        // Pop the next message, but if it's an update/replace and there is
        // a pending create/insert for the same messageId later in the queue,
        // process the create first to ensure objects exist before updates.
        var message = _messageQueue.removeAt(0);

        // If this is an update/replace, check for a create/insert for same id
        final action = (message['action'] ?? '').toString();
        if (action == 'update' || action == 'replace') {
          final sameCreateIndex = _messageQueue.indexWhere((m) {
            final a = (m['action'] ?? '').toString();
            return (a == 'insert' || a == 'create') &&
                m['messageId'] == message['messageId'];
          });
          if (sameCreateIndex != -1) {
            // re-enqueue the update at the end and pull the create to process now
            _messageQueue.add(message);
            message = _messageQueue.removeAt(sameCreateIndex);
          }
        }

        debugPrint(
          "Processing message ${message['messageId']}, remaining: ${_messageQueue.length}",
        );

        try {
          // Process message asynchronously
          await _processServerMessage(message);
        } catch (e) {
          debugPrint("Error processing message ${message['messageId']}: $e");
          // Continue processing other messages even if one fails
        }

        // Small delay to prevent blocking the UI thread
        await Future.delayed(const Duration(milliseconds: 1));
      }
    } finally {
      _isProcessingQueue = false;
      debugPrint("Finished processing message queue");
    }
  }

  // Process individual server message asynchronously
  Future<void> _processServerMessage(Map<String, dynamic> message) async {
    final collectionName = message['collectionName'];
    final messageId = message['messageId'];
    final action = message['action'];
    final fullDocument = message['fullDocument'];
    final updateDescription = message['updateDescription'];
    final redisEntryId = message['redisEntryId'];

    if (messageId == null) {
      debugPrint("Message ID is null, skipping update");
      return;
    }

    debugPrint(
      "Processing: Collection=$collectionName, Action=$action, ID=$messageId",
    );

    try {
      switch (action) {
        case 'insert':
          await _handleInsertAsync(collectionName, fullDocument);
          break;
        case 'update':
        case 'replace':
          await _handleUpdateAsync(
            collectionName,
            messageId,
            updateDescription,
            fullDocument,
          );
          break;
        case 'delete':
          await _handleDeleteAsync(collectionName, messageId);
          break;
        default:
          debugPrint("Unknown action: $action");
          // Send negative ACK for unknown actions
          _sendAcknowledgment(redisEntryId, false, "Unknown action: $action");
          return;
      }

      // Send positive ACK after successful processing
      _sendAcknowledgment(redisEntryId, true, null);
    } catch (e) {
      debugPrint("Error processing server message: $e");
      // Send negative ACK for processing errors
      // _sendAcknowledgment(redisEntryId, false, e.toString());
      // rethrow;
    }
  }

  // Send acknowledgment back to server after message processing
  void _sendAcknowledgment(String redisEntryId, bool success, String? error) {
    try {
      final ackData = {
        'type': 'ack',
        'redisEntryId': redisEntryId,
        'companyIdentifier': usersBloc.userDetails.companyidentifer,
        'success': success,
        'timestamp': DateTime.now().toIso8601String(),
        if (error != null) 'error': error,
      };

      // Use the existing WebSocket channel to send ACK
      if (_currentChannel != null) {
        _currentChannel!.sink.add(jsonEncode(ackData));
        debugPrint(
          "✅ ACK sent for redis entryId $redisEntryId: success=$success",
        );
        if (error != null) {
          debugPrint("❌ ACK error details: $error");
        }
      } else {
        debugPrint(
          "⚠️ Cannot send ACK - WebSocket channel is null for message $redisEntryId",
        );
      }
    } catch (e) {
      debugPrint(
        "💥 Error sending acknowledgment for message $redisEntryId: $e",
      );
    }
  }

  // Get acknowledgment status for monitoring
  Map<String, dynamic> getAcknowledgmentStatus() {
    return {
      'webSocketConnected': _currentChannel != null,
      'messageQueueSize': _messageQueue.length,
      'isProcessingQueue': _isProcessingQueue,
      'lastProcessedAt': DateTime.now().toIso8601String(),
    };
  }

  // Manual acknowledgment method for special cases
  void sendManualAcknowledgment(String messageId, bool success, String? error) {
    _sendAcknowledgment(messageId, success, error);
  }

  void syncUnsyncedData() async {
    try {
      // Sort unsynced data by Realm insertion order (oldest first)
      final unsyncedList =
          realm.all<UnsyncedData>().toList()
            ..sort((a, b) => a.id.toString().compareTo(b.id.toString()));

      if (unsyncedList.isEmpty) {
        debugPrint('✅ No unsynced data to sync.');
        return;
      }
      for (var item in unsyncedList) {
        debugPrint('📤 Sent ${item.id} unsynced record over socket.');
        final dataMap = jsonDecode(item.jsonData);
        pushToWebSocket(
          item.action,
          item.collectionName,
          dataMap,
          addToDb: false,
        );
      }
    } catch (e) {
      debugPrint('❌ Error syncing unsynced data: $e');
    }
  }

  // Helper method to convert objects to JSON
  Map<String, dynamic> _toJson(dynamic object) {
    if (object is Project ||
        object is SubProject ||
        object is Location ||
        object is VisualSection ||
        object is InvasiveSection ||
        object is ConclusiveSection ||
        object is DeckImage ||
        object is DynamicVisualSection ||
        object is LocationForm) {
      return object.toJson();
    }
    throw UnsupportedError('Unsupported object type: ${object.runtimeType}');
  }

  void createProject(Project project) {
    try {
      var creationtime = DateTime.now().toString();
      project.createdat = creationtime;
      realm.write<Project>(() => realm.add<Project>(project));
      pushToWebSocket('create', 'project', _toJson(project));
      notifyListeners();
    } catch (e) {
      //handle the exception
    }
  }

  String deleteProject(Project project) {
    try {
      var projData = project.toJson();
      realm.write(() => realm.delete(project));
      notifyListeners();
      pushToWebSocket('delete', 'project', projData, isDelete: true);
      return 'success';
    } catch (e) {
      return 'failed';
    }
  }

  Project? getProject(ObjectId id) {
    var project = realm.find<Project>(id);
    currentFormId = project!.formId;
    debugPrint(currentFormId.toString());
    return project;
  }

  ObjectId? currentFormId;
  LocationForm? getCurrentForm() {
    return realm.find<LocationForm>(currentFormId);
  }

  RealmResults<LocationForm> getAllForms() {
    return realm.all<LocationForm>();
  }

  bool updateProjectUrl(Project project, String url) {
    try {
      if (offlineModeOn || !appSettings.activeConnection) {
        DeckImage image = DeckImage(
          ObjectId(),
          url,
          '',
          false,
          project.id,
          'project',
          'projectimage',
          project.name as String,
          usersBloc.userDetails.username as String,
          company,
        );
        realm.write(() {
          realm.add<DeckImage>(image, update: true);
        });
      }
      realm.write(() {
        project.url = url;
      });
      //push to websocket
      pushToWebSocket('updateImageUrl', 'project', {
        "id": project.id.hexString,
        "url": url,
        "companyIdentifier": usersBloc.userDetails.companyidentifer,
      });
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  bool addupdateProject(
    Project project,
    String name,
    String address,
    String description,
    String userName,
    double longitude,
    double lattitude,
    ObjectId? formId,
    bool isNewProject,
  ) {
    try {
      if (loggedInUser == "") {
        loggedInUser = usersBloc.userDetails.username as String;
      }
      var creationtime = DateTime.now().toString();

      realm.write<Project>(() {
        project.latitude = lattitude;
        project.longitude = longitude;
        project.name = name;
        if (isNewProject) {
          project.formId = formId;
        }
        project.companyIdentifier =
            usersBloc.userDetails.companyidentifer as String;
        project.address = address;
        project.description = description;
        if (isNewProject) {
          project.createdby = loggedInUser;
          project.assignedto.add(loggedInUser);
        } else {
          project.lasteditedby = userName;
        }

        project.createdat ??= creationtime;
        project.editedat = DateTime.now().toString();

        return realm.add<Project>(project, update: true);
      });
      notifyListeners();
      if (isNewProject) {
        pushToWebSocket('create', 'project', _toJson(project));
      } else {
        pushToWebSocket('update', 'project', _toJson(project));
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  //Update Project Children data
  void updateProjectChildren(
    ObjectId childId,
    ObjectId parentId,
    bool isInvasive,
    String name,
    String type,
    String description,
  ) {
    var parentProject = realm.find<Project>(parentId);

    if (parentProject != null) {
      parentProject.isInvasive = isInvasive;
      var found = parentProject.children.where(
        (element) => element.id == childId,
      );
      if (found.isEmpty) {
        parentProject.children.add(
          Child(
            childId,
            isInvasive,
            name: name,
            type: type,
            description: description,
            url: "",
          ),
        );
      } else {
        var foundChild = found.first;
        foundChild.name = name;
        foundChild.description = description;
        foundChild.isInvasive = isInvasive;
      }
    }
  }

  void deleteProjectChildren(ObjectId childId, ObjectId parentId) {
    var parentProject = realm.find<Project>(parentId);
    if (parentProject != null) {
      var foundChild = parentProject.children.firstWhere(
        (element) => element.id == childId,
      );
      parentProject.children.remove(foundChild);
    }
  }

  void updateChildUrl(ObjectId childId, ObjectId parentId, String url) {
    var parentProject = realm.find<Project>(parentId);
    try {
      if (parentProject != null) {
        var found = parentProject.children.where(
          (element) => element.id == childId,
        );

        var foundChild = found.first;

        foundChild.url = url;
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  bool updateAssignment(ObjectId projectId, List<String> assignees) {
    try {
      var foundProject = realm.find<Project>(projectId);
      if (foundProject != null) {
        realm.write(() {
          foundProject.assignedto.clear();
          foundProject.assignedto.addAll(assignees);
        });

        pushToWebSocket('update', 'project', {
          "id": projectId.hexString,
          "assignedto": assignees,
        });
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  //Update SubProject Children data
  void updateSubProjectChildren(
    ObjectId childId,
    ObjectId parentId,
    bool isInvasive,
    String name,
    String type,
    String description,
  ) {
    var parentProject = realm.find<SubProject>(parentId);

    if (parentProject != null) {
      var found = parentProject.children.where(
        (element) => element.id == childId,
      );
      if (found.isEmpty) {
        parentProject.children.add(
          Child(
            childId,
            isInvasive,
            name: name,
            type: type,
            description: description,
            url: "",
          ),
        );
      } else {
        var foundChild = found.first;
        foundChild.name = name;
        foundChild.description = description;
      }
    }
  }

  void deleteSubProjectChildren(ObjectId childId, ObjectId parentId) {
    var parentProject = realm.find<SubProject>(parentId);
    if (parentProject != null) {
      var foundChild = parentProject.children.firstWhere(
        (element) => element.id == childId,
      );
      parentProject.children.remove(foundChild);
    }
  }

  void updateSubChildUrl(ObjectId childId, ObjectId parentId, String url) {
    var parentProject = realm.find<SubProject>(parentId);
    if (parentProject != null) {
      var found = parentProject.children.where(
        (element) => element.id == childId,
      );

      var foundChild = found.first;

      foundChild.url = url;
    }
  }

  //Sub-projects
  void createSubProject(SubProject subProject) {
    try {
      var creationtime = DateTime.now().toString();
      subProject.createdat ??= creationtime;

      realm.write<SubProject>(() => realm.add<SubProject>(subProject));
      notifyListeners();
    } catch (e) {
      //handle the exception
    }
  }

  String deleteSubProject(SubProject subProject) {
    try {
      var subProjData = subProject.toJson();
      realm.write(() {
        deleteProjectChildren(subProject.id, subProject.parentid);
        realm.delete(subProject);
      });
      notifyListeners();
      pushToWebSocket('delete', 'subProject', subProjData, isDelete: true);
      return 'success';
    } catch (e) {
      return 'failed';
    }
  }

  SubProject? getSubProject(ObjectId id) {
    return realm.find<SubProject>(id);
  }

  bool updateSubProjectUrl(SubProject subProject, String url) {
    try {
      if (offlineModeOn || !appSettings.activeConnection) {
        DeckImage image = DeckImage(
          ObjectId(),
          url,
          '',
          false,
          subProject.id,
          'subProject',
          'subProjectimage',
          subProject.name as String,
          usersBloc.userDetails.username as String,
          company,
        );
        realm.write(() {
          realm.add<DeckImage>(image, update: true);
        });
      }
      realm.write(() {
        updateChildUrl(subProject.id, subProject.parentid, url);
        subProject.url = url;
      });

      notifyListeners();
      pushToWebSocket('updateImageUrl', 'subProject', {
        "id": subProject.id.hexString,
        "url": url,
        "companyIdentifier": usersBloc.userDetails.companyidentifer,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  bool addupdateSubProject(
    SubProject subProject,
    String name,
    String description,
    bool isNewBuilding,
    String fullUserName,
  ) {
    try {
      var creationtime = DateTime.now().toString();

      realm.write(() {
        subProject.name = name;

        subProject.description = description;
        if (isNewBuilding) {
          subProject.createdby = fullUserName;
          subProject.assignedto.add(loggedInUser);
        } else {
          subProject.lasteditedby = fullUserName;
        }
        subProject.createdat ??= creationtime;
        subProject.editedat = DateTime.now().toString();

        //find the project and update it.
        updateProjectChildren(
          subProject.id,
          subProject.parentid,
          subProject.isInvasive,
          subProject.name as String,
          subProject.type as String,
          subProject.description as String,
        );
        realm.add<SubProject>(subProject, update: true);
        if (isNewBuilding) {
          pushToWebSocket('create', 'subProject', _toJson(subProject));
        } else {
          pushToWebSocket('update', 'subProject', _toJson(subProject));
        }
      });
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  //Locations
  void createLocation(Location location) {
    try {
      realm.write<Location>(() => realm.add<Location>(location));
      //notifyListeners();
    } catch (e) {
      //handle the exception
    }
  }

  bool updateLocationUrl(Location currentLocation, String url) {
    try {
      if (offlineModeOn || !appSettings.activeConnection) {
        DeckImage image = DeckImage(
          ObjectId(),
          url,
          '',
          false,
          currentLocation.id,
          'location',
          'locationImage',
          currentLocation.name as String,
          usersBloc.userDetails.username as String,
          company,
        );
        realm.write(() {
          realm.add<DeckImage>(image, update: true);
        });
      }
      realm.write(() {
        if (currentLocation.type == 'projectlocation') {
          updateChildUrl(currentLocation.id, currentLocation.parentid, url);
        } else {
          updateSubChildUrl(currentLocation.id, currentLocation.parentid, url);
        }
        currentLocation.url = url;
      });

      notifyListeners();
      pushToWebSocket('updateImageUrl', 'location', {
        "id": currentLocation.id.hexString,
        "url": url,
        "companyIdentifier": usersBloc.userDetails.companyidentifer,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  String deleteLocation(Location location) {
    try {
      var locationData = location.toJson();
      realm.write(() {
        if (location.parenttype == 'project') {
          deleteProjectChildren(location.id, location.parentid);
        } else {
          deleteSubProjectChildren(location.id, location.parentid);
        }

        realm.delete(location);
        pushToWebSocket('delete', 'location', locationData, isDelete: true);
      });
      //notifyListeners();
      return 'success';
    } catch (e) {
      return 'failed';
    }
  }

  Location? getLocation(ObjectId id) {
    // if (appSettings.activeConnection) {
    //   uploadImages();
    // }
    return realm.find<Location>(id);
  }

  bool addupdateLocation(
    Location location,
    String name,
    String description,
    String fullUserName,
    bool isNewLocation,
  ) {
    try {
      var creationtime = DateTime.now().toString();

      realm.write(() {
        location.name = name;
        location.description = description;
        if (isNewLocation) {
          location.createdby = fullUserName;
        } else {
          location.lasteditedby = fullUserName;
        }
        location.createdat ??= creationtime;
        location.editedat = DateTime.now().toString();

        //find the project and update it.
        if (location.parenttype == 'project') {
          updateProjectChildren(
            location.id,
            location.parentid,
            location.isInvasive,
            location.name as String,
            location.type as String,
            location.description as String,
          );
        } else {
          updateSubProjectChildren(
            location.id,
            location.parentid,
            location.isInvasive,
            location.name as String,
            location.type as String,
            location.description as String,
          );
        }
        realm.add<Location>(location, update: true);
      });
      if (isNewLocation) {
        pushToWebSocket('create', 'location', _toJson(location));
      } else {
        pushToWebSocket('update', 'location', _toJson(location));
      }
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }

    //notifyListeners();
  }

  //Visual Sections
  void createVisualSection(VisualSection visualSection) {
    try {
      var creationtime = DateTime.now().toString();
      visualSection.createdat ??= creationtime;

      realm.write<VisualSection>(() => realm.add<VisualSection>(visualSection));
      notifyListeners();
    } catch (e) {
      //handle the exception
    }
  }

  String deleteVisualSection(VisualSection section) {
    try {
      var sectionData = section.toJson();
      realm.write(() {
        deleteLocationSection(
          section.parenttype,
          section.id,
          section.parentid,
          false,
        );
        realm.delete(section);
      });
      notifyListeners();
      pushToWebSocket('delete', 'visualSection', sectionData, isDelete: true);
      return 'success';
    } catch (e) {
      return 'failed';
    }
  }

  String deleteVisualSectionDynamic(DynamicVisualSection section) {
    try {
      var sectionData = section.toJson();
      realm.write(() {
        deleteLocationSection(
          section.parenttype,
          section.id,
          section.parentid,
          false,
        );
        realm.delete(section);
      });
      notifyListeners();
      pushToWebSocket('delete', 'dynamicSection', sectionData, isDelete: true);
      return 'success';
    } catch (e) {
      return 'failed';
    }
  }

  VisualSection? getVisualSection(ObjectId id) {
    return realm.find<VisualSection>(id);
  }

  DynamicVisualSection? getDynamicVisualSection(ObjectId id) {
    return realm.find<DynamicVisualSection>(id);
  }

  void updateImageUploadStatus(
    Location parentLocation,
    ObjectId sectionId,
    bool status,
  ) {
    var found = parentLocation.sections.where(
      (element) => element.id == sectionId,
    );
    if (found.isNotEmpty) {
      realm.write(() => found.first.isuploading = status);
    }
    notifyListeners();
  }

  bool addupdateVisualSection(
    VisualSection visualSection,
    String name,
    String concerns,
    List<ElementModel> selectedExteriorelements,
    List<ElementModel> selectedWaterproofingElements,
    VisualReview? review,
    ConditionalAssessment? assessment,
    ExpectancyYears? eee,
    ExpectancyYears? lbc,
    ExpectancyYears? awe,
    bool invasiveReviewRequired,
    bool hasSignsOfLeak,
    bool isNewSection,
    String userFullName,
    bool unitUnavailable,
  ) {
    try {
      realm.write(() {
        visualSection.name = name;
        visualSection.unitUnavailable = unitUnavailable;
        visualSection.additionalconsiderations = concerns;
        visualSection.exteriorelements.clear();
        visualSection.exteriorelements.addAll(
          selectedExteriorelements.map((element) => element.name),
        );
        visualSection.waterproofingelements.clear();
        visualSection.waterproofingelements.addAll(
          selectedWaterproofingElements.map((element) => element.name),
        );

        visualSection.visualreview = review == null ? "" : review.name;
        visualSection.conditionalassessment =
            assessment == null ? "" : assessment.name;
        visualSection.eee = eee == null ? "" : eee.name;
        visualSection.lbc = lbc == null ? "" : lbc.name;
        visualSection.awe = awe == null ? "" : awe.name;
        visualSection.furtherinvasivereviewrequired = invasiveReviewRequired;
        visualSection.visualsignsofleak = hasSignsOfLeak;

        if (isNewSection) {
          visualSection.createdby = userFullName;
        } else {
          visualSection.lasteditedby = userFullName;
        }

        var creationtime = DateTime.now().toString();
        visualSection.createdat ??= creationtime;
        visualSection.editedat = DateTime.now().toString();
        //update parent with the section detail
        updateLocationSection(
          visualSection.parenttype,
          visualSection.id,
          visualSection.parentid,
          visualSection.name,
          visualSection.visualreview,
          visualSection.visualsignsofleak,
          visualSection.furtherinvasivereviewrequired,
          visualSection.conditionalassessment,
          visualSection.images.length,
        );

        realm.add(visualSection, update: true);
      });
      if (isNewSection) {
        pushToWebSocket('create', 'visualSection', _toJson(visualSection));
      } else {
        pushToWebSocket('update', 'visualSection', {
          "id": visualSection.id.hexString,
          "name": name,
          "unitunavailable": unitUnavailable,
          "visualsignsofleak": hasSignsOfLeak,
          "furtherinvasivereviewrequired": invasiveReviewRequired,
          "additionalconsiderations": visualSection.additionalconsiderations,
          "exteriorelements": visualSection.exteriorelements,
          "waterproofingelements": visualSection.waterproofingelements,
          "visualreview": visualSection.visualreview,
          "conditionalassessment": visualSection.conditionalassessment,
          "eee": visualSection.eee,
          "lbc": visualSection.lbc,
          "awe": visualSection.awe,
          "lasteditedby": userFullName,
          "parentid": visualSection.parentid,
          "editedat": DateTime.now().toString(),
          "companyIdentifier": visualSection.companyIdentifier,
        });
      }
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  bool addupdateDynamicVisualSection(
    DynamicVisualSection visualSection,
    String name,
    String concerns,
    bool invasiveReviewRequired,
    bool isNewSection,
    String userFullName,
    List<Question> questions,
    bool unitUnavailable,
  ) {
    try {
      realm.write(() {
        visualSection.name = name;
        visualSection.companyIdentifier = company;
        visualSection.unitUnavailable = unitUnavailable;
        visualSection.additionalconsiderations = concerns;
        visualSection.questions.clear();
        visualSection.questions.addAll(questions);
        visualSection.furtherinvasivereviewrequired = invasiveReviewRequired;

        if (isNewSection) {
          visualSection.createdby = userFullName;
        } else {
          visualSection.lasteditedby = userFullName;
        }

        var creationtime = DateTime.now().toString();
        visualSection.createdat ??= creationtime;
        visualSection.editedat = DateTime.now().toString();
        //update parent with the section detail
        updateLocationSection(
          visualSection.parenttype,
          visualSection.id,
          visualSection.parentid,
          visualSection.name,
          null,
          false,
          invasiveReviewRequired,
          "",
          visualSection.images.length,
        );

        realm.add(visualSection, update: true);
      });
      if (isNewSection) {
        pushToWebSocket('create', 'dynamicSection', _toJson(visualSection));
      } else {
        pushToWebSocket('update', 'dynamicSection', {
          "id": visualSection.id.hexString,
          "companyIdentifier": visualSection.companyIdentifier,
          "name": name,
          "unitunavailable": unitUnavailable,
          "furtherinvasivereviewrequired": invasiveReviewRequired,
          "additionalconsiderations": visualSection.additionalconsiderations,
          "questions": visualSection.questions,
          "lasteditedby": userFullName,
          "editedat": DateTime.now().toString(),
          "parentid": visualSection.parentid,
        });
      }
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  bool removeImageUrl(VisualSection localVisualSection, String url) {
    try {
      realm.write(() {
        localVisualSection.images.remove(url);

        updateImageCount(
          localVisualSection.parenttype,
          localVisualSection.id,
          localVisualSection.parentid,
          localVisualSection.images.length,
          localVisualSection.images.last,
        );
      });
      pushToWebSocket('update', 'visualSection', {
        "id": localVisualSection.id.hexString,
        "images": localVisualSection.images,
      });
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  bool removeImageUrlFromDynamic(
    DynamicVisualSection localVisualSection,
    String url,
  ) {
    try {
      realm.write(() {
        localVisualSection.images.remove(url);

        updateImageCount(
          localVisualSection.parenttype,
          localVisualSection.id,
          localVisualSection.parentid,
          localVisualSection.images.length,
          localVisualSection.images.last,
        );
      });
      pushToWebSocket('update', 'dynamicSection', {
        "id": localVisualSection.id.hexString,
        "images": localVisualSection.images,
      });
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  String getlocalPath(String onlinePath) {
    if (!onlinePath.startsWith('http')) {
      return onlinePath;
    }
    var images = realm.query<DeckImage>('onlinePath == \$0', [onlinePath]);
    if (images.isNotEmpty) {
      return images.first.imageLocalPath;
    }
    return "";
  }

  bool addImagesUrl(
    VisualSection localVisualSection,
    List<String> localPaths,
    List<String> onlinePaths,
  ) {
    try {
      int k = 0;
      if (offlineModeOn || !appSettings.activeConnection) {
        realm.write(() {
          for (var url in onlinePaths) {
            DeckImage image = DeckImage(
              ObjectId(),
              url,
              '',
              false,
              localVisualSection.id,
              'visualSection',
              'section',
              localVisualSection.name as String,
              usersBloc.userDetails.username as String,
              company,
            );

            realm.add<DeckImage>(image, update: true);
            if (localVisualSection.images.contains(url)) {
              int index = localVisualSection.images.indexOf(url);
              localVisualSection.images[index] = onlinePaths[k];
            } else {
              localVisualSection.images.add(onlinePaths[k]);
            }
            k++;
          }
          //localVisualSection.images.addAll(onlinePaths);
        });
      } else {
        k = 0;
        realm.write(() {
          for (var url in localPaths) {
            DeckImage image = DeckImage(
              ObjectId(),
              url,
              onlinePaths[k],
              true,
              localVisualSection.id,
              'visualSection',
              'section',
              localVisualSection.name as String,
              usersBloc.userDetails.username as String,
              company,
            );

            realm.add<DeckImage>(image, update: true);

            if (localVisualSection.images.contains(url)) {
              int index = localVisualSection.images.indexOf(url);
              localVisualSection.images[index] = onlinePaths[k];
            } else {
              if (!localVisualSection.images.contains(onlinePaths[k])) {
                localVisualSection.images.add(onlinePaths[k]);
              }
            }
            k++;
          }
        });
      }

      realm.write(() {
        updateImageCount(
          localVisualSection.parenttype,
          localVisualSection.id,
          localVisualSection.parentid,
          localVisualSection.images.length,
          onlinePaths.last,
        );
      });

      notifyListeners();
      pushToWebSocket('addImages', 'visualSection', {
        "id": localVisualSection.id.hexString,
        "images": localVisualSection.images,
        "companyIdentifier": localVisualSection.companyIdentifier,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  bool addImagesUrlToDynamicform(
    DynamicVisualSection localVisualSection,
    List<String> localPaths,
    List<String> onlinePaths,
  ) {
    try {
      int k = 0;
      if (offlineModeOn || !appSettings.activeConnection) {
        realm.write(() {
          for (var url in onlinePaths) {
            DeckImage image = DeckImage(
              ObjectId(),
              url,
              '',
              false,
              localVisualSection.id,
              'dynamicvisualSection',
              'section',
              localVisualSection.name as String,
              usersBloc.userDetails.username as String,
              company,
            );

            realm.add<DeckImage>(image, update: true);
            if (localVisualSection.images.contains(url)) {
              int index = localVisualSection.images.indexOf(url);
              localVisualSection.images[index] = onlinePaths[k];
            } else {
              localVisualSection.images.add(onlinePaths[k]);
            }
            k++;
          }
          //localVisualSection.images.addAll(onlinePaths);
        });
      } else {
        k = 0;
        realm.write(() {
          for (var url in localPaths) {
            DeckImage image = DeckImage(
              ObjectId(),
              url,
              onlinePaths[k],
              true,
              localVisualSection.id,
              'dynamicvisualSection',
              'section',
              localVisualSection.name as String,
              usersBloc.userDetails.username as String,
              company,
            );

            realm.add<DeckImage>(image, update: true);

            if (localVisualSection.images.contains(url)) {
              int index = localVisualSection.images.indexOf(url);
              localVisualSection.images[index] = onlinePaths[k];
            } else {
              if (!localVisualSection.images.contains(onlinePaths[k])) {
                localVisualSection.images.add(onlinePaths[k]);
              }
            }
            k++;
          }
        });
      }

      realm.write(() {
        updateImageCount(
          localVisualSection.parenttype,
          localVisualSection.id,
          localVisualSection.parentid,
          localVisualSection.images.length,
          onlinePaths.last,
        );
      });
      pushToWebSocket('addImages', 'dynamicSection', {
        "id": localVisualSection.id.hexString,
        "images": localVisualSection.images,
        "companyIdentifier": localVisualSection.companyIdentifier,
      });
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Consolidate updates for the same object id, debounce them and send a flat payload
  void pushToWebSocket(
    String eventName,
    String collectionName,
    Map<String, dynamic> data, {
    bool isDelete = false,
    bool addToDb = true,
  }) {
    debugPrint('Pushing to WebSocket: $eventName $collectionName');

    try {
      final messageId = (data['id'] ?? data['messageId'] ?? '').toString();
      if (messageId.isEmpty) {
        debugPrint('pushToWebSocket: missing id in data');
        return;
      }

      // If delete, send immediately and remove any pending consolidation
      if (isDelete) {
        _debounceTimers[messageId]?.cancel();
        _debounceTimers.remove(messageId);
        _pendingOutgoing.remove(messageId);

        final Map<String, Object> socketData = {
          'id': messageId,
          'messageId': messageId,
          'collectionName': collectionName,
          'action': 'delete',
          'data': jsonEncode({'id': messageId}),
        };

        final sent = syncService.pushToWebSocket(socketData, messageId);
        if (!sent && addToDb) {
          _saveUnsyncedDataImmediate(socketData.cast<String, dynamic>());
        }
        return;
      }

      // Merge incoming data into pending map
      final pending = _pendingOutgoing.putIfAbsent(messageId, () => {});
      data.forEach((k, v) {
        if (pending.containsKey(k)) {
          final existing = pending[k];
          if (existing is List && v is List) {
            final set =
                <dynamic>{}
                  ..addAll(existing)
                  ..addAll(v);
            pending[k] = set.toList();
          } else if (existing is Map && v is Map) {
            pending[k] = {...existing, ...v};
          } else {
            pending[k] = v;
          }
        } else {
          pending[k] = v;
        }
      });

      // Debounce send
      _debounceTimers[messageId]?.cancel();
      _debounceTimers[messageId] = Timer(_debounceDuration, () {
        try {
          final merged = _pendingOutgoing.remove(messageId) ?? {};
          _debounceTimers.remove(messageId);

          final Map<String, Object> socketData = {
            'id': messageId,
            'messageId': messageId,
            'collectionName': collectionName,
            'action': eventName,
            'data': jsonEncode(merged),
          };

          final sent = syncService.pushToWebSocket(socketData, messageId);
          if (!sent && addToDb) {
            _saveUnsyncedDataImmediate(socketData.cast<String, dynamic>());
          }
        } catch (e) {
          debugPrint('Error sending consolidated socketData: $e');
        }
      });
    } catch (e) {
      debugPrint('Error in pushToWebSocket: $e');
    }
  }

  @override
  void dispose() {
    _channelSubscription?.cancel();
    _currentChannel = null;
    // Clear any pending messages
    _messageQueue.clear();
    _isProcessingQueue = false;
    debugPrint("Cleared message queue and stopped processing");

    realm.close();
    super.dispose();
  }

  void uploadLocalImages() async {
    try {
      syncUnsyncedData();
      if (offlineModeOn) return;
      //List<DeckImage> imagesTobeDelete = [];

      if (!realm.isClosed) {
        final images = realm.query<DeckImage>("isUploaded == false");
        //just removing the notifications part, perhaps failing the whole method.
        if (images.isNotEmpty && !offlineModeOn) {
          //NotificationController.createNewNotification();
        }
        //set device lock
        //WakelockPlus.enable();
        for (var image in images) {
          if (!appSettings.activeConnection) {
            appSettings.isImageUploading = false;
            return;
          }
          String localPath = image.imageLocalPath;
          String transformedPath = '';
          String parentType = image.parentType;
          ObjectId parentId = image.parentId;

          if (Platform.isIOS) {
            final directory = await getApplicationSupportDirectory();

            transformedPath = path.join(directory.path, localPath);
          } else {
            transformedPath = localPath;
          }
          final file = File(transformedPath);
          //will not delete any entries now
          if (!file.existsSync()) {
            //imagesTobeDelete.add(image);
            continue;
          }
          try {
            var result = await imagesBloc.uploadImage(
              transformedPath,
              image.containerName,
              image.uploadedBy,
              image.id.toString(),
              image.parentType,
              image.entityName,
            );
            if (result is ImageResponse) {
              //check if the image is already added to db
              final addedImage = realm.query<DeckImage>(
                "imageLocalPath == \$0",
                [localPath],
              );
              realm.write(() {
                if (addedImage.isEmpty) {
                  if (result.url!.startsWith('http')) {
                    image.isUploaded = true;
                  } else {
                    image.isUploaded = false;
                  }

                  image.onlinePath = result.url as String;
                  image.imageLocalPath = localPath;
                  realm.add<DeckImage>(image, update: true);
                } else {
                  if (result.url!.startsWith('http')) {
                    addedImage.first.isUploaded = true;
                  } else {
                    addedImage.first.isUploaded = false;
                  }

                  addedImage.first.onlinePath = result.url as String;
                }

                switch (parentType.toLowerCase()) {
                  case 'project':
                    var project = realm.find<Project>(parentId);
                    project?.url = result.url;
                    pushToWebSocket('update', 'project', {
                      "id": parentId.hexString,
                      "url": result.url,
                      "companyIdentifier": project?.companyIdentifier,
                    });
                    break;

                  case 'subproject':
                    var subproject = realm.find<SubProject>(parentId);
                    subproject?.url = result.url;
                    pushToWebSocket('update', 'subProject', {
                      "id": parentId.hexString,
                      "url": result.url,
                      "companyIdentifier": subproject?.companyIdentifier,
                    });
                    updateChildUrl(
                      parentId,
                      subproject?.parentid as ObjectId,
                      result.url as String,
                    );
                    break;
                  case 'location':
                    var location = realm.find<Location>(parentId);
                    location?.url = result.url;
                    pushToWebSocket('update', 'location', {
                      "id": parentId.hexString,
                      "url": result.url,
                      "companyIdentifier": location?.companyIdentifier,
                    });
                    updateSubChildUrl(
                      parentId,
                      location?.parentid as ObjectId,
                      result.url as String,
                    );
                    break;
                  case 'visualsection':
                    var visualsection = realm.find<VisualSection>(parentId);
                    if (visualsection != null) {
                      int index = visualsection.images.indexWhere(
                        (element) => element == image.imageLocalPath,
                      );
                      if (index != -1) {
                        visualsection.images[index] = result.url as String;
                        //update coverurls
                        pushToWebSocket('addImages', 'visualSection', {
                          "id": parentId.hexString,
                          "images": visualsection.images,
                          "companyIdentifier": visualsection.companyIdentifier,
                        });

                        updateImageCount(
                          visualsection.parenttype,
                          visualsection.id,
                          visualsection.parentid,
                          visualsection.images.length,
                          visualsection.images.last,
                        );
                      }
                    }
                    break;
                  case 'dynamicvisualsection':
                    var visualsection = realm.find<DynamicVisualSection>(
                      parentId,
                    );
                    if (visualsection != null) {
                      int index = visualsection.images.indexWhere(
                        (element) => element == image.imageLocalPath,
                      );
                      if (index != -1) {
                        visualsection.images[index] = result.url as String;
                        //update coverurls
                        updateImageCount(
                          visualsection.parenttype,
                          visualsection.id,
                          visualsection.parentid,
                          visualsection.images.length,
                          visualsection.images.last,
                        );
                        pushToWebSocket('addImages', 'dynamicSection', {
                          "id": parentId.hexString,
                          "images": visualsection.images,
                          "companyIdentifier": visualsection.companyIdentifier,
                        });
                      }
                    }
                    break;
                  case 'invasivesection':
                    var invasiveSection = realm.find<InvasiveSection>(parentId);
                    if (invasiveSection != null) {
                      int index = invasiveSection.invasiveimages.indexWhere(
                        (element) => element == image.imageLocalPath,
                      );
                      if (index != -1) {
                        invasiveSection.invasiveimages[index] =
                            result.url as String;
                        pushToWebSocket('addImages', 'invasiveSection', {
                          "id": parentId.hexString,
                          "images": invasiveSection.invasiveimages,
                          "companyIdentifier":
                              invasiveSection.companyIdentifier,
                        });
                      }
                    }
                    break;
                  case 'conclusivesection':
                    var conclusiveSection = realm.find<ConclusiveSection>(
                      parentId,
                    );
                    if (conclusiveSection != null) {
                      int index = conclusiveSection.conclusiveimages.indexWhere(
                        (element) => element == image.imageLocalPath,
                      );
                      if (index != -1) {
                        conclusiveSection.conclusiveimages[index] =
                            result.url as String;
                        pushToWebSocket('addImages', 'conclusiveSection', {
                          "id": parentId.hexString,
                          "images": conclusiveSection.conclusiveimages,
                          "companyIdentifier":
                              conclusiveSection.companyIdentifier,
                        });
                      }
                    }
                    break;
                  default:
                }
              });
            }
          } catch (e) {
            debugPrint("Error message: $e");
            continue;
          }
        }
        //realm.write(() => realm.deleteMany<DeckImage>(imagesTobeDelete));
      }
    } catch (e) {
      debugPrint("Error message: $e");
      appSettings.isImageUploading = false;
    } finally {
      //NotificationController.cancelNotifications();
      appSettings.isImageUploading = false;
      //WakelockPlus.disable();
    }
  }

  void deleteLocationSection(
    String parentType,
    ObjectId id,
    ObjectId parentid,
    bool updateInvasiveSection,
  ) {
    if (parentType == 'project') {
      try {
        var parentProject = realm.find<Project>(parentid);
        Section foundChild;
        if (parentProject != null) {
          if (updateInvasiveSection) {
            // foundChild = parentProject.invasiveSections
            //     .firstWhere((element) => element.id == id);

            // parentProject.invasiveSections.remove(foundChild);
          } else {
            foundChild = parentProject.sections.firstWhere(
              (element) => element.id == id,
            );

            parentProject.sections.remove(foundChild);
          }
        }
      } catch (e) {
        debugPrint(e.toString());
      }
    } else {
      var parentLocation = realm.find<Location>(parentid);
      Section foundChild;

      if (parentLocation != null) {
        try {
          if (updateInvasiveSection) {
            if (parentLocation.parenttype == 'project') {
              var parentProject = realm.find<Project>(parentLocation.parentid);
              if (parentProject != null) {
                // LocalChild invasiveChild = parentProject.invasiveChildren
                //     .firstWhere((element) => element.id == parentid);
                // parentProject.invasiveChildren.remove(invasiveChild);
              }
            } else {
              var parentSubProject = realm.find<SubProject>(
                parentLocation.parentid,
              );
              if (parentSubProject != null) {
                // LocalChild invasiveChild = parentSubProject.invasiveChildren
                //     .firstWhere((element) => element.id == parentid);
                // parentSubProject.invasiveChildren.remove(invasiveChild);
                //remove from project as well.
                var parentProject = realm.find<Project>(
                  parentSubProject.parentid,
                );
                if (parentProject != null) {
                  // invasiveChild = parentProject.invasiveChildren.firstWhere(
                  //     (element) => element.id == parentSubProject.id);
                  // parentProject.invasiveChildren.remove(invasiveChild);
                }
              }
            }
          } else {
            foundChild = parentLocation.sections.firstWhere(
              (element) => element.id == id,
            );
            parentLocation.sections.remove(foundChild);
            // pushToWebSocket('removeSection', 'location', {
            //   "id": parentid.hexString,
            //   "changedFields": {
            //     "sections": {"id": id},
            //   },
            // });
          }
        } catch (e) {
          debugPrint(e.toString());
        }
      }
    }
  }

  void updateLocationSection(
    String parentType,
    ObjectId id,
    ObjectId parentid,
    String? name,
    String? visualreview,
    bool visualsignsofleak,
    bool furtherinvasivereviewrequired,
    String? conditionalassessment,
    int length,
  ) {
    //for singlelevel project
    if (parentType == 'project') {
      var parentProject = realm.find<Project>(parentid);

      if (parentProject != null) {
        var found = parentProject.sections.where((element) => element.id == id);
        if (found.isEmpty) {
          parentProject.sections.add(
            Section(
              id,
              furtherinvasivereviewrequired,
              name: name,
              visualreview: visualreview,
              visualsignsofleak: visualsignsofleak,
              furtherinvasivereviewrequired: furtherinvasivereviewrequired,
              conditionalassessment: conditionalassessment,
              count: length,
            ),
          );
        } else {
          var foundChild = found.first;
          foundChild.name = name;
          foundChild.visualreview = visualreview;
          foundChild.visualsignsofleak = visualsignsofleak;
          foundChild.conditionalassessment = conditionalassessment;
          foundChild.furtherinvasivereviewrequired =
              furtherinvasivereviewrequired;
          foundChild.count = length;
          foundChild.isInvasive = furtherinvasivereviewrequired;
        }
      }
    } else {
      var parentLocation = realm.find<Location>(parentid);

      if (parentLocation != null) {
        var found = parentLocation.sections.where(
          (element) => element.id == id,
        );
        if (found.isEmpty) {
          parentLocation.sections.add(
            Section(
              id,
              furtherinvasivereviewrequired,
              name: name,
              visualreview: visualreview,
              visualsignsofleak: visualsignsofleak,
              furtherinvasivereviewrequired: furtherinvasivereviewrequired,
              conditionalassessment: conditionalassessment,
              count: length,
            ),
          );
        } else {
          var foundChild = found.first;
          foundChild.name = name;
          foundChild.visualreview = visualreview;
          foundChild.visualsignsofleak = visualsignsofleak;
          foundChild.conditionalassessment = conditionalassessment;
          foundChild.furtherinvasivereviewrequired =
              furtherinvasivereviewrequired;
          foundChild.count = length;
          foundChild.isInvasive = furtherinvasivereviewrequired;
        }

        //set invasive property of location.
        parentLocation.isInvasive = parentLocation.sections.any(
          (element) => element.furtherinvasivereviewrequired == true,
        );
        //update parents
        if (parentLocation.parenttype == 'project') {
          var parentProject = realm.find<Project>(parentLocation.parentid);
          if (parentProject != null) {
            var childLocation = parentProject.children.where(
              (element) => element.id == parentLocation.id,
            );
            childLocation.first.isInvasive = parentLocation.isInvasive;
            parentProject.isInvasive = parentProject.children.any(
              (element) => element.isInvasive == true,
            );
          }
        }
        if (parentLocation.parenttype == 'subproject') {
          var parentSubProject = realm.find<SubProject>(
            parentLocation.parentid,
          );
          if (parentSubProject != null) {
            var childLocation = parentSubProject.children.where(
              (element) => element.id == parentLocation.id,
            );
            childLocation.first.isInvasive = parentLocation.isInvasive;
            parentSubProject.isInvasive = parentSubProject.children.any(
              (element) => element.isInvasive == true,
            );
            var parentProject = realm.find<Project>(parentSubProject.parentid);
            if (parentProject != null) {
              var childLocation = parentProject.children.where(
                (element) => element.id == parentSubProject.id,
              );
              childLocation.first.isInvasive = parentSubProject.isInvasive;
              parentProject.isInvasive = parentProject.children.any(
                (element) => element.isInvasive == true,
              );
            }
          }
        }
      }
    }
  }

  void updateImageCount(
    String parentType,
    ObjectId id,
    ObjectId parentid,
    int length,
    String url,
  ) {
    try {
      if (parentType == 'project') {
        var parentProject = realm.find<Project>(parentid);

        if (parentProject != null) {
          var found = parentProject.sections.where(
            (element) => element.id == id,
          );
          var foundChild = found.first;
          foundChild.count = length;
          if (url != '') {
            foundChild.coverUrl = url;
          }
          pushToWebSocket('updateImageCount', 'project', {
            "id": parentProject.id.hexString,
            "childId": id,
            "count": length,
            "coverUrl": url,
          });
        }
      } else {
        var parentLocation = realm.find<Location>(parentid);

        if (parentLocation != null) {
          var found = parentLocation.sections.where(
            (element) => element.id == id,
          );
          var foundChild = found.first;
          foundChild.count = length;
          if (url != '') {
            foundChild.coverUrl = url;
          }

          pushToWebSocket('updateImageCount', 'location', {
            "id": parentLocation.id.hexString,
            "childId": id,
            "count": length,
            "coverUrl": url,
          });
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  InvasiveSection getNewInvasiveSection(ObjectId sectionId) {
    return InvasiveSection(
      ObjectId(),
      sectionId,
      "",
      usersBloc.userDetails.companyidentifer as String,
      postinvasiverepairsrequired: false,
    );
  }

  ConclusiveSection getNewConclusiveSection(ObjectId sectionId) {
    return ConclusiveSection(
      ObjectId(),
      sectionId,
      "",
      "",
      "",
      "",
      usersBloc.userDetails.companyidentifer as String,
      propowneragreed: false,
      invasiverepairsinspectedandcompleted: false,
    );
  }

  bool addInvasiveImagesUrl(
    String visualSectionName,
    InvasiveSection currentInvasiveSection,
    List<String> urls,
  ) {
    try {
      if (offlineModeOn || !appSettings.activeConnection) {
        realm.write(() {
          for (var url in urls) {
            DeckImage image = DeckImage(
              ObjectId(),
              url,
              '',
              false,
              currentInvasiveSection.id,
              'invasiveSection',
              'invasiveSectionImage',
              visualSectionName,
              usersBloc.userDetails.username as String,
              company,
            );

            realm.add<DeckImage>(image, update: true);
          }
          // VisualSection.images.addAll(urls);
        });
      }

      realm.write(() {
        currentInvasiveSection.invasiveimages.addAll(urls);
      });
      pushToWebSocket('addImages', 'invasiveSection', {
        "id": currentInvasiveSection.id.hexString,
        "images": currentInvasiveSection.invasiveimages,
        "companyIdentifier": currentInvasiveSection.companyIdentifier,
      });
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  bool addConclusiveImagesUrl(
    String visualSectionName,
    ConclusiveSection currentConclusiveSection,
    List<String> urls,
  ) {
    try {
      if (offlineModeOn || !appSettings.activeConnection) {
        realm.write(() {
          for (var url in urls) {
            DeckImage image = DeckImage(
              ObjectId(),
              url,
              '',
              false,
              currentConclusiveSection.id,
              'conclusiveSection',
              'conclusiveSectionImage',
              visualSectionName,
              usersBloc.userDetails.username as String,
              company,
            );

            realm.add<DeckImage>(image, update: true);
          }
          // VisualSection.images.addAll(urls);
        });
      }

      realm.write(() {
        currentConclusiveSection.conclusiveimages.addAll(urls);
      });
      pushToWebSocket('addImages', 'conclusiveSection', {
        "id": currentConclusiveSection.id.hexString,
        "images": currentConclusiveSection.conclusiveimages,
        "companyIdentifier": currentConclusiveSection.companyIdentifier,
      });
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  InvasiveSection getInvasiveSection(ObjectId sectionId) {
    var result = realm.query<InvasiveSection>('parentid ==\$0', [sectionId]);
    if (result.isEmpty) {
      return getNewInvasiveSection(sectionId);
    }
    return result.first;
  }

  ConclusiveSection getConclusiveSection(ObjectId sectionId) {
    var result = realm.query<ConclusiveSection>('parentid == \$0', [sectionId]);
    if (result.isEmpty) {
      return getNewConclusiveSection(sectionId);
    }
    return result.first;
  }

  bool addupdateInvasiveSection(
    InvasiveSection currentInvasiveSection,
    String description,
    bool postInvasiveRepairsRequired,
  ) {
    try {
      realm.write(() {
        currentInvasiveSection.postinvasiverepairsrequired =
            postInvasiveRepairsRequired;
        currentInvasiveSection.invasiveDescription = description;

        realm.add<InvasiveSection>(currentInvasiveSection, update: true);
      });

      pushToWebSocket('update', 'invasiveSection', {
        "id": currentInvasiveSection.id.hexString,
        "companyIdentifier": currentInvasiveSection.companyIdentifier,
        "postinvasiverepairsrequired": postInvasiveRepairsRequired,
        "invasiveDescription": description,
        "parentid": currentInvasiveSection.parentid.hexString,
      });

      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  addupdateConclusiveSection(
    ConclusiveSection currentConclusiveSection,
    bool propOwnerAgreed,
    bool invasiveRepairsCompleted,
    String eeeConclusive,
    String lbcConclusive,
    String aweConclusive,
    String description,
  ) {
    try {
      realm.write(() {
        currentConclusiveSection.propowneragreed = propOwnerAgreed;
        currentConclusiveSection.invasiverepairsinspectedandcompleted =
            invasiveRepairsCompleted;
        currentConclusiveSection.aweconclusive = aweConclusive;
        currentConclusiveSection.eeeconclusive = eeeConclusive;
        currentConclusiveSection.lbcconclusive = lbcConclusive;
        currentConclusiveSection.conclusiveconsiderations = description;
        realm.add<ConclusiveSection>(currentConclusiveSection, update: true);
      });
      notifyListeners();
      pushToWebSocket('update', 'conclusiveSection', {
        "id": currentConclusiveSection.id.hexString,
        "companyIdentifier": currentConclusiveSection.companyIdentifier,
        "parentid": currentConclusiveSection.parentid.hexString,
        "propowneragreed": propOwnerAgreed,
        "invasiverepairsinspectedandcompleted": invasiveRepairsCompleted,
        "aweconclusive": aweConclusive,
        "eeeconclusive": eeeConclusive,
        "lbcconclusive": lbcConclusive,
        "conclusiveconsiderations": description,
        "conclusiveimages": currentConclusiveSection.conclusiveimages,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  bool removeConclusiveImageUrl(
    ConclusiveSection localConclusiveSection,
    String url,
  ) {
    try {
      realm.write(() {
        localConclusiveSection.conclusiveimages.remove(url);
        //updateImageCount(localConclusiveSection.parenttype, localConclusiveSection.id,
        //localConclusiveSection.parentid, localConclusiveSection.images.length, "");
      });
      pushToWebSocket('addImages', 'conclusiveSection', {
        "id": localConclusiveSection.id.hexString,
        "conclusiveimages": localConclusiveSection.conclusiveimages,
        "companyIdentifier": localConclusiveSection.companyIdentifier,
      });
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  bool removeInvasiveImageUrl(
    InvasiveSection localInvasiveSection,
    String url,
  ) {
    try {
      realm.write(() {
        localInvasiveSection.invasiveimages.remove(url);
        //updateImageCount(localConclusiveSection.parenttype, localConclusiveSection.id,
        //localConclusiveSection.parentid, localConclusiveSection.images.length, "");
      });
      pushToWebSocket('addImages', 'invasiveSection', {
        "id": localInvasiveSection.id.hexString,
        "images": localInvasiveSection.invasiveimages,
        "companyIdentifier": localInvasiveSection.companyIdentifier,
      });
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<String>> getImagesNotUploaded(
    List<String> capturedImages,
    bool activeConnection,
    bool isNewSection,
  ) async {
    List<String> offlineImages = [];
    RealmResults<DeckImage> deckImages;
    try {
      if (activeConnection && !offlineModeOn) {
        return capturedImages.where((e) => !e.startsWith('http')).toList();
      } else {
        if (isNewSection) {
          return capturedImages;
        } else {
          for (var imgpath in capturedImages) {
            deckImages = realm.query<DeckImage>('imageLocalPath == \$0', [
              imgpath,
            ]);
            if (deckImages.isNotEmpty) {
              // if (!deckImages.first.isUploaded) {
              //   offlineImages.add(deckImages.first.imageLocalPath);
              // }
            } else {
              offlineImages.add(imgpath);
            }
          }
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    }
    return offlineImages.toList();
  }

  // Get queue status for monitoring
  Map<String, dynamic> getMessageQueueStatus() {
    return {
      'queueSize': _messageQueue.length,
      'isProcessing': _isProcessingQueue,
      'oldestMessageAge':
          _messageQueue.isNotEmpty
              ? DateTime.now().millisecondsSinceEpoch -
                  (_messageQueue.first['timestamp'] ??
                      DateTime.now().millisecondsSinceEpoch)
              : 0,
    };
  }

  // Force process any remaining messages (useful for debugging)
  Future<void> forceProcessQueue() async {
    if (_messageQueue.isNotEmpty) {
      debugPrint("Force processing ${_messageQueue.length} queued messages");
      await _processMessageQueue();
    }
  }

  // Keep original logic in a private helper so we can call it from the queued processor
  void _saveUnsyncedDataImmediate(Map<String, dynamic> socketData) {
    try {
      //check if the data already exists, using findAsync with _id
      final existingData = realm.find<UnsyncedData>(
        ObjectId.fromHexString(socketData['id']),
      );
      print('unsynceddata: $socketData');
      if (existingData == null) {
        realm.write(() {
          realm.add<UnsyncedData>(
            UnsyncedData(
              ObjectId.fromHexString(socketData['id']),
              'create',
              socketData['collectionName'] as String,
              socketData['data'],
              DateTime.now().toString(),
            ),
            update: true,
          );
        });
      } else if (socketData['action'] == 'update' ||
          socketData['action'] == 'updateImageUrl' ||
          socketData['action'] == 'updateImageCount' ||
          socketData['action'] == 'addImages') {
        // Patch the existing data with updated fields
        try {
          final existingJson = jsonDecode(existingData.jsonData);
          final updateJson = jsonDecode(socketData['data']);
          // Only patch the fields present in updateJson
          updateJson.forEach((key, value) {
            existingJson[key] = value;
          });
          realm.write(() {
            existingData.jsonData = jsonEncode(existingJson);
            existingData.updatedAt = DateTime.now().toString();
          });
        } catch (e) {
          debugPrint("Error patching unsynced data: $e");
        }
      } else if (socketData['action'] == 'delete') {
        // For delete, remove any existing entry
        realm.write(() {
          realm.delete<UnsyncedData>(existingData);
        });
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  // Public wrapper - enqueue and process serially
  void saveUnsyncedData(Map<String, dynamic> socketData) {
    try {
      // Defensive copy to decouple the queued map from caller
      _unsyncedQueue.add(Map<String, dynamic>.from(socketData));
      if (!_isProcessingUnsyncedQueue) _processUnsyncedQueue();
    } catch (e) {
      debugPrint('Error enqueueing unsynced data: $e');
    }
  }

  // Serial processor - drains the queue and calls the immediate saver for each item
  Future<void> _processUnsyncedQueue() async {
    if (_isProcessingUnsyncedQueue) return;
    _isProcessingUnsyncedQueue = true;
    try {
      while (_unsyncedQueue.isNotEmpty) {
        final item = _unsyncedQueue.removeAt(0);
        try {
          _saveUnsyncedDataImmediate(item);
        } catch (e) {
          debugPrint('Error processing unsynced item: $e');
          // Push item back and abort processing to avoid tight loop
          _unsyncedQueue.insert(0, item);
          break;
        }
      }
    } finally {
      _isProcessingUnsyncedQueue = false;
    }
  }

  // Async versions of handlers for non-blocking message processing
  Future<void> _handleInsertAsync(
    String collectionName,
    dynamic fullDocument,
  ) async {
    if (fullDocument == null) {
      debugPrint("Full document is null for insert operation");
      return;
    }

    try {
      // Use Future.microtask to make Realm write async
      await Future.microtask(() {
        realm.write(() {
          final obj = _getRealmObjectFromCollectionName(
            collectionName,
            fullDocument,
          );
          if (obj != null) {
            realm.add(obj, update: true);
            debugPrint("Async inserted/updated object in $collectionName");
          }
        });
      });
    } catch (e) {
      debugPrint("Error async inserting object: $e");
      rethrow;
    }
  }

  Future<void> _handleUpdateAsync(
    String collectionName,
    String messageId,
    dynamic updateDescription,
    dynamic fullDocument,
  ) async {
    try {
      final objectId = ObjectId.fromHexString(messageId);

      await Future.microtask(() {
        final existingObj = _findRealmObjectByCollectionName(
          collectionName,
          objectId,
        );

        if (existingObj == null) {
          debugPrint(
            "Object not found for update in $collectionName with id: $messageId",
          );
          // If object doesn't exist locally and we have fullDocument, create it
          if (fullDocument != null) {
            realm.write(() {
              final obj = _getRealmObjectFromCollectionName(
                collectionName,
                fullDocument,
              );
              if (obj != null) {
                realm.add(obj, update: true);
                debugPrint("Async created missing object in $collectionName");
              }
            });
          }
          return;
        }

        realm.write(() {
          if (updateDescription != null &&
              updateDescription['updatedFields'] != null) {
            // Update only the changed fields
            _updateSpecificFields(
              existingObj,
              updateDescription['updatedFields'],
              collectionName,
            );
          } else if (fullDocument != null) {
            // Fallback to full document update
            final obj = _getRealmObjectFromCollectionName(
              collectionName,
              fullDocument,
            );
            if (obj != null) {
              realm.add(obj, update: true);
            }
          }
          debugPrint("Async updated object in $collectionName");
        });
      });
    } catch (e) {
      debugPrint("Error async updating object: $e");
      rethrow;
    }
  }

  Future<void> _handleDeleteAsync(
    String collectionName,
    String messageId,
  ) async {
    try {
      await Future.microtask(() {
        realm.write(() {
          final obj = _findRealmObjectByCollectionName(
            collectionName,
            ObjectId.fromHexString(messageId),
          );
          if (obj != null) {
            realm.delete(obj);
            debugPrint("Async deleted object from $collectionName");
          } else {
            debugPrint(
              "Object not found for deletion in $collectionName with id: $messageId",
            );
          }
        });
      });
    } catch (e) {
      debugPrint("Error async deleting object: $e");
      rethrow;
    }
  }

  void _updateSpecificFields(
    dynamic obj,
    Map<String, dynamic> updatedFields,
    String collectionName,
  ) {
    switch (collectionName) {
      case 'project':
        _updateProjectFields(obj as Project, updatedFields);
        break;
      case 'subProject':
        _updateSubProjectFields(obj as SubProject, updatedFields);
        break;
      case 'location':
        _updateLocationFields(obj as Location, updatedFields);
        break;
      case 'visualSection':
        _updateVisualSectionFields(obj as VisualSection, updatedFields);
        break;
      case 'dynamicVisualSection':
        _updateDynamicVisualSectionFields(
          obj as DynamicVisualSection,
          updatedFields,
        );
        break;
      case 'invasiveSection':
        _updateInvasiveSectionFields(obj as InvasiveSection, updatedFields);
        break;
      case 'conclusiveSection':
        _updateConclusiveSectionFields(obj as ConclusiveSection, updatedFields);
        break;
      default:
        debugPrint("No field update handler for collection: $collectionName");
    }
  }

  void _updateProjectFields(Project project, Map<String, dynamic> fields) {
    fields.forEach((key, value) {
      if (key.startsWith('children.')) {
        // Handle children updates like children.0, children.1
        // Match children.<index> but use _id to find the child
        final match = RegExp(r'children\.(\d+)').firstMatch(key);
        if (match != null && value is Map<String, dynamic>) {
          final childIdStr = value['id'] ?? value['_id'];
          if (childIdStr != null) {
            final childId = ObjectId.fromHexString(childIdStr);
            final existingChild = project.children.firstWhereOrNull(
              (c) => c.id == childId,
            );
            if (existingChild != null) {
              value.forEach((childKey, childValue) {
                switch (childKey) {
                  case 'name':
                    existingChild.name = childValue?.toString() ?? '';
                    break;
                  case 'type':
                    existingChild.type = childValue?.toString() ?? '';
                    break;
                  case 'description':
                    existingChild.description = childValue?.toString() ?? '';
                    break;
                  case 'url':
                    existingChild.url = childValue?.toString() ?? '';
                    break;
                  case 'isInvasive':
                    existingChild.isInvasive = childValue ?? false;
                    break;
                  case 'sequenceNo':
                    existingChild.sequenceNo = childValue?.toString() ?? '';
                    break;
                }
              });
            } else {
              // Insert new child if not found
              project.children.add(
                Child(
                  childId,
                  value['isInvasive'] ?? false,
                  name: value['name'] ?? '',
                  type: value['type'] ?? '',
                  description: value['description'] ?? '',
                  url: value['url'] ?? '',
                  sequenceNo: value['sequenceNo'] ?? '',
                ),
              );
            }
          }
        }
      } else {
        switch (key) {
          case 'name':
            project.name = value?.toString() ?? '';
            break;
          case 'url':
            project.url = value?.toString() ?? '';
            break;
          case 'description':
            project.description = value?.toString() ?? '';
            break;
          case 'address':
            project.address = value?.toString() ?? '';
            break;
          case 'isInvasive':
            project.isInvasive = value ?? false;
            break;
          case 'editedat':
            project.editedat = value?.toString() ?? '';
            break;
          case 'lasteditedby':
            project.lasteditedby = value?.toString() ?? '';
            break;
          case 'assignedto':
            if (value is List) {
              project.assignedto.clear();
              project.assignedto.addAll(Set<String>.from(value));
            }
            break;
          case 'latitude':
            project.latitude = value?.toDouble();
            break;
          case 'longitude':
            project.longitude = value?.toDouble();
            break;
          case 'isSynced':
            project.isSynced = value ?? true;
            break;
        }
      }
    });
  }

  void _updateSubProjectFields(
    SubProject subProject,
    Map<String, dynamic> fields,
  ) {
    fields.forEach((key, value) {
      if (key.startsWith('children.')) {
        // Handle children updates like children.0, children.1
        // Match children.<index> but use _id to find the child
        final match = RegExp(r'children\.(\d+)').firstMatch(key);
        if (match != null && value is Map<String, dynamic>) {
          final childIdStr = value['id'] ?? value['_id'];
          if (childIdStr != null) {
            final childId = ObjectId.fromHexString(childIdStr);
            final existingChild = subProject.children.firstWhereOrNull(
              (c) => c.id == childId,
            );
            if (existingChild != null) {
              value.forEach((childKey, childValue) {
                switch (childKey) {
                  case 'name':
                    existingChild.name = childValue?.toString() ?? '';
                    break;
                  case 'type':
                    existingChild.type = childValue?.toString() ?? '';
                    break;
                  case 'description':
                    existingChild.description = childValue?.toString() ?? '';
                    break;
                  case 'url':
                    existingChild.url = childValue?.toString() ?? '';
                    break;
                  case 'isInvasive':
                    existingChild.isInvasive = childValue ?? false;
                    break;
                  case 'sequenceNo':
                    existingChild.sequenceNo = childValue?.toString() ?? '';
                    break;
                }
              });
            } else {
              // Insert new child if not found
              subProject.children.add(
                Child(
                  childId,
                  value['isInvasive'] ?? false,
                  name: value['name'] ?? '',
                  type: value['type'] ?? '',
                  description: value['description'] ?? '',
                  url: value['url'] ?? '',
                  sequenceNo: value['sequenceNo'] ?? '',
                ),
              );
            }
          }
        }
      } else {
        switch (key) {
          case 'name':
            subProject.name = value?.toString() ?? '';
            break;
          case 'url':
            subProject.url = value?.toString() ?? '';
            break;
          case 'description':
            subProject.description = value?.toString() ?? '';
            break;
          case 'isInvasive':
            subProject.isInvasive = value ?? false;
            break;
          case 'editedat':
            subProject.editedat = value?.toString() ?? '';
            break;
          case 'lasteditedby':
            subProject.lasteditedby = value?.toString() ?? '';
            break;
          case 'assignedto':
            if (value is List) {
              subProject.assignedto.clear();
              subProject.assignedto.addAll(Set<String>.from(value));
            }
            break;
          case 'isSynced':
            subProject.isSynced = value ?? true;
            break;
        }
      }
    });
  }

  void _updateLocationFields(Location location, Map<String, dynamic> fields) {
    fields.forEach((key, value) {
      //apply the same logic as in project and subproject
      if (key.startsWith('sections.')) {
        // Handle children updates like sections.0, sections.1
        // Match sections.<index> but use _id to find the child
        final match = RegExp(r'sections\.(\d+)').firstMatch(key);
        if (match != null && value is Map<String, dynamic>) {
          final childIdStr = value['id'] ?? value['_id'];
          if (childIdStr != null) {
            final childId = ObjectId.fromHexString(childIdStr);
            final existingChild = location.sections.firstWhereOrNull(
              (c) => c.id == childId,
            );
            if (existingChild != null) {
              value.forEach((childKey, childValue) {
                switch (childKey) {
                  case 'name':
                    existingChild.name = childValue?.toString() ?? '';
                    break;
                  case 'conditionalassessment':
                    existingChild.conditionalassessment =
                        childValue?.toString() ?? '';
                    break;
                  case 'visualreview':
                    existingChild.visualreview = childValue?.toString() ?? '';
                    break;
                  case 'coverUrl':
                    existingChild.coverUrl = childValue?.toString() ?? '';
                    break;
                  case 'furtherinvasivereviewrequired':
                    existingChild.furtherinvasivereviewrequired =
                        childValue ?? false;
                    break;
                  case 'visualsignsofleak':
                    existingChild.visualsignsofleak = childValue ?? false;
                    break;
                  case 'isInvasive':
                    existingChild.isInvasive = childValue ?? false;
                    break;
                  case 'count':
                    existingChild.count = childValue ?? 0;
                    break;
                  case 'isuploading':
                    existingChild.isuploading = childValue ?? false;
                    break;
                  case 'sequenceNo':
                    existingChild.sequenceNo = childValue?.toString() ?? '';
                    break;
                }
              });
            } else {
              // Insert new child if not found
              location.sections.add(
                Section(
                  childId,
                  value['isInvasive'] ?? false,
                  name: value['name'] ?? '',
                  coverUrl: value['coverUrl'] ?? '',
                  visualreview: value['visualreview'] ?? '',
                  conditionalassessment: value['conditionalassessment'] ?? '',
                  visualsignsofleak: value['visualsignsofleak'] ?? false,
                  furtherinvasivereviewrequired:
                      value['furtherinvasivereviewrequired'] ?? false,
                  count: value['count'] ?? 0,
                  isuploading: value['isuploading'] ?? false,
                  sequenceNo: value['sequenceNo'] ?? '',
                ),
              );
            }
          }
        }
      } else {
        switch (key) {
          case 'name':
            location.name = value?.toString() ?? '';
            break;
          case 'url':
            location.url = value?.toString() ?? '';
            break;
          case 'description':
            location.description = value?.toString() ?? '';
            break;
          case 'isInvasive':
            location.isInvasive = value ?? false;
            break;
          case 'editedat':
            location.editedat = value?.toString() ?? '';
            break;
          case 'lasteditedby':
            location.lasteditedby = value?.toString() ?? '';
            break;
          case 'isSynced':
            location.isSynced = value ?? true;
            break;
        }
      }
    });
  }

  void _updateVisualSectionFields(
    VisualSection visualSection,
    Map<String, dynamic> fields,
  ) {
    fields.forEach((key, value) {
      switch (key) {
        case 'name':
          visualSection.name = value?.toString() ?? '';
          break;
        case 'unitUnavailable':
          visualSection.unitUnavailable = value ?? false;
          break;
        case 'additionalconsiderations':
          visualSection.additionalconsiderations = value?.toString();
          break;
        case 'visualreview':
          visualSection.visualreview = value?.toString();
          break;
        case 'conditionalassessment':
          visualSection.conditionalassessment = value?.toString();
          break;
        case 'eee':
          visualSection.eee = value?.toString() ?? '';
          break;
        case 'lbc':
          visualSection.lbc = value?.toString() ?? '';
          break;
        case 'awe':
          visualSection.awe = value?.toString() ?? '';
          break;
        case 'visualsignsofleak':
          visualSection.visualsignsofleak = value ?? false;
          break;
        case 'furtherinvasivereviewrequired':
          visualSection.furtherinvasivereviewrequired = value ?? false;
          break;
        case 'images':
          if (value is List) {
            visualSection.images.clear();
            visualSection.images.addAll(List<String>.from(value));
          }
          break;
        case 'exteriorelements':
          if (value is List) {
            visualSection.exteriorelements.clear();
            visualSection.exteriorelements.addAll(List<String>.from(value));
          }
          break;
        case 'waterproofingelements':
          if (value is List) {
            visualSection.waterproofingelements.clear();
            visualSection.waterproofingelements.addAll(
              List<String>.from(value),
            );
          }
          break;
        case 'editedat':
          visualSection.editedat = value?.toString();
          break;
        case 'lasteditedby':
          visualSection.lasteditedby = value?.toString();
          break;
        case 'isSynced':
          visualSection.isSynced = value ?? true;
          break;
      }
    });
  }

  void _updateDynamicVisualSectionFields(
    DynamicVisualSection dynamicSection,
    Map<String, dynamic> fields,
  ) {
    fields.forEach((key, value) {
      switch (key) {
        case 'name':
          dynamicSection.name = value?.toString() ?? '';
          break;
        case 'unitUnavailable':
          dynamicSection.unitUnavailable = value ?? false;
          break;
        case 'additionalconsiderations':
          dynamicSection.additionalconsiderations = value?.toString();
          break;
        case 'furtherinvasivereviewrequired':
          dynamicSection.furtherinvasivereviewrequired = value ?? false;
          break;
        case 'images':
          if (value is List) {
            dynamicSection.images.clear();
            dynamicSection.images.addAll(List<String>.from(value));
          }
          break;
        case 'questions':
          if (value is List) {
            dynamicSection.questions.clear();
            dynamicSection.questions.addAll(List<Question>.from(value));
          }
          break;
        case 'editedat':
          dynamicSection.editedat = value?.toString();
          break;
        case 'lasteditedby':
          dynamicSection.lasteditedby = value?.toString();
          break;
        case 'isSynced':
          dynamicSection.isSynced = value ?? true;
          break;
      }
    });
  }

  void _updateInvasiveSectionFields(
    InvasiveSection invasiveSection,
    Map<String, dynamic> fields,
  ) {
    try {
      fields.forEach((key, value) {
        switch (key) {
          case 'invasiveDescription':
            invasiveSection.invasiveDescription = value?.toString() ?? '';
            break;
          case 'postinvasiverepairsrequired':
            invasiveSection.postinvasiverepairsrequired = value ?? false;
            break;
          case 'invasiveimages':
            if (value is List) {
              invasiveSection.invasiveimages.clear();
              invasiveSection.invasiveimages.addAll(List<String>.from(value));
            }
            break;
          case 'isSynced':
            invasiveSection.isSynced = value ?? true;
            break;
        }
      });
    } catch (e) {
      debugPrint("Error updating invasive section fields: $e");
    }
  }

  void _updateConclusiveSectionFields(
    ConclusiveSection conclusiveSection,
    Map<String, dynamic> fields,
  ) {
    fields.forEach((key, value) {
      switch (key) {
        case 'conclusiveconsiderations':
          conclusiveSection.conclusiveconsiderations = value?.toString() ?? '';
          break;
        case 'eeeconclusive':
          conclusiveSection.eeeconclusive = value?.toString() ?? '';
          break;
        case 'lbcconclusive':
          conclusiveSection.lbcconclusive = value?.toString() ?? '';
          break;
        case 'aweconclusive':
          conclusiveSection.aweconclusive = value?.toString() ?? '';
          break;
        case 'propowneragreed':
          conclusiveSection.propowneragreed = value ?? false;
          break;
        case 'invasiverepairsinspectedandcompleted':
          conclusiveSection.invasiverepairsinspectedandcompleted =
              value ?? false;
          break;
        case 'conclusiveimages':
          if (value is List) {
            conclusiveSection.conclusiveimages.clear();
            conclusiveSection.conclusiveimages.addAll(List<String>.from(value));
          }
          break;
        case 'isSynced':
          conclusiveSection.isSynced = value ?? true;
          break;
      }
    });
  }

  // Add this method to resolve the error
  // Helper to find an object by collection name and id
  dynamic _findRealmObjectByCollectionName(String collectionName, ObjectId id) {
    switch (collectionName) {
      case 'project':
        return realm.find<Project>(id);
      case 'subProject':
        return realm.find<SubProject>(id);
      case 'location':
        return realm.find<Location>(id);
      case 'visualSection':
        return realm.find<VisualSection>(id);
      case 'dynamicVisualSection':
        return realm.find<DynamicVisualSection>(id);
      case 'invasiveSection':
        return realm.find<InvasiveSection>(id);
      case 'conclusiveSection':
        return realm.find<ConclusiveSection>(id);
      // Add other cases as needed
      default:
        return null;
    }
  }

  // Add this method to resolve the error
  dynamic _getRealmObjectFromCollectionName(
    String collectionName,
    dynamic data,
  ) {
    switch (collectionName) {
      case 'project':
        final sectionsData = data['sections'] as List? ?? [];
        final sections =
            sectionsData.map((sectionData) {
              return Section(
                ObjectId.fromHexString(sectionData['_id'] ?? sectionData['id']),
                sectionData['isInvasive'] ?? false,
                furtherinvasivereviewrequired:
                    sectionData['furtherinvasivereviewrequired'] ?? false,
                name: sectionData['name'] ?? '',
                visualreview: sectionData['visualreview'] ?? '',
                visualsignsofleak: sectionData['visualsignsofleak'] ?? false,
                conditionalassessment:
                    sectionData['conditionalassessment'] ?? '',
                count: sectionData['count'] ?? 0,
                coverUrl: sectionData['coverUrl'] ?? '',
                sequenceNo: sectionData['sequenceNo'] ?? '',
                isuploading: sectionData['isuploading'] ?? false,
              );
            }).toList();

        final childrenData = data['children'] as List? ?? [];
        final children =
            childrenData.map((childData) {
              return Child(
                ObjectId.fromHexString(childData['_id'] ?? childData['id']),
                childData['isInvasive'] ?? false,
                name: childData['name'] ?? '',
                type: childData['type'] ?? '',
                description: childData['description'] ?? '',
                url: childData['url'] ?? '',
                sequenceNo: childData['sequenceNo'] ?? '',
              );
            }).toList();

        final project = Project(
          ObjectId.fromHexString(data['_id']),
          data['companyIdentifier'] ?? '',
          name: data['name'] ?? '',
          projecttype: data['projecttype'] ?? '',
          description: data['description'] ?? '',
          address: data['address'] ?? '',
          createdby: data['createdby'] ?? '',
          createdat: data['createdat'] ?? '',
          url: data['url'] ?? '',
          editedat: data['editedat'] ?? '',
          lasteditedby: data['lasteditedby'] ?? '',
          iscomplete: data['isDeleted'] ?? false,
          isInvasive: data['isInvasive'] ?? false,
          children: children,
          sections: sections,
          assignedto: Set<String>.from(data['assignedto'] ?? []),
        );
        return project;
      case 'subProject':
        final childrenData = data['children'] as List? ?? [];
        final children =
            childrenData.map((childData) {
              return Child(
                ObjectId.fromHexString(childData['_id'] ?? childData['id']),
                childData['isInvasive'] ?? false,
                name: childData['name'] ?? '',
                type: childData['type'] ?? '',
                description: childData['description'] ?? '',
                url: childData['url'] ?? '',
                sequenceNo: childData['sequenceNo'] ?? '',
              );
            }).toList();

        return SubProject(
          ObjectId.fromHexString(data['_id']),
          data['parentid'] != null
              ? ObjectId.fromHexString(data['parentid'])
              : ObjectId(),
          data['isInvasive'] ?? false,
          data['companyIdentifier'] ?? '',
          name: data['name'] ?? '',
          url: data['url'] ?? '',
          createdby: data['createdBy'] ?? '',
          createdat: data['createdAt'] ?? '',
          type: data['type'] ?? '',
          description: data['description'] ?? '',
          parenttype: data['parenttype'] ?? '',
          children: children,
          assignedto: Set<String>.from(data['assignedto'] ?? []),
          isSynced: data['isSynced'] ?? true,
          editedat: data['editedat'] ?? '',
          lasteditedby: data['lasteditedby'] ?? '',
        );
      case 'location':
        final sectionsData = data['sections'] as List? ?? [];
        final sections =
            sectionsData.map((sectionData) {
              return Section(
                ObjectId.fromHexString(sectionData['_id'] ?? sectionData['id']),
                sectionData['isInvasive'] ?? false,
                furtherinvasivereviewrequired:
                    sectionData['furtherinvasivereviewrequired'] ?? false,
                name: sectionData['name'] ?? '',
                visualreview: sectionData['visualreview'] ?? '',
                visualsignsofleak: sectionData['visualsignsofleak'] ?? false,
                conditionalassessment:
                    sectionData['conditionalassessment'] ?? '',
                count: sectionData['count'] ?? 0,
                coverUrl: sectionData['coverUrl'] ?? '',
                sequenceNo: sectionData['sequenceNo'] ?? '',
                isuploading: sectionData['isuploading'] ?? false,
              );
            }).toList();

        return Location(
          ObjectId.fromHexString(data['_id']),
          data['parentid'] != null
              ? ObjectId.fromHexString(data['parentid'])
              : ObjectId(),
          data['isInvasive'] ?? false,
          data['companyIdentifier'] ?? '',
          name: data['name'] ?? '',
          type: data['type'] ?? '',
          description: data['description'] ?? '',
          parenttype: data['parenttype'] ?? '',
          createdby: data['createdBy'] ?? '',
          createdat: data['createdAt'] ?? '',
          url: data['url'] ?? '',
          editedat: data['editedat'] ?? '',
          lasteditedby: data['lasteditedby'] ?? '',
          sections: sections,
          isSynced: data['isSynced'] ?? true,
        );

      case 'visualSection':
        return VisualSection(
          ObjectId.fromHexString(data['_id']),
          data['eee'] ?? '',
          data['lbc'] ?? '',
          data['awe'] ?? '',
          data['parentid'] != null
              ? ObjectId.fromHexString(data['parentid'])
              : ObjectId(),
          data['unitUnavailable'] ?? false,
          data['companyIdentifier'] ?? '',
          name: data['name'] ?? '',
          parenttype: data['parenttype'] ?? '',
          images: List<String>.from(data['images'] ?? []),
          exteriorelements: List<String>.from(data['exteriorelements'] ?? []),
          waterproofingelements: List<String>.from(
            data['waterproofingelements'] ?? [],
          ),
          additionalconsiderations: data['additionalconsiderations'],
          visualreview: data['visualreview'],
          visualsignsofleak: data['visualsignsofleak'] ?? false,
          furtherinvasivereviewrequired:
              data['furtherinvasivereviewrequired'] ?? true,
          conditionalassessment: data['conditionalassessment'],
          createdby: data['createdby'],
          createdat: data['createdat'],
          isSynced: data['isSynced'] ?? true,
          editedat: data['editedat'],
          lasteditedby: data['lasteditedby'],
        );
      case 'dynamicVisualSection':
        final questionsData = data['questions'] as List? ?? [];
        final questions =
            questionsData.map((questionData) {
              // Assuming Question constructor takes these parameters
              return Question(
                questionData['id'] ?? '',
                questionData['type'] ?? '',
                questionData['name'] ?? '',
                questionData['answer'],
                multipleAnswers: List<String>.from(
                  questionData['multipleAnswers'] ?? [],
                ),
                allowedValues: List<String>.from(
                  questionData['allowedValues'] ?? [],
                ),
                isMandatory: questionData['isMandatory'] ?? false,
              );
            }).toList();
        return DynamicVisualSection(
          ObjectId.fromHexString(data['_id']),
          data['parentid'] != null
              ? ObjectId.fromHexString(data['parentid'])
              : ObjectId(),
          data['unitUnavailable'] ?? false,
          companyIdentifier: data['companyIdentifier'] ?? '',
          name: data['name'] ?? '',
          images: List<String>.from(data['images'] ?? []),
          questions: questions,
          furtherinvasivereviewrequired:
              data['furtherinvasivereviewrequired'] ?? true,
          createdby: data['createdby'],
          createdat: data['createdat'],
          parenttype: data['parenttype'] ?? '',
          isSynced: data['isSynced'] ?? true,
          editedat: data['editedat'],
          lasteditedby: data['lasteditedby'],
          additionalconsiderations: data['additionalconsiderations'],
        );
      case 'invasiveSection':
        return InvasiveSection(
          ObjectId.fromHexString(data['_id']),
          data['parentid'] != null
              ? ObjectId.fromHexString(data['parentid'])
              : ObjectId(),
          data['invasiveDescription'] ?? '',
          data['companyIdentifier'] ?? '',
          postinvasiverepairsrequired:
              data['postinvasiverepairsrequired'] ?? false,
          invasiveimages: List<String>.from(data['invasiveimages'] ?? []),
          isSynced: data['isSynced'] ?? true,
        );
      case 'conclusiveSection':
        return ConclusiveSection(
          ObjectId.fromHexString(data['_id']),
          data['parentid'] != null
              ? ObjectId.fromHexString(data['parentid'])
              : ObjectId(),
          data['conclusiveconsiderations'] ?? '',
          data['eeeconclusive'] ?? '',
          data['lbcconclusive'] ?? '',
          data['aweconclusive'] ?? '',
          data['companyIdentifier'] ?? '',
          propowneragreed: data['propowneragreed'] ?? false,
          invasiverepairsinspectedandcompleted:
              data['invasiverepairsinspectedandcompleted'] ?? false,
          conclusiveimages: List<String>.from(data['conclusiveimages'] ?? []),
          isSynced: data['isSynced'] ?? true,
        );
      default:
        debugPrint('Unknown collection name: $collectionName');
        return null;
    }
  }
}
