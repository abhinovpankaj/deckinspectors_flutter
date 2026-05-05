import 'dart:async';

import 'package:cbl/cbl.dart';
import 'package:flutter/material.dart';

import '../../bloc/settings_bloc.dart';
import '../../bloc/users_bloc.dart';
import '../../models/couchbase/couchbase_models.dart';
import 'database_provider.dart';
import 'image_repository.dart';
import 'project_repository.dart';
import 'subproject_repository.dart';

class LocationRepository {
  final DatabaseProvider _databaseProvider;
  final SubprojectRepository _subprojectRepository;
  final ImageRepository _imageRepository;
  final ProjectRepository _projectRepository;
  final UsersBloc _usersBloc;
  final AppSettings _appSettings;

  LocationRepository(
    this._databaseProvider,
    this._projectRepository,
    this._subprojectRepository,
    this._imageRepository,
    this._usersBloc,
    this._appSettings,
  );
  final String locationDocumentType = 'location';
  final String attributeDocumentType = 'documentType';

  Future<void> createLocation(Location location) async {
    try {
      final id = CouchbaseDocument.generateId();
      final doc = MutableDocument.withId(id, location.toDocument());
      await _databaseProvider.locationCollection.saveDocument(doc);
    } catch (e) {
      debugPrint('Error creating location: $e');
    }
  }

  /// Fetch a single location by id
  Future<Location?> fetchLocationById(String id) async {
    try {
      final doc = await _databaseProvider.locationCollection.document(id);
      if (doc == null) return null;
      final model = Location.fromDocument(doc.toPlainMap(), id: doc.id);
      return model;
    } catch (e) {
      debugPrint('Error fetching location by id: $e');
      return null;
    }
  }

  Future<void> updateImageUploadStatus(
    Location parentLocation,
    String sectionId,
    bool status,
  ) async {
    var found =
        parentLocation.sections
            .where((element) => element.id == sectionId)
            .toList();
    if (found.isNotEmpty) {
      found.first.isuploading = status;
      try {
        // Update the parentLocation's sections list
        final doc = MutableDocument.withId(
          parentLocation.id as String,
          parentLocation.toDocument(),
        );
        await _databaseProvider.locationCollection.saveDocument(doc);
      } catch (e) {
        debugPrint('Error updating image upload status in Couchbase Lite: $e');
      }
    }
  }

  Future<bool> updateLocationUrl(Location currentLocation, String url) async {
    try {
      if (_databaseProvider.isAppOfflineMode() ||
          !_appSettings.activeConnection) {
        final image = DeckImage(
          localUrl: url,
          remoteUrl: url,
          isuploaded: url.startsWith('http'),
          parentid: currentLocation.id,
          parenttype: 'location',
          sectiontype: 'locationImage',
          sectionname: currentLocation.name,
          uploadedBy: _usersBloc.userDetails.username,
        );
        await _imageRepository.saveImage(image);
      }

      if (currentLocation.parenttype == 'project') {
        await _projectRepository.updateChildUrl(
          currentLocation.id as String,
          currentLocation.parentid,
          url,
        );
      } else {
        await _subprojectRepository.updateChildUrl(
          currentLocation.id as String,
          currentLocation.parentid,
          url,
        );
      }

      currentLocation.url = url;
      final doc = MutableDocument.withId(
        currentLocation.id as String,
        currentLocation.toDocument(),
      );
      await _databaseProvider.locationCollection.saveDocument(doc);
      return true;
    } catch (e) {
      debugPrint('Error updating location url: $e');
      return false;
    }
  }

  Future<String> deleteLocation(Location location) async {
    try {
      if (location.parenttype == 'project') {
        await _projectRepository.deleteProjectChildren(
          location.id as String,
          location.parentid,
        );
      } else {
        await _subprojectRepository.deleteSubProjectChildren(
          location.id as String,
          location.parentid,
        );
      }

      final doc = await _databaseProvider.locationCollection.document(
        location.id as String,
      );
      if (doc != null) {
        await _databaseProvider.locationCollection.deleteDocument(doc);
      }
      return 'success';
    } catch (e) {
      debugPrint('Error deleting location: $e');
      return 'failed';
    }
  }

