import 'dart:async';

import 'package:cbl/cbl.dart';
import 'package:flutter/material.dart';

import '../../bloc/settings_bloc.dart';
import '../../bloc/users_bloc.dart';
import '../../models/couchbase/couchbase_models.dart';
import 'database_provider.dart';
import 'image_repository.dart';

class ProjectRepository {
  /// Fetch projects assigned to the logged-in user
  Future<List<Project>> fetchAssignedProjects() async {
    try {
      final loggedInUser = usersBloc.userDetails.username;
      final query = QueryBuilder.createAsync()
          .select(
            SelectResult.expression(Meta.id).as('docId'),
            SelectResult.all(),
          )
          .from(
            DataSource.collection(
              _databaseProvider.projectCollection,
            ).as('Project'),
          )
          .where(
            Expression.property(attributeDocumentType)
                .equalTo(Expression.string(projectDocumentType))
                .and(
                  ArrayFunction.contains(
                    Expression.property('assignedto'),
                    value: Expression.string(loggedInUser),
                  ),
                )
                .and(
                  Expression.property('iscomplete')
                      .equalTo(Expression.boolean(false))
                      .or(Expression.property('iscomplete').isNullOrMissing()),
                ),
          );

      final result = await query.execute();
      final results = await result.allResults();

      return results.map((row) {
        final map = row.dictionary('Project')!.toPlainMap();
        final project = Project.fromDocument(map);
        final id = row.string('docId');
        if (id != null && id.isNotEmpty) project.id = id;
        return project;
      }).toList();
    } catch (e) {
      debugPrint('Error fetching assigned projects: $e');
      return [];
    }
  }

  final DatabaseProvider _databaseProvider;
  final ImageRepository _imageRepository;

  ProjectRepository(this._databaseProvider, this._imageRepository);

  final String projectDocumentType = 'Project';
  final String attributeDocumentType = 'docType';
  //add a method to fetch all projects
  //Future<List<Project>> fetchAllProjects() async {
  Future<AsyncListenStream<QueryChange<ResultSet>>?>? fetchAllProjects() async {
    try {
      final query = QueryBuilder.createAsync()
          .select(SelectResult.all())
          .from(
            DataSource.collection(
              _databaseProvider.projectCollection,
            ).as('Project'),
          )
          .where(
            Expression.property(
              attributeDocumentType,
            ).equalTo(Expression.string(projectDocumentType)),
          );
      // final result = await query.execute();
      // final results = await result.allResults();
      // return results
      //     .map(
      //       (result) => Project.fromDocument(
      //         result.dictionary('Project')!.toPlainMap(),
      //       ),
      //     )
      //     .toList();
      return query.changes();
    } catch (e) {
      debugPrint('Error fetching all projects: $e');
    }
    return null;
  }

  /// Fetch all forms for the logged-in user's company (mirrors Realm getAllForms).
  Future<List<LocationForm>> getAllForms() async {
    try {
      final company = usersBloc.userDetails.companyidentifer;
      if (company == null || company.isEmpty) {
        debugPrint('getAllForms: no company identifier');
        return [];
      }
      if (_databaseProvider.e3inspectionsDatabase == null) return [];

      final query = QueryBuilder.createAsync()
          .select(
            SelectResult.expression(Meta.id).as('docId'),
            SelectResult.all(),
          )
          .from(
            DataSource.collection(
              _databaseProvider.formCollection,
            ).as('LocationForm'),
          )
          .where(
            Expression.property(attributeDocumentType)
                .equalTo(Expression.string('LocationForm'))
                .and(
                  Expression.property(
                    'companyIdentifier',
                  ).equalTo(Expression.string(company)),
                ),
          );

      final result = await query.execute();
      final rows = await result.allResults();

      return rows
          .map((row) {
            final data = row.dictionary('LocationForm')?.toPlainMap();
            if (data == null) return null;
            final form = LocationForm.fromDocument(data);
            final docId = row.string('docId');
            if (docId != null && docId.isNotEmpty) form.id = docId;
            return form;
          })
          .whereType<LocationForm>()
          .toList();
    } catch (e) {
      debugPrint('Error fetching forms: $e');
      return [];
    }
  }

  /// Fetch a single project by its ID
  Future<Project?> fetchProjectById(String projectId) async {
    try {
      final doc = await _databaseProvider.projectCollection.document(projectId);
      if (doc == null) return null;

      final model = Project.fromDocument(doc.toPlainMap(), id: doc.id);
      return model;
    } catch (e) {
      debugPrint('Error fetching project by id: $e');
      return null;
    }
  }

  Future<bool> updateProject(Project project) async {
    try {
      await createOrUpdateProject(project);
      return true;
    } catch (e) {
      debugPrint('Error updating project: $e');
      return false;
    }
  }

  /// Update project URL and optionally queue an image doc when offline
  Future<bool> updateProjectUrl(Project project, String url) async {
    try {
      if (_databaseProvider.isAppOfflineMode() ||
          !appSettings.activeConnection) {
        final image = DeckImage(
          localUrl: url,
          remoteUrl: url,
          isuploaded: url.startsWith('http'),
          parentid: project.id,
          parenttype: 'project',
          sectiontype: 'projectimage',
          sectionname: project.name,
          uploadedBy: usersBloc.userDetails.username,
        );
        await _imageRepository.saveImage(image);
      }

      project.url = url;
      await createOrUpdateProject(project);
      return true;
    } catch (e) {
      debugPrint('Error updating project url: $e');
      return false;
    }
  }

