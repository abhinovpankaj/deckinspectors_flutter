import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:realm/realm.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../bloc/images_bloc.dart';
import '../bloc/notificationcontroller.dart';
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
  static late bool offlineModeOn;
  bool isWaiting = false;
  String loggedInUser;
  String company;
  RealmLocalServices(this.company, this.loggedInUser) {
    SharedPreferences.getInstance().then((value) {
      var configValue = value.getString('appSync') ?? 'true';
      if (configValue == 'false') {
        offlineModeOn = true;
      } else {
        offlineModeOn = false;
      }
      if (offlineModeOn) {
        realm.syncSession.pause();
      }
    });

    realm = Realm(Configuration.local([
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
      Question.schema
    ]));
  }
  SyncData getUnsyncedData() {
    final unsyncedProjects =
        realm.all<Project>().where((project) => !project.isSynced).toList();
    final unsyncedSubProjects = realm
        .all<SubProject>()
        .where((subProject) => !subProject.isSynced)
        .toList();
    final unsyncedLocations =
        realm.all<Location>().where((location) => !location.isSynced).toList();
    final unsyncedVisualSections = realm
        .all<VisualSection>()
        .where((section) => !section.isSynced)
        .toList();
    final unsyncedInvasiveSections = realm
        .all<InvasiveSection>()
        .where((section) => !section.isSynced)
        .toList();
    final unsyncedConclusiveSections = realm
        .all<ConclusiveSection>()
        .where((section) => !section.isSynced)
        .toList();
    final unsyncedDeckImages =
        realm.all<DeckImage>().where((image) => !image.isUploaded).toList();
    final unsyncedDynamicVisualSections = realm
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
      notifyListeners();
    } catch (e) {
      //handle the exception
    }
  }

  String deleteProject(Project project) {
    try {
      realm.write(() => realm.delete(project));
      notifyListeners();
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
            usersBloc.userDetails.username as String);
        realm.write(() {
          realm.add<DeckImage>(image, update: true);
        });
      }
      realm.write(() {
        project.url = url;
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
      bool isNewProject) {
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
      return true;
    } catch (e) {
      return false;
    }
  }