  Future<bool> addupdateLocation(
    Location location,
    String name,
    String description,
    String fullUserName,
    bool isNewLocation,
  ) async {
    try {
      final creationtime = DateTime.now().toString();

      location.name = name;
      location.description = description;
      if (isNewLocation) {
        location.createdby = fullUserName;
      } else {
        location.lasteditedby = fullUserName;
      }
      location.createdat ??= creationtime;
      location.editedat = DateTime.now().toString();
      // ensure id exists before updating parent or saving
      final id = location.id ?? CouchbaseDocument.generateId();
      location.id = id;

      if (location.parenttype == 'project') {
        await _projectRepository.updateProjectChildren(
          location.id as String,
          location.parentid,
          location.isInvasive,
          location.name ?? '',
          location.type ?? '',
          location.description ?? '',
        );
      } else {
        await _subprojectRepository.updateSubProjectChildren(
          location.id as String,
          location.parentid,
          location.isInvasive,
          location.name ?? '',
          location.type ?? '',
          location.description ?? '',
        );
      }

      final doc = MutableDocument.withId(
        location.id as String,
        location.toDocument(),
      );
      await _databaseProvider.locationCollection.saveDocument(doc);
      return true;
    } catch (e) {
      debugPrint('Error adding/updating location: $e');
      return false;
    }
  }

  Future<void> updateLocationSection(
    String parentType,
    String id,
    String parentid,
    String? name,
    String? visualreview,
    bool visualsignsofleak,
    bool furtherinvasivereviewrequired,
    String? conditionalassessment,
    int length, {
    String? coverUrl,
  }) async {
    //for singlelevel project
    if (parentType == 'project') {
      var doc = await _databaseProvider.projectCollection.document(parentid);

      if (doc != null) {
        final parentProject = Project.fromDocument(
          doc.toPlainMap(),
          id: doc.id,
        );
        var found = parentProject.sections.where((element) => element.id == id);
        if (found.isEmpty) {
          parentProject.sections.add(
            Section(
              id: id,
              isInvasive: furtherinvasivereviewrequired,
              name: name,
              visualreview: visualreview,
              visualsignsofleak: visualsignsofleak,
              furtherinvasivereviewrequired: furtherinvasivereviewrequired,
              conditionalassessment: conditionalassessment,
              count: length,
            ),
          );
        } else {
          final index = parentProject.sections.indexWhere((e) => e.id == id);
          if (index != -1) {
            parentProject.sections[index].name = name;
            parentProject.sections[index].visualreview = visualreview;
            parentProject.sections[index].visualsignsofleak = visualsignsofleak;
            parentProject.sections[index].conditionalassessment =
                conditionalassessment;
            parentProject.sections[index].furtherinvasivereviewrequired =
                furtherinvasivereviewrequired;
            parentProject.sections[index].count = length;
            parentProject.sections[index].isInvasive =
                furtherinvasivereviewrequired;
            if (coverUrl != null && coverUrl.isNotEmpty) {
              parentProject.sections[index].coverUrl = coverUrl;
            }
          }
        }
        final updatedDoc = MutableDocument.withId(
          parentProject.id as String,
          parentProject.toDocument(),
        );
        await _databaseProvider.projectCollection.saveDocument(updatedDoc);
      }
    } else {
      var location = await _databaseProvider.locationCollection.document(
        parentid,
      );
      if (location != null) {
        final parentLocation = Location.fromDocument(
          location.toPlainMap(),
          id: location.id,
        );
        var found = parentLocation.sections.where(
          (element) => element.id == id,
        );
        if (found.isEmpty) {
          parentLocation.sections.add(
            Section(
              id: id,
              isInvasive: furtherinvasivereviewrequired,
              name: name,
              visualreview: visualreview,
              visualsignsofleak: visualsignsofleak,
              furtherinvasivereviewrequired: furtherinvasivereviewrequired,
              conditionalassessment: conditionalassessment,
              count: length,
            ),
          );
        } else {
          final index = parentLocation.sections.indexWhere((e) => e.id == id);
          if (index != -1) {
            parentLocation.sections[index].name = name;
            parentLocation.sections[index].visualreview = visualreview;
            parentLocation.sections[index].visualsignsofleak =
                visualsignsofleak;
            parentLocation.sections[index].conditionalassessment =
                conditionalassessment;
            parentLocation.sections[index].furtherinvasivereviewrequired =
                furtherinvasivereviewrequired;
            parentLocation.sections[index].count = length;
            parentLocation.sections[index].isInvasive =
                furtherinvasivereviewrequired;
            if (coverUrl != null && coverUrl.isNotEmpty) {
              parentLocation.sections[index].coverUrl = coverUrl;
            }
          }
        }
        //set invasive property of location.
        parentLocation.isInvasive = parentLocation.sections.any(
          (element) => element.furtherinvasivereviewrequired == true,
        );
        //update parents
        if (parentLocation.parenttype == 'project') {
          var projDoc = await _databaseProvider.projectCollection.document(
            parentLocation.parentid,
          );
          if (projDoc != null) {
            final parentProject = Project.fromDocument(
              projDoc.toPlainMap(),
              id: projDoc.id,
            );

            var childLocation = parentProject.children.where(
              (element) => element.id == parentLocation.id,
            );
            if (childLocation.isNotEmpty) {
              childLocation.first.isInvasive = parentLocation.isInvasive;
              parentProject.isInvasive = parentProject.children.any(
                (element) => element.isInvasive == true,
              );
              final updatedDoc = MutableDocument.withId(
                parentProject.id as String,
                parentProject.toDocument(),
              );
              await _databaseProvider.projectCollection.saveDocument(
                updatedDoc,
              );
            }
          }
        }
        if (parentLocation.parenttype == 'subproject') {
          var subDoc = await _databaseProvider.subProjectCollection.document(
            parentLocation.parentid,
          );
          if (subDoc != null) {
            final parentSubProject = SubProject.fromDocument(
              subDoc.toPlainMap(),
              id: subDoc.id,
            );
            var childLocation = parentSubProject.children.where(
              (element) => element.id == parentLocation.id,
            );
            if (childLocation.isNotEmpty) {
              childLocation.first.isInvasive = parentLocation.isInvasive;
              parentSubProject.isInvasive = parentSubProject.children.any(
                (element) => element.isInvasive == true,
              );
              final updatedSubDoc = MutableDocument.withId(
                parentSubProject.id as String,
                parentSubProject.toDocument(),
              );
              await _databaseProvider.subProjectCollection.saveDocument(
                updatedSubDoc,
              );
            }
            // update parent project
            var projDoc = await _databaseProvider.projectCollection.document(
              parentSubProject.parentid,
            );
            if (projDoc != null) {
              final parentProject = Project.fromDocument(
                projDoc.toPlainMap(),
                id: projDoc.id,
              );
              var childLocation = parentProject.children.where(
                (element) => element.id == parentSubProject.id,
              );
              if (childLocation.isNotEmpty) {
                childLocation.first.isInvasive = parentSubProject.isInvasive;
                parentProject.isInvasive = parentProject.children.any(
                  (element) => element.isInvasive == true,
                );
                final updatedDoc = MutableDocument.withId(
                  parentProject.id as String,
                  parentProject.toDocument(),
                );
                await _databaseProvider.projectCollection.saveDocument(
                  updatedDoc,
                );
              }
            }
          }
        }
        final updatedLocDoc = MutableDocument.withId(
          parentLocation.id as String,
          parentLocation.toDocument(),
        );
        await _databaseProvider.locationCollection.saveDocument(updatedLocDoc);
      }
    }
  }

