import 'dart:convert';
import 'dart:io';
import 'package:E3InspectionsMultiTenant/src/services/sync_service.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:realm/realm.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
//import 'package:wakelock_plus/wakelock_plus.dart';
import '../bloc/images_bloc.dart';
//import '../bloc/notificationcontroller.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/users_bloc.dart';
import '../models/exteriorelements.dart';
import '../models/realm/realm_schemas.dart';
import '../models/customsync/sync_data.dart';
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
  }
  void registerToChannelStream(WebSocketChannel channel) {
    channel.stream.listen(
      (message) {
        debugPrint("Received message: $message");
        final response = jsonDecode(message);
        final messageId = response['messageId'];

        if (response != null && response['status'] == 'success') {
          // final objectId = ObjectId.fromHexString(data['id']);
          // markAsSynced(objectId);
          // debugPrint("Object marked as synced: ${data['id']}");
        } else {
          debugPrint("Failed to sync object: ${response?['message']}");
          //add this to unsynced data
          final failedData = syncService.pendingMessages[messageId];
          if (failedData != null) {
            saveUnsyncedData(jsonDecode(failedData));
          }
        }
        syncService.pendingMessages.remove(messageId);
      },
      onError: (error) {
        // If needed, retry everything in pendingMessages
        for (final data in syncService.pendingMessages.values) {
          saveUnsyncedData(jsonDecode(data));
        }
        syncService.pendingMessages.clear();
      },
      onDone: () {
        debugPrint("WebSocket connection closed");
        syncService.isWebSocketConnected = false;
      },
    );
  }

  void listenForRealmChanges() {
    final projects = realm.all<Project>();
    projects.changes.listen((changes) {
      for (var inserted in changes.inserted) {
        final project = projects[inserted];
        pushToWebSocket('create', 'project', _toJson(project));
      }

      for (var modified in changes.modified) {
        final project = projects[modified];
        pushToWebSocket('update', 'project', _toJson(project));
      }
    });

    final subProjects = realm.all<SubProject>();
    subProjects.changes.listen((changes) {
      for (var inserted in changes.inserted) {
        final subProject = subProjects[inserted];
        pushToWebSocket('create', 'subProject', _toJson(subProject));
      }

      for (var modified in changes.modified) {
        final subProject = subProjects[modified];
        pushToWebSocket('update', 'subProject', _toJson(subProject));
      }
    });
    final locations = realm.all<Location>();
    locations.changes.listen((changes) {
      for (var inserted in changes.inserted) {
        final location = locations[inserted];
        pushToWebSocket('create', 'location', _toJson(location));
      }

      for (var modified in changes.modified) {
        final location = locations[modified];
        pushToWebSocket('update', 'location', _toJson(location));
      }
    });
    final visualSections = realm.all<VisualSection>();
    visualSections.changes.listen((changes) {
      for (var inserted in changes.inserted) {
        final visualSection = visualSections[inserted];
        pushToWebSocket('create', 'visualSection', _toJson(visualSection));
      }

      for (var modified in changes.modified) {
        final visualSection = visualSections[modified];
        pushToWebSocket('update', 'visualSection', _toJson(visualSection));
      }
    });
    final invasiveSections = realm.all<InvasiveSection>();
    invasiveSections.changes.listen((changes) {
      for (var inserted in changes.inserted) {
        final invasiveSection = invasiveSections[inserted];
        pushToWebSocket('create', 'invasiveSection', _toJson(invasiveSection));
      }

      for (var modified in changes.modified) {
        final invasiveSection = invasiveSections[modified];
        pushToWebSocket('update', 'invasiveSection', _toJson(invasiveSection));
      }
    });
    final conclusiveSections = realm.all<ConclusiveSection>();
    conclusiveSections.changes.listen((changes) {
      for (var inserted in changes.inserted) {
        final conclusiveSection = conclusiveSections[inserted];
        pushToWebSocket(
          'create',
          'conclusiveSection',
          _toJson(conclusiveSection),
        );
      }

      for (var modified in changes.modified) {
        final conclusiveSection = conclusiveSections[modified];
        pushToWebSocket(
          'update',
          'conclusiveSection',
          _toJson(conclusiveSection),
        );
      }
    });
    // final deckImages = realmServices.realm.all<DeckImage>();
    // deckImages.changes.listen((changes) {
    //   for (var inserted in changes.inserted) {
    //     final deckImage = deckImages[inserted];
    //     pushToWebSocket('insert', 'deckImage', deckImage.toJson());
    //   }

    //   for (var modified in changes.modified) {
    //     final deckImage = deckImages[modified];
    //     pushToWebSocket('update', 'deckImage', deckImage.toJson());
    //   }

    //   for (var deleted in changes.deleted) {
    //     pushToWebSocket('delete', 'deckImage', {
    //       'id': deckImages[deleted].id.hexString,
    //     }, isDelete: true);
    //   }
    // });
    final dynamicVisualSections = realm.all<DynamicVisualSection>();
    dynamicVisualSections.changes.listen((changes) {
      for (var inserted in changes.inserted) {
        final dynamicVisualSection = dynamicVisualSections[inserted];
        pushToWebSocket(
          'create',
          'dynamicVisualSection',
          _toJson(dynamicVisualSection),
        );
      }

      for (var modified in changes.modified) {
        final dynamicVisualSection = dynamicVisualSections[modified];
        pushToWebSocket(
          'update',
          'dynamicVisualSection',
          _toJson(dynamicVisualSection),
        );
      }
    });
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

  SyncData getUnsyncedData() {
    final unsyncedProjects =
        realm.all<Project>().where((project) => !project.isSynced).toList();
    final unsyncedSubProjects =
        realm
            .all<SubProject>()
            .where((subProject) => !subProject.isSynced)
            .toList();
    final unsyncedLocations =
        realm.all<Location>().where((location) => !location.isSynced).toList();
    final unsyncedVisualSections =
        realm
            .all<VisualSection>()
            .where((section) => !section.isSynced)
            .toList();
    final unsyncedInvasiveSections =
        realm
            .all<InvasiveSection>()
            .where((section) => !section.isSynced)
            .toList();
    final unsyncedConclusiveSections =
        realm
            .all<ConclusiveSection>()
            .where((section) => !section.isSynced)
            .toList();
    final unsyncedDeckImages =
        realm.all<DeckImage>().where((image) => !image.isUploaded).toList();
    final unsyncedDynamicVisualSections =
        realm
            .all<DynamicVisualSection>()
            .where((section) => !section.isSynced)
            .toList();
    final unsyncedLocationForms =
        realm.all<LocationForm>().where((form) => !form.isSynced).toList();

    return SyncData(
      projects: unsyncedProjects,
      subProjects: unsyncedSubProjects,
      locations: unsyncedLocations,
      visualSections: unsyncedVisualSections,
      invasiveSections: unsyncedInvasiveSections,
      conclusiveSections: unsyncedConclusiveSections,
      deckImages: unsyncedDeckImages,
      dynamicVisualSections: unsyncedDynamicVisualSections,
      locationForms: unsyncedLocationForms,
    );
  }

  void markDataAsSynced(SyncData syncData) {
    realm.write(() {
      for (var project in syncData.projects) {
        project.isSynced = true;
      }
      for (var subProject in syncData.subProjects) {
        subProject.isSynced = true;
      }
      for (var location in syncData.locations) {
        location.isSynced = true;
      }
      for (var section in syncData.visualSections) {
        section.isSynced = true;
      }
      for (var section in syncData.invasiveSections) {
        section.isSynced = true;
      }
      for (var section in syncData.conclusiveSections) {
        section.isSynced = true;
      }
      for (var image in syncData.deckImages) {
        image.isUploaded = true;
      }
      for (var section in syncData.dynamicVisualSections) {
        section.isSynced = true;
      }
      for (var form in syncData.locationForms) {
        form.isSynced = true;
      }
    });
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
      pushToWebSocket('update', 'project', {
        "id": project.id.hexString,
        "changedFields": {"url": url},
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
          project.createdby = userName;
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
        pushToWebSocket('update', 'project', {
          "id": project.id.hexString,
          "changedFields": {
            "name": name,
            "address": address,
            "description": description,
            "latitude": lattitude,
            "longitude": longitude,
            "lasteditedby": userName,
            "editedat": DateTime.now().toString(),
          },
        });
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
      pushToWebSocket('updateChild', 'project', {
        "id": childId.hexString,
        "changedFields": {
          "children": {
            "id": childId,
            "isInvasive": isInvasive,
            "name": name,
            "type": type,
            "description": description,
            "url": "",
          },
        },
      });
    }
  }

  void deleteProjectChildren(ObjectId childId, ObjectId parentId) {
    var parentProject = realm.find<Project>(parentId);
    if (parentProject != null) {
      var foundChild = parentProject.children.firstWhere(
        (element) => element.id == childId,
      );
      parentProject.children.remove(foundChild);
      pushToWebSocket('deleteChild', 'project', {
        "id": parentId.hexString,
        "changedFields": {
          "children": {"id": childId.hexString},
        },
      });
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
        pushToWebSocket('updateChild', 'project', {
          "id": parentId.hexString,
          "changedFields": {
            "children": {"id": childId.hexString, "url": url},
          },
        });
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
          "changedFields": {"assignedto": assignees},
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
      pushToWebSocket('updateChild', 'subProject', {
        "id": childId.hexString,
        "changedFields": {
          "children": {
            "id": childId,
            "isInvasive": isInvasive,
            "name": name,
            "type": type,
            "description": description,
            "url": "",
          },
        },
      });
    }
  }

  void deleteSubProjectChildren(ObjectId childId, ObjectId parentId) {
    var parentProject = realm.find<SubProject>(parentId);
    if (parentProject != null) {
      var foundChild = parentProject.children.firstWhere(
        (element) => element.id == childId,
      );
      parentProject.children.remove(foundChild);
      pushToWebSocket('deleteChild', 'subProject', {
        "id": parentId.hexString,
        "changedFields": {
          "children": {"id": childId.hexString},
        },
      });
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
      pushToWebSocket('updateChild', 'subProject', {
        "id": parentId.hexString,
        "changedFields": {
          "children": {"id": childId.hexString, "url": url},
        },
      });
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
      pushToWebSocket('update', 'subProject', {
        "id": subProject.id.hexString,
        "changedFields": {"url": url},
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
          pushToWebSocket('update', 'subProject', {
            "id": subProject.id.hexString,
            "changedFields": {
              "name": name,
              "description": description,
              "lasteditedby": fullUserName,
              "editedat": DateTime.now().toString(),
            },
          });
        }
        pushToWebSocket('update', 'subProject', {
          "id": subProject.id.hexString,
          "changedFields": {
            "name": name,
            "description": description,
            "lasteditedby": fullUserName,

            "editedat": DateTime.now().toString(),
          },
        });
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
      pushToWebSocket('update', 'location', {
        "id": currentLocation.id.hexString,
        "changedFields": {"url": url},
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
        pushToWebSocket('update', 'location', {
          "id": location.id.hexString,
          "changedFields": {
            "name": name,
            "description": description,
            "lasteditedby": fullUserName,
            "editedat": DateTime.now().toString(),
          },
        });
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
          "changedFields": {
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
            "editedat": DateTime.now().toString(),
          },
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
          "changedFields": {
            "name": name,
            "unitunavailable": unitUnavailable,
            "furtherinvasivereviewrequired": invasiveReviewRequired,
            "additionalconsiderations": visualSection.additionalconsiderations,
            "questions": visualSection.questions,
            "lasteditedby": userFullName,
            "editedat": DateTime.now().toString(),
          },
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
      pushToWebSocket('removeUrl', 'visualSection', {
        "id": localVisualSection.id.hexString,
        "changedFields": {"images": localVisualSection.images},
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
      pushToWebSocket('removeUrl', 'dynamicSection', {
        "id": localVisualSection.id.hexString,
        "changedFields": {"images": localVisualSection.images},
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
      pushToWebSocket('update', 'visualSection', {
        "id": localVisualSection.id.hexString,
        "changedFields": {"images": localVisualSection.images},
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
      pushToWebSocket('update', 'dynamicSection', {
        "id": localVisualSection.id.hexString,
        "changedFields": {"images": localVisualSection.images},
      });
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  void dispose() {
    realm.close();
    super.dispose();
  }

  void uploadLocalImages() async {
    try {
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
                      "changedFields": {"url": result.url},
                    });
                    break;

                  case 'subproject':
                    var subproject = realm.find<SubProject>(parentId);
                    subproject?.url = result.url;
                    pushToWebSocket('update', 'subProject', {
                      "id": parentId.hexString,
                      "changedFields": {"url": result.url},
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
            pushToWebSocket('removeSection', 'project', {
              "id": parentid.hexString,
              "changedFields": {
                "sections": {"id": id},
              },
            });
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
            pushToWebSocket('removeSection', 'location', {
              "id": parentid.hexString,
              "changedFields": {
                "sections": {"id": id},
              },
            });
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
        pushToWebSocket('update', 'project', {
          "id": parentid.hexString,
          "changedFields": {
            "sections": {
              "id": id,
              "name": name,
              "count": length,
              "visualreview": visualreview,
              "visualsignsofleak": visualsignsofleak,
              "furtherinvasivereviewrequired": furtherinvasivereviewrequired,
              "conditionalassessment": conditionalassessment,
              "isInvasive": furtherinvasivereviewrequired,
            },
          },
        });
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
        pushToWebSocket('update', 'location', {
          "id": parentid.hexString,
          "changedFields": {
            "sections": {
              "id": id,
              "name": name,
              "count": length,
              "visualreview": visualreview,
              "visualsignsofleak": visualsignsofleak,
              "furtherinvasivereviewrequired": furtherinvasivereviewrequired,
              "conditionalassessment": conditionalassessment,
              "isInvasive": furtherinvasivereviewrequired,
            },
          },
        });
        //set invasive property of location.
        parentLocation.isInvasive = parentLocation.sections.any(
          (element) => element.furtherinvasivereviewrequired == true,
        );
        pushToWebSocket('update', 'location', {
          "id": parentLocation.id.hexString,
          "changedFields": {"isInvasive": parentLocation.isInvasive},
        });
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
            pushToWebSocket('update', 'project', {
              "id": parentProject.id.hexString,
              "changedFields": {"isInvasive": parentProject.isInvasive},
            });
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
            pushToWebSocket('update', 'subproject', {
              "id": parentSubProject.id.hexString,
              "changedFields": {"isInvasive": parentSubProject.isInvasive},
            });
            var parentProject = realm.find<Project>(parentSubProject.parentid);
            if (parentProject != null) {
              var childLocation = parentProject.children.where(
                (element) => element.id == parentSubProject.id,
              );
              childLocation.first.isInvasive = parentSubProject.isInvasive;
              parentProject.isInvasive = parentProject.children.any(
                (element) => element.isInvasive == true,
              );
              pushToWebSocket('update', 'project', {
                "id": parentProject.id.hexString,
                "changedFields": {"isInvasive": parentProject.isInvasive},
              });
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
          pushToWebSocket('update', 'project', {
            "id": parentProject.id.hexString,
            "changedFields": {
              "sections": {"id": id, "count": length, "coverUrl": url},
            },
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

          pushToWebSocket('update', 'location', {
            "id": parentLocation.id.hexString,
            "changedFields": {
              "sections": {"id": id, "count": length, "coverUrl": url},
            },
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
        "changedFields": {
          "invasiveimages": currentInvasiveSection.invasiveimages,
        },
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
      pushToWebSocket('addImages', 'invasiveSection', {
        "id": currentConclusiveSection.id.hexString,
        "changedFields": {
          "conclusiveimages": currentConclusiveSection.conclusiveimages,
        },
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
        "changedFields": {
          "postinvasiverepairsrequired": postInvasiveRepairsRequired,
          "invasiveDescription": description,
        },
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
        "changedFields": {
          "propowneragreed": propOwnerAgreed,
          "invasiverepairsinspectedandcompleted": invasiveRepairsCompleted,
          "aweconclusive": aweConclusive,
          "eeeconclusive": eeeConclusive,
          "lbcconclusive": lbcConclusive,
          "conclusiveconsiderations": description,
        },
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
      pushToWebSocket('removeUrl', 'conclusiveSection', {
        "id": localConclusiveSection.id.hexString,
        "changedFields": {"conclusiveimages": url},
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
      pushToWebSocket('removeUrl', 'invasiveSection', {
        "id": localInvasiveSection.id.hexString,
        "changedFields": {"invasiveimages": url},
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

  void saveUnsyncedData(Map<String, Object> socketData) {
    try {
      realm.write(() {
        realm.add<UnsyncedData>(
          UnsyncedData(
            ObjectId(),
            socketData['action'] as String,
            socketData['collectionName'] as String,
            jsonEncode(socketData['jsonData']),
            DateTime.now().toString(),
          ),
          update: true,
        );
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void pushToWebSocket(
    String eventName,
    String collectionName,
    Map<String, dynamic> data, {
    bool isDelete = false,
  }) {
    try {
      Map<String, Object> socketData = {};
      final messageId = ObjectId().hexString;
      if (isDelete) {
        socketData = {
          "messageId": messageId,
          "collectionName": collectionName,
          "action": "delete",
          "data": jsonEncode({"id": data['id']}),
        };
      } else {
        socketData = {
          "messageId": messageId,
          "collectionName": collectionName,
          "action": eventName,
          "data": jsonEncode(data),
        };
      }
      if (!syncService.pushToWebSocket(socketData, messageId)) {
        saveUnsyncedData(socketData);
      }
    } catch (e) {
      debugPrint("Error pushing to WebSocket: $e");
      //saveUnsyncedData(sock);
    }
  }
}