  /// Create or update project with fields similar to Realm's addupdateProject
  Future<bool> addupdateProject(
    Project project,
    String name,
    String address,
    String description,
    String userName,
    double longitude,
    double latitude,
    String? formId,
    bool isNewProject,
  ) async {
    try {
      String loggedInUser = usersBloc.userDetails.username ?? '';

      final creationtime = DateTime.now().toUtc().toIso8601String();

      project.latitude = latitude;
      project.longitude = longitude;
      project.name = name;
      if (isNewProject) {
        project.formId = formId;
      }
      project.companyIdentifier = usersBloc.userDetails.companyidentifer;
      project.address = address;
      project.description = description;
      if (isNewProject) {
        project.createdby = userName;
        if (!project.assignedto.contains(loggedInUser)) {
          project.assignedto.add(loggedInUser);
        }
      } else {
        project.lasteditedby = userName;
      }

      project.createdat ??= creationtime;
      project.editedat = DateTime.now().toUtc().toIso8601String();
      await createOrUpdateProject(project);
      return true;
    } catch (e) {
      debugPrint('Error adding/updating project: $e');
      return false;
    }
  }

  /// Save or update project document helper
  Future<void> createOrUpdateProject(Project project) async {
    final id = project.id ?? CouchbaseDocument.generateId();
    project.id = id;
    final doc = MutableDocument.withId(id, project.toDocument());
    await _databaseProvider.projectCollection.saveDocument(doc);
  }

  /// Update children for a project (add or modify a Child)
  Future<void> updateProjectChildren(
    String childId,
    String parentId,
    bool isInvasive,
    String name,
    String type,
    String description,
  ) async {
    try {
      debugPrint(
        'updateProjectChildren called childId=$childId parentId=$parentId',
      );
      final parentDoc = await _databaseProvider.projectCollection.document(
        parentId,
      );
      if (parentDoc == null) return;
      final project = Project.fromDocument(
        parentDoc.toPlainMap(),
        id: parentDoc.id,
      );
      debugPrint('Existing children count: ${project.children.length}');

      final found = project.children.where((c) => c.id == childId);
      if (found.isEmpty) {
        project.children.add(
          Child(
            id: childId,
            name: name,
            type: type,
            description: description,
            url: '',
            isInvasive: isInvasive,
          ),
        );
        debugPrint('Added child $childId to project $parentId');
      } else {
        final index = project.children.indexWhere((c) => c.id == childId);
        if (index != -1) {
          project.children[index].name = name;
          project.children[index].description = description;
          project.children[index].type = type;
          project.children[index].isInvasive = isInvasive;
        }
      }
      // Recompute project isInvasive from all children
      project.isInvasive = project.children.any((c) => c.isInvasive);

      await createOrUpdateProject(project);
      debugPrint('Project $parentId children now: ${project.children.length}');
      // verify saved document contents
      try {
        await _databaseProvider.projectCollection.document(parentId);
      } catch (e) {
        debugPrint('Error reading saved doc after save: $e');
      }
      //notifyListeners();
    } catch (e) {
      debugPrint('Error updating project children: $e');
    }
  }

  /// Remove a child from a parent project
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

      await createOrUpdateProject(project);
      //notifyListeners();
    } catch (e) {
      debugPrint('Error deleting project child: $e');
    }
  }

  /// Update a child's url inside a project
  Future<void> updateChildUrl(
    String childId,
    String parentId,
    String url,
  ) async {
    try {
      final parentDoc = await _databaseProvider.projectCollection.document(
        parentId,
      );
      if (parentDoc == null) return;
      final project = Project.fromDocument(
        parentDoc.toPlainMap(),
        id: parentDoc.id,
      );

      final found = project.children.where((c) => c.id == childId);
      if (found.isNotEmpty) {
        final child = found.first;
        child.url = url;
        await createOrUpdateProject(project);
        //notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating child url: $e');
    }
  }

  /// Delete a project document by id
  Future<void> deleteProject(String projectId) async {
    try {
      final doc = await _databaseProvider.projectCollection.document(projectId);
      if (doc != null) {
        await _databaseProvider.projectCollection.deleteDocument(doc);
      }
    } catch (e) {
      debugPrint('Error deleting project: $e');
      rethrow;
    }
  }

  /// Update assignment list for a project
  Future<bool> updateAssignment(
    String projectId,
    List<String> assignees,
  ) async {
    try {
      final doc = await _databaseProvider.projectCollection.document(projectId);
      if (doc == null) return false;
      final project = Project.fromDocument(doc.toPlainMap(), id: doc.id);
      project.assignedto = assignees;
      await createOrUpdateProject(project);
      return true;
    } catch (e) {
      debugPrint('Error updating assignment: $e');
      return false;
    }
  }

  /// Stream of document IDs that have changed in the project collection
  Future<Stream<String>> watchProjectCollectionDocumentIds() async {
    final controller = StreamController<String>.broadcast();
    final listenerToken = await _databaseProvider.projectCollection
        .addChangeListener((change) {
          for (final docId in change.documentIds) {
            controller.add(docId);
          }
        });
    controller.onCancel = () {
      _databaseProvider.projectCollection.removeChangeListener(listenerToken);
      controller.close();
    };
    return controller.stream;
  }
}