  Future<void> updateImageCount(
    String parentType,
    String id,
    String parentid,
    int length,
    String url,
  ) async {
    try {
      if (parentType == 'project') {
        var doc = await _databaseProvider.projectCollection.document(parentid);
        if (doc != null) {
          final parentProject = Project.fromDocument(
            doc.toPlainMap(),
            id: doc.id,
          );
          var found = parentProject.sections.where(
            (element) => element.id == id,
          );
          if (found.isNotEmpty) {
            var foundChild = found.first;
            foundChild.count = length;
            if (url != '') {
              foundChild.coverUrl = url;
            }
            final updatedDoc = MutableDocument.withId(
              parentProject.id as String,
              parentProject.toDocument(),
            );
            await _databaseProvider.projectCollection.saveDocument(updatedDoc);
          }
        }
      } else {
        var doc = await _databaseProvider.locationCollection.document(parentid);
        if (doc != null) {
          final parentLocation = Location.fromDocument(
            doc.toPlainMap(),
            id: doc.id,
          );
          var found = parentLocation.sections.where(
            (element) => element.id == id,
          );
          if (found.isNotEmpty) {
            var foundChild = found.first;
            foundChild.count = length;
            if (url != '') {
              foundChild.coverUrl = url;
            }
            final updatedDoc = MutableDocument.withId(
              parentLocation.id as String,
              parentLocation.toDocument(),
            );
            await _databaseProvider.locationCollection.saveDocument(updatedDoc);
          }
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  /// Stream of document IDs that have changed in the location collection
  Future<Stream<String>> watchLocationCollectionDocumentIds() async {
    final controller = StreamController<String>.broadcast();
    final listenerToken = await _databaseProvider.locationCollection
        .addChangeListener((change) {
          for (final docId in change.documentIds) {
            controller.add(docId);
          }
        });
    controller.onCancel = () {
      _databaseProvider.locationCollection.removeChangeListener(listenerToken);
      controller.close();
    };
    return controller.stream;
  }
}
