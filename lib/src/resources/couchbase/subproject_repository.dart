import 'dart:async';

import 'package:cbl/cbl.dart';
import 'package:flutter/material.dart';

import '../../bloc/settings_bloc.dart';
import '../../bloc/users_bloc.dart';
import '../../models/couchbase/couchbase_models.dart';
import 'database_provider.dart';
import 'image_repository.dart';
import 'project_repository.dart';

class SubprojectRepository {
  final DatabaseProvider _databaseProvider;
  final ProjectRepository _projectRepository;
  final ImageRepository _imageRepository;
  final UsersBloc _usersBloc;
  final AppSettings appSettings;

  SubprojectRepository(
    this._databaseProvider,
    this._projectRepository,
    this._imageRepository,
    this._usersBloc,
    this.appSettings,
  );
  final String subprojectDocumentType = 'subproject';
  final String attributeDocumentType = 'documentType';

  Future<void> deleteProjectChildren(String childId, String parentId) async {
    try {
      final parentDoc = await _databaseProvider.projectCollection.document(
        parentId,
      );
      if (parentDoc == null) return;
      final project = Project.fromDocument(
        parentDoc.toPlainMap(),
        id: parentDoc.id,
      );

      project.children.removeWhere((c) => c.id == childId);

      await _projectRepository.createOrUpdateProject(project);
      //notifyListeners();
    } catch (e) {
      debugPrint('Error deleting project child: $e');
    }
  }

  Future<void> deleteSubProjectChildren(String id, String parentid) async {
    try {
      final parentDoc = await _databaseProvider.subProjectCollection.document(
        parentid,
      );
      if (parentDoc == null) return;
      final subProject = SubProject.fromDocument(
        parentDoc.toPlainMap(),
        id: parentDoc.id,
      );

      subProject.children.removeWhere((c) => c.id == id);

      await createOrUpdateSubProject(subProject);
      //notifyListeners();
    } catch (e) {
      debugPrint('Error deleting subproject child: $e');
    }
  }

  Future<String> deleteSubProject(SubProject subProject) async {
    try {
      // remove from parent project children
      await deleteProjectChildren(subProject.id as String, subProject.parentid);
      final doc = await _databaseProvider.subProjectCollection.document(
        subProject.id as String,
      );
      if (doc != null) {
        await _databaseProvider.subProjectCollection.deleteDocument(doc);
      }
      return 'success';
    } catch (e) {
      debugPrint('Error deleting subproject: $e');
      return 'failed';
    }
  }

