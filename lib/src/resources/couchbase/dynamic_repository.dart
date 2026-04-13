import 'package:cbl/cbl.dart';
import 'package:flutter/material.dart';
import '../../bloc/users_bloc.dart';
import '../../models/couchbase/couchbase_models.dart';
import 'database_provider.dart';
import 'image_repository.dart';
import 'location_repository.dart';

class DynamicRepository {
  final DatabaseProvider _databaseProvider;
  final ImageRepository _imageRepository;
  final UsersBloc _usersBloc;
  final LocationRepository _locationRepository;

  DynamicRepository(
    this._databaseProvider,
    this._imageRepository,
    this._usersBloc,
    this._locationRepository,
  );

  Future<String> createDynamicSection(
    DynamicVisualSection dynamicSection,
  ) async {
    try {
      final id = CouchbaseDocument.generateId();
      final doc = MutableDocument.withId(id, dynamicSection.toDocument());
      await _databaseProvider.dynamicSectionCollection.saveDocument(doc);
      return id;
    } catch (e) {
      debugPrint('Error creating dynamic section: $e');
      rethrow;
    }
  }

  Future<DynamicVisualSection?> getDynamicSection(String id) async {
    try {
      final doc = await _databaseProvider.dynamicSectionCollection.document(id);
      if (doc != null) {
        final model = DynamicVisualSection.fromDocument(doc.toPlainMap());
        model.id = doc.id;
        return model;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching dynamic section: $e');
      return null;
    }
  }

  Future<DynamicVisualSection?> getDynamicVisualSection(String id) async {
    try {
      final doc = await _databaseProvider.dynamicSectionCollection.document(id);
      if (doc != null) {
        final model = DynamicVisualSection.fromDocument(doc.toPlainMap());
        model.id = id; // Preserve the document ID
        return model;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching dynamic section: $e');
      return null;
    }
  }

  Future<String> createOrUpdateDynamicSection(
    DynamicVisualSection section, {
    String? docId,
  }) async {
    try {
      final id = docId ?? CouchbaseDocument.generateId();
      final doc = MutableDocument.withId(id, section.toDocument());
      await _databaseProvider.dynamicSectionCollection.saveDocument(doc);
      return id;
    } catch (e) {
      debugPrint('Error saving dynamic section: $e');
      rethrow;
    }
  }

  Future<String> deleteDynamicSectionById(String id) async {
    try {
      final doc = await _databaseProvider.dynamicSectionCollection.document(id);
      if (doc != null) {
        await _databaseProvider.dynamicSectionCollection.deleteDocument(doc);
      }
      return 'success';
    } catch (e) {
      debugPrint('Error deleting dynamic section: $e');
      return 'failed';
    }
  }

  Future<DynamicVisualSection> getNewDynamicSection(String parentId) async {
    return DynamicVisualSection(
      parentid: parentId,
      name: '',
      additionalconsiderations: '',
      questions: const [],
      sections: const [],
      images: const [],
    );
  }

  /// Fetch a LocationForm by its document ID to retrieve template questions.
  Future<LocationForm?> getFormById(String formId) async {
    try {
      final doc = await _databaseProvider.formCollection.document(formId);
      if (doc != null) {
        final form = LocationForm.fromDocument(doc.toPlainMap());
        form.id = doc.id;
        return form;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching form by id: $e');
      return null;
    }
  }

  Future<bool> addDynamicImagesUrl(
    String sectionName,
    String sectionId,
    DynamicVisualSection currentDynamicSection,
    List<String> localPaths,
    List<String> urls,
  ) async {
    try {
      for (int i = 0; i < localPaths.length; i++) {
        final remoteUrl = i < urls.length ? urls[i] : '';
        final image = DeckImage(
          localUrl: localPaths[i],
          remoteUrl: remoteUrl,
          isuploaded: remoteUrl.startsWith('http'),
          parentid: currentDynamicSection.id,
          parenttype: 'dynamicSection',
          sectiontype: 'dynamicSectionImage',
          sectionname: sectionName,
          uploadedBy: _usersBloc.userDetails.username,
        );
        await _imageRepository.saveImage(image);

        // Replace local path with remote URL in the images list
        if (remoteUrl.isNotEmpty) {
          if (currentDynamicSection.images.contains(localPaths[i])) {
            final index = currentDynamicSection.images.indexOf(localPaths[i]);
            currentDynamicSection.images[index] = remoteUrl;
          } else {
            currentDynamicSection.images.add(remoteUrl);
          }
        }
      }

      final doc = MutableDocument.withId(
        currentDynamicSection.id as String,
        currentDynamicSection.toDocument(),
      );
      await _databaseProvider.dynamicSectionCollection.saveDocument(doc);

      final newCoverUrl =
          currentDynamicSection.images.isNotEmpty
              ? currentDynamicSection.images.last
              : '';
      await _locationRepository.updateImageCount(
        currentDynamicSection.parenttype,
        currentDynamicSection.id as String,
        currentDynamicSection.parentid as String,
        currentDynamicSection.images.length,
        newCoverUrl,
      );

      return true;
    } catch (e) {
      debugPrint('Error adding dynamic images url: $e');
      return false;
    }
  }

  Future<DynamicVisualSection?> getDynamicSectionByParentId(
    String parentId,
  ) async {
    try {
      final query = QueryBuilder.createAsync()
          .select(SelectResult.all())
          .from(
            DataSource.collection(
              _databaseProvider.dynamicSectionCollection,
            ).as('DynamicSection'),
          )
          .where(
            Expression.property(
              'parentid',
            ).equalTo(Expression.string(parentId)),
          );
      final result = await query.execute();
      final results = await result.allResults();
      if (results.isEmpty) {
        return await getNewDynamicSection(parentId);
      }
      final model = DynamicVisualSection.fromDocument(
        results.first.toPlainMap(),
      );
      //model.id = results.first.id;
      return model;
    } catch (e) {
      debugPrint('Error fetching dynamic section by parentId: $e');
      return null;
    }
  }

  Future<bool> addupdateDynamicSection(
    DynamicVisualSection dynamicSection,
    String name,
    String description,
    bool isNewSection,
    String userFullName,
  ) async {
    try {
      dynamicSection.name = name;
      if (isNewSection) {
        dynamicSection.createdby = userFullName;
      } else {
        dynamicSection.lasteditedby = userFullName;
      }
      var creationtime = DateTime.now().toString();
      dynamicSection.createdat ??= creationtime;
      dynamicSection.editedat = DateTime.now().toString();
      final id = CouchbaseDocument.generateId();
      final doc = MutableDocument.withId(id, dynamicSection.toDocument());
      await _databaseProvider.dynamicSectionCollection.saveDocument(doc);
      return true;
    } catch (e) {
      debugPrint('Error adding/updating dynamic section: $e');
      return false;
    }
  }

  Future<DynamicVisualSection> addupdateDynamicVisualSection({
    required DynamicVisualSection section,
    required String name,
    required String concerns,
    required List<Question> questions,
    required bool invasiveReviewRequired,
    required bool isNewSection,
    required String userFullName,
    required bool unitUnavailable,
  }) async {
    try {
      section.name = name;
      section.additionalconsiderations = concerns;
      section.questions = questions;
      section.furtherinvasivereviewrequired = invasiveReviewRequired;
      section.unitUnavailable = unitUnavailable;

      if (isNewSection) {
        section.createdby = userFullName;
        section.createdat = DateTime.now().toString();
        if (section.id == null || section.id!.isEmpty) {
          section.id = CouchbaseDocument.generateId();
        }
      } else {
        section.lasteditedby = userFullName;
      }
      section.editedat = DateTime.now().toString();

      final doc = MutableDocument.withId(
        section.id as String,
        section.toDocument(),
      );
      await _databaseProvider.dynamicSectionCollection.saveDocument(doc);

      final coverUrl = section.images.isNotEmpty ? section.images.first : null;
      await _locationRepository.updateLocationSection(
        section.parenttype,
        section.id as String,
        section.parentid as String,
        section.name,
        null,
        false,
        section.furtherinvasivereviewrequired,
        null,
        section.images.length,
        coverUrl: coverUrl,
      );

      return section;
    } catch (e) {
      debugPrint('Error adding/updating dynamic visual section: $e');
      rethrow;
    }
  }

  Future<void> deleteDynamicVisualSection(DynamicVisualSection section) async {
    try {
      final doc = await _databaseProvider.dynamicSectionCollection.document(
        section.id as String,
      );
      if (doc != null) {
        await _databaseProvider.dynamicSectionCollection.deleteDocument(doc);
      }
    } catch (e) {
      debugPrint('Error deleting dynamic visual section: $e');
      rethrow;
    }
  }

  Future<bool> removeDynamicImageUrl(
    DynamicVisualSection localDynamicSection,
    String url,
  ) async {
    try {
      localDynamicSection.images.remove(url);
      // caller should provide sectionId if needed; generate a new id here
      final id = CouchbaseDocument.generateId();
      final doc = MutableDocument.withId(id, localDynamicSection.toDocument());
      await _databaseProvider.dynamicSectionCollection.saveDocument(doc);
      return true;
    } catch (e) {
      debugPrint('Error removing dynamic image url: $e');
      return false;
    }
  }
}