//Update Project Children data
  void updateProjectChildren(ObjectId childId, ObjectId parentId,
      bool isInvasive, String name, String type, String description) {
    var parentProject = realm.find<Project>(parentId);

    if (parentProject != null) {
      parentProject.isInvasive = isInvasive;
      var found =
          parentProject.children.where((element) => element.id == childId);
      if (found.isEmpty) {
        parentProject.children.add(Child(childId, isInvasive,
            name: name, type: type, description: description, url: ""));
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
      var foundChild =
          parentProject.children.firstWhere((element) => element.id == childId);
      parentProject.children.remove(foundChild);
    }
  }

  void updateChildUrl(ObjectId childId, ObjectId parentId, String url) {
    var parentProject = realm.find<Project>(parentId);
    try {
      if (parentProject != null) {
        var found =
            parentProject.children.where((element) => element.id == childId);

        var foundChild = found.first;

        foundChild.url = url;

        // found = parentProject.invasiveChildren
        //     .where((element) => element.id == childId);

        // foundChild = found.first;

        // foundChild.url = url;
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
      var found =
          parentProject.children.where((element) => element.id == childId);
      if (found.isEmpty) {
        parentProject.children.add(Child(childId, isInvasive,
            name: name, type: type, description: description, url: ""));
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
      var foundChild =
          parentProject.children.firstWhere((element) => element.id == childId);
      parentProject.children.remove(foundChild);
    }
  }

  void updateSubChildUrl(ObjectId childId, ObjectId parentId, String url) {
    var parentProject = realm.find<SubProject>(parentId);
    if (parentProject != null) {
      var found =
          parentProject.children.where((element) => element.id == childId);

      var foundChild = found.first;

      foundChild.url = url;

      // found = parentProject.invasiveChildren
      //     .where((element) => element.id == childId);

      // foundChild = found.first;

      // foundChild.url = url;
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
      realm.write(() {
        deleteProjectChildren(subProject.id, subProject.parentid);
        realm.delete(subProject);
      });
      notifyListeners();
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
            usersBloc.userDetails.username as String);
        realm.write(() {
          realm.add<DeckImage>(image, update: true);
        });
      }
      realm.write(() {
        updateChildUrl(subProject.id, subProject.parentid, url);
        subProject.url = url;
      });

      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  bool addupdateSubProject(SubProject subProject, String name,
      String description, bool isNewBuilding, String fullUserName) {
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
            subProject.description as String);
        realm.add<SubProject>(subProject, update: true);
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
            usersBloc.userDetails.username as String);
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
      return true;
    } catch (e) {
      return false;
    }
  }

  String deleteLocation(Location location) {
    try {
      realm.write(() {
        if (location.parenttype == 'project') {
          deleteProjectChildren(location.id, location.parentid);
        } else {
          deleteSubProjectChildren(location.id, location.parentid);
        }

        realm.delete(location);
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

  bool addupdateLocation(Location location, String name, String description,
      String fullUserName, bool isNewLocation) {
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
              location.description as String);
          // updateProjectInvasiveChildren(
          //     location.id,
          //     location.parentid,
          //     location.name as String,
          //     location.type as String,
          //     location.description as String);
        } else {
          updateSubProjectChildren(
              location.id,
              location.parentid,
              location.isInvasive,
              location.name as String,
              location.type as String,
              location.description as String);
          // updateSubProjectInvasiveChildren(
          //     location.id,
          //     location.parentid,
          //     location.name as String,
          //     location.type as String,
          //     location.description as String);
        }
        realm.add<Location>(location, update: true);
      });
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
      realm.write(() {
        deleteLocationSection(
            section.parenttype, section.id, section.parentid, false);
        realm.delete(section);
      });
      notifyListeners();
      return 'success';
    } catch (e) {
      return 'failed';
    }
  }

  String deleteVisualSectionDynamic(DynamicVisualSection section) {
    try {
      realm.write(() {
        deleteLocationSection(
            section.parenttype, section.id, section.parentid, false);
        realm.delete(section);
      });
      notifyListeners();
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
      Location parentLocation, ObjectId sectionId, bool status) {
    var found =
        parentLocation.sections.where((element) => element.id == sectionId);
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
      bool unitUnavailable) {
    try {
      realm.write(() {
        visualSection.name = name;
        visualSection.unitUnavailable = unitUnavailable;
        visualSection.additionalconsiderations = concerns;
        visualSection.exteriorelements.clear();
        visualSection.exteriorelements
            .addAll(selectedExteriorelements.map((element) => element.name));
        visualSection.waterproofingelements.clear();
        visualSection.waterproofingelements.addAll(
            selectedWaterproofingElements.map((element) => element.name));

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
            visualSection.images.length);

        realm.add(visualSection, update: true);
      });
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
      bool unitUnavailable) {
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
            visualSection.images.length);

        realm.add(visualSection, update: true);
      });
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
            localVisualSection.images.last);
      });

      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  bool removeImageUrlFromDynamic(
      DynamicVisualSection localVisualSection, String url) {
    try {
      realm.write(() {
        localVisualSection.images.remove(url);

        updateImageCount(
            localVisualSection.parenttype,
            localVisualSection.id,
            localVisualSection.parentid,
            localVisualSection.images.length,
            localVisualSection.images.last);
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

  bool addImagesUrl(VisualSection localVisualSection, List<String> localPaths,
      List<String> onlinePaths) {
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
                usersBloc.userDetails.username as String);

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
                usersBloc.userDetails.username as String);

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
            onlinePaths.last);
      });

      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  bool addImagesUrlToDynamicform(DynamicVisualSection localVisualSection,
      List<String> localPaths, List<String> onlinePaths) {
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
                usersBloc.userDetails.username as String);

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
                usersBloc.userDetails.username as String);

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
            onlinePaths.last);
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
        realm.syncSession.resume();

        final images = realm.query<DeckImage>("isUploaded == false");
        //just removing the notifications part, perhaps failing the whole method.
        if (images.isNotEmpty && !offlineModeOn) {
          NotificationController.createNewNotification();
        }
        //set device lock
        WakelockPlus.enable();
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
                image.entityName);
            if (result is ImageResponse) {
//check if the image is already added to db
              final addedImage =
                  realm.query<DeckImage>("imageLocalPath == \$0", [localPath]);
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
                    break;
                  case 'subproject':
                    var subproject = realm.find<SubProject>(parentId);
                    subproject?.url = result.url;
                    updateChildUrl(parentId, subproject?.parentid as ObjectId,
                        result.url as String);
                    break;
                  case 'location':
                    var location = realm.find<Location>(parentId);
                    location?.url = result.url;
                    updateSubChildUrl(parentId, location?.parentid as ObjectId,
                        result.url as String);
                    break;
                  case 'visualsection':
                    var visualsection = realm.find<VisualSection>(parentId);
                    if (visualsection != null) {
                      int index = visualsection.images.indexWhere(
                          (element) => element == image.imageLocalPath);
                      if (index != -1) {
                        visualsection.images[index] = result.url as String;
                        //update coverurls
                        updateImageCount(
                            visualsection.parenttype,
                            visualsection.id,
                            visualsection.parentid,
                            visualsection.images.length,
                            visualsection.images.last);
                      }
                    }
                    break;
                  case 'dynamicvisualsection':
                    var visualsection =
                        realm.find<DynamicVisualSection>(parentId);
                    if (visualsection != null) {
                      int index = visualsection.images.indexWhere(
                          (element) => element == image.imageLocalPath);
                      if (index != -1) {
                        visualsection.images[index] = result.url as String;
                        //update coverurls
                        updateImageCount(
                            visualsection.parenttype,
                            visualsection.id,
                            visualsection.parentid,
                            visualsection.images.length,
                            visualsection.images.last);
                      }
                    }
                    break;
                  case 'invasivesection':
                    var invasiveSection = realm.find<InvasiveSection>(parentId);
                    if (invasiveSection != null) {
                      int index = invasiveSection.invasiveimages.indexWhere(
                          (element) => element == image.imageLocalPath);
                      if (index != -1) {
                        invasiveSection.invasiveimages[index] =
                            result.url as String;
                      }
                    }
                    break;
                  case 'conclusivesection':
                    var conclusiveSection =
                        realm.find<ConclusiveSection>(parentId);
                    if (conclusiveSection != null) {
                      int index = conclusiveSection.conclusiveimages.indexWhere(
                          (element) => element == image.imageLocalPath);
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
      NotificationController.cancelNotifications();
      appSettings.isImageUploading = false;
      WakelockPlus.disable();
    }
  }

  void deleteLocationSection(String parentType, ObjectId id, ObjectId parentid,
      bool updateInvasiveSection) {
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
            foundChild = parentProject.sections
                .firstWhere((element) => element.id == id);

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
              var parentSubProject =
                  realm.find<SubProject>(parentLocation.parentid);
              if (parentSubProject != null) {
                // LocalChild invasiveChild = parentSubProject.invasiveChildren
                //     .firstWhere((element) => element.id == parentid);
                // parentSubProject.invasiveChildren.remove(invasiveChild);
                //remove from project as well.
                var parentProject =
                    realm.find<Project>(parentSubProject.parentid);
                if (parentProject != null) {
                  // invasiveChild = parentProject.invasiveChildren.firstWhere(
                  //     (element) => element.id == parentSubProject.id);
                  // parentProject.invasiveChildren.remove(invasiveChild);
                }
              }
            }
          } else {
            foundChild = parentLocation.sections
                .firstWhere((element) => element.id == id);
            parentLocation.sections.remove(foundChild);
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
          parentProject.sections.add(Section(id, furtherinvasivereviewrequired,
              name: name,
              visualreview: visualreview,
              visualsignsofleak: visualsignsofleak,
              furtherinvasivereviewrequired: furtherinvasivereviewrequired,
              conditionalassessment: conditionalassessment,
              count: length));
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
        var found =
            parentLocation.sections.where((element) => element.id == id);
        if (found.isEmpty) {
          parentLocation.sections.add(Section(id, furtherinvasivereviewrequired,
              name: name,
              visualreview: visualreview,
              visualsignsofleak: visualsignsofleak,
              furtherinvasivereviewrequired: furtherinvasivereviewrequired,
              conditionalassessment: conditionalassessment,
              count: length));
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
        parentLocation.isInvasive = parentLocation.sections
            .any((element) => element.furtherinvasivereviewrequired == true);
        //update parents
        if (parentLocation.parenttype == 'project') {
          var parentProject = realm.find<Project>(parentLocation.parentid);
          if (parentProject != null) {
            var childLocation = parentProject.children
                .where((element) => element.id == parentLocation.id);
            childLocation.first.isInvasive = parentLocation.isInvasive;
            parentProject.isInvasive = parentProject.children
                .any((element) => element.isInvasive == true);
          }
        }
        if (parentLocation.parenttype == 'subproject') {
          var parentSubProject =
              realm.find<SubProject>(parentLocation.parentid);
          if (parentSubProject != null) {
            var childLocation = parentSubProject.children
                .where((element) => element.id == parentLocation.id);
            childLocation.first.isInvasive = parentLocation.isInvasive;
            parentSubProject.isInvasive = parentSubProject.children
                .any((element) => element.isInvasive == true);

            var parentProject = realm.find<Project>(parentSubProject.parentid);
            if (parentProject != null) {
              var childLocation = parentProject.children
                  .where((element) => element.id == parentSubProject.id);
              childLocation.first.isInvasive = parentSubProject.isInvasive;
              parentProject.isInvasive = parentProject.children
                  .any((element) => element.isInvasive == true);
            }
          }
        }
      }
    }
  }

  void updateImageCount(String parentType, ObjectId id, ObjectId parentid,
      int length, String url) {
    try {
      if (parentType == 'project') {
        var parentProject = realm.find<Project>(parentid);

        if (parentProject != null) {
          var found =
              parentProject.sections.where((element) => element.id == id);
          var foundChild = found.first;
          foundChild.count = length;
          if (url != '') {
            foundChild.coverUrl = url;
          }

          //for inavasive sections
          // found = parentProject.invasiveSections
          //     .where((element) => element.id == id);
          // foundChild = found.first;
          // foundChild.count = length;
          // if (url != '') {
          //   foundChild.coverUrl = url;
          // }
        }
      } else {
        var parentLocation = realm.find<Location>(parentid);

        if (parentLocation != null) {
          var found =
              parentLocation.sections.where((element) => element.id == id);
          var foundChild = found.first;
          foundChild.count = length;
          if (url != '') {
            foundChild.coverUrl = url;
          }

          //for inavasive sections
          // found = parentLocation.invasiveSections
          //     .where((element) => element.id == id);
          // foundChild = found.first;
          // foundChild.count = length;
          // if (url != '') {
          //   foundChild.coverUrl = url;
          // }
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
      propowneragreed: false,
      invasiverepairsinspectedandcompleted: false,
    );
  }

  bool addInvasiveImagesUrl(String visualSectionName,
      InvasiveSection currentInvasiveSection, List<String> urls) {
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
                usersBloc.userDetails.username as String);

            realm.add<DeckImage>(image, update: true);
          }
          // VisualSection.images.addAll(urls);
        });
      }

      realm.write(() {
        currentInvasiveSection.invasiveimages.addAll(urls);
      });

      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  bool addConclusiveImagesUrl(String visualSectionName,
      ConclusiveSection currentConclusiveSection, List<String> urls) {
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
                usersBloc.userDetails.username as String);

            realm.add<DeckImage>(image, update: true);
          }
          // VisualSection.images.addAll(urls);
        });
      }

      realm.write(() {
        currentConclusiveSection.conclusiveimages.addAll(urls);
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
      return true;
    } catch (e) {
      return false;
    }
  }

  bool removeConclusiveImageUrl(
      ConclusiveSection localConclusiveSection, String url) {
    try {
      realm.write(() {
        localConclusiveSection.conclusiveimages.remove(url);
        //updateImageCount(localConclusiveSection.parenttype, localConclusiveSection.id,
        //localConclusiveSection.parentid, localConclusiveSection.images.length, "");
      });

      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  bool removeInvasiveImageUrl(
      InvasiveSection localInvasiveSection, String url) {
    try {
      realm.write(() {
        localInvasiveSection.invasiveimages.remove(url);
        //updateImageCount(localConclusiveSection.parenttype, localConclusiveSection.id,
        //localConclusiveSection.parentid, localConclusiveSection.images.length, "");
      });

      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<String>> getImagesNotUploaded(List<String> capturedImages,
      bool activeConnection, bool isNewSection) async {
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
            deckImages =
                realm.query<DeckImage>('imageLocalPath == \$0', [imgpath]);
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
}