  Future<SubProject?> getSubProject(String id) async {
    try {
      final doc = await _databaseProvider.subProjectCollection.document(id);
      if (doc != null) {
        final model = SubProject.fromDocument(doc.toPlainMap(), id: doc.id);
        return model;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting subproject: $e');
      return null;
    }
  }

  Future<bool> updateSubProjectUrl(SubProject subProject, String url) async {
    try {
      if (_databaseProvider.isAppOfflineMode() ||
          !appSettings.activeConnection) {
        final image = DeckImage(
          localUrl: url,
          remoteUrl: '',
          isuploaded: false,
          parentid: subProject.id,
          parenttype: 'subProject',
          sectiontype: 'subProjectimage',
          sectionname: subProject.name,
          uploadedBy: _usersBloc.userDetails.username,
        );
        await _imageRepository.saveImage(image);
      }

      // update parent project child url
      await _projectRepository.updateChildUrl(
        subProject.id as String,
        subProject.parentid,
        url,
      );

      subProject.url = url;

      final doc = MutableDocument.withId(
        subProject.id as String,
        subProject.toDocument(),
      );
      await _databaseProvider.subProjectCollection.saveDocument(doc);

      return true;
    } catch (e) {
      debugPrint('Error updating subproject url: $e');
      return false;
    }
  }

  Future<void> updateSubProjectChildren(
    String childId,
    String parentId,
    bool isInvasive,
    String name,
    String type,
    String description,
  ) async {
    try {
      final parentDoc = await _databaseProvider.subProjectCollection.document(
        parentId,
      );
      if (parentDoc == null) return;
      final subProject = SubProject.fromDocument(
        parentDoc.toPlainMap(),
        id: parentDoc.id,
      );

      final found = subProject.children.where((c) => c.id == childId);
      if (found.isEmpty) {
        subProject.children.add(
          Child(
            id: childId,
            name: name,
            type: type,
            description: description,
            url: '',
            isInvasive: isInvasive,
          ),
        );
      } else {
        final index = subProject.children.indexWhere((c) => c.id == childId);
        if (index != -1) {
          subProject.children[index].name = name;
          subProject.children[index].description = description;
          subProject.children[index].type = type;
          subProject.children[index].isInvasive = isInvasive;
        }
      }
      // Recompute subProject isInvasive from all children
      subProject.isInvasive = subProject.children.any((c) => c.isInvasive);

      await createOrUpdateSubProject(subProject);
      //notifyListeners();
    } catch (e) {
      debugPrint('Error updating subproject children: $e');
    }
  }

  Future<void> createOrUpdateSubProject(SubProject subProject) async {
    // ensure id exists
    final id = subProject.id ?? CouchbaseDocument.generateId();
    subProject.id = id;
    final doc = MutableDocument.withId(id, subProject.toDocument());
    await _databaseProvider.subProjectCollection.saveDocument(doc);
  }

  Future<void> updateChildUrl(
    String childId,
    String parentId,
    String url,
  ) async {
    try {
      final parentDoc = await _databaseProvider.subProjectCollection.document(
        parentId,
      );
      if (parentDoc == null) return;
      final subProject = SubProject.fromDocument(parentDoc.toPlainMap());
      final found = subProject.children.where((c) => c.id == childId);
      if (found.isNotEmpty) {
        final child = found.first;
        child.url = url;
        await createOrUpdateSubProject(subProject);
        //notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating child url: $e');
    }
  }

  Future<bool> addupdateSubProject(
    SubProject subProject,
    String name,
    String description,
    bool isNewBuilding,
    String fullUserName,
  ) async {
    try {
      final creationtime = DateTime.now().toString();
      String loggedInUser = _usersBloc.userDetails.username ?? '';
      subProject.name = name;
      subProject.description = description;
      if (isNewBuilding) {
        subProject.createdby = fullUserName;
        if (!subProject.assignedto.contains(loggedInUser)) {
          subProject.assignedto.add(loggedInUser);
        }
      } else {
        subProject.lasteditedby = fullUserName;
      }
      subProject.createdat ??= creationtime;
      subProject.editedat = DateTime.now().toString();

      // ensure id exists before updating parent or saving
      final id = subProject.id ?? CouchbaseDocument.generateId();
      subProject.id = id;

      debugPrint(
        'addupdateSubProject: id=$id parent=${subProject.parentid} name=${subProject.name}',
      );

      // update parent project's children
      await _projectRepository.updateProjectChildren(
        subProject.id as String,
        subProject.parentid,
        subProject.isInvasive,
        subProject.name ?? '',
        subProject.type,
        subProject.description ?? '',
      );

      debugPrint('addupdateSubProject: updated parent ${subProject.parentid}');

      final doc = MutableDocument.withId(
        subProject.id as String,
        subProject.toDocument(),
      );
      await _databaseProvider.subProjectCollection.saveDocument(doc);
      return true;
    } catch (e) {
      debugPrint('Error adding/updating subproject: $e');
      return false;
    }
  }

  /// Stream of document IDs that have changed in the subproject collection
  Future<Stream<String>> watchSubprojectCollectionDocumentIds() async {
    final controller = StreamController<String>.broadcast();
    final listenerToken = await _databaseProvider.subProjectCollection
        .addChangeListener((change) {
          for (final docId in change.documentIds) {
            controller.add(docId);
          }
        });
    controller.onCancel = () {
      _databaseProvider.subProjectCollection.removeChangeListener(
        listenerToken,
      );
      controller.close();
    };
    return controller.stream;
  }
}
