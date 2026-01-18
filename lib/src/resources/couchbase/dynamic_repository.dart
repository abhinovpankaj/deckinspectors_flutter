import 'package:cbl/cbl.dart';
import 'package:flutter/material.dart';
import '../../bloc/users_bloc.dart';
import '../../models/couchbase/couchbase_models.dart';
import 'database_provider.dart';
import 'image_repository.dart';

class DynamicRepository {
  final DatabaseProvider _databaseProvider;
  final ImageRepository _imageRepository;
  final UsersBloc _usersBloc;

  DynamicRepository(
      this._databaseProvider, this._imageRepository, this._usersBloc);

  Future<String> createDynamicSection(
      DynamicVisualSection dynamicSection) async {
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

        return model;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching dynamic section: $e');
      return null;
    }
  }

  Future<String> createOrUpdateDynamicSection(DynamicVisualSection section,
      {String? docId}) async {
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

  Future<bool> addDynamicImagesUrl(String sectionName, String sectionId,
      DynamicVisualSection currentDynamicSection, List<String> urls) async {
    try {
      for (var url in urls) {
        final image = DeckImage(
          localUrl: url,
          remoteUrl: '',
          isuploaded: false,
          parentid: currentDynamicSection.id,
          parenttype: 'dynamicSection',
          sectiontype: 'dynamicSectionImage',
          sectionname: sectionName,
          uploadedBy: _usersBloc.userDetails.username,
        );
        await _imageRepository.saveImage(image);
      }
      currentDynamicSection.images.addAll(urls);
      final doc = MutableDocument.withId(
        currentDynamicSection.id as String,
        currentDynamicSection.toDocument(),
      );
      await _databaseProvider.dynamicSectionCollection.saveDocument(doc);
      return true;
    } catch (e) {
      debugPrint('Error adding dynamic images url: $e');
      return false;
    }
  }

  Future<DynamicVisualSection?> getDynamicSectionByParentId(
      String parentId) async {
    try {
      final query = QueryBuilder.createAsync()
          .select(SelectResult.all())
          .from(
              DataSource.collection(_databaseProvider.dynamicSectionCollection)
                  .as('DynamicSection'))
          .where(Expression.property('parentid')
              .equalTo(Expression.string(parentId)));
      final result = await query.execute();
      final results = await result.allResults();
      if (results.isEmpty) {
        return await getNewDynamicSection(parentId);
      }
      final model =
          DynamicVisualSection.fromDocument(results.first.toPlainMap());
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
      final doc = MutableDocument.withId(
        id,
        dynamicSection.toDocument(),
      );
      await _databaseProvider.dynamicSectionCollection.saveDocument(doc);
      return true;
    } catch (e) {
      debugPrint('Error adding/updating dynamic section: $e');
      return false;
    }
  }

  Future<bool> removeDynamicImageUrl(
      DynamicVisualSection localDynamicSection, String url) async {
    try {
      localDynamicSection.images.remove(url);
      // caller should provide sectionId if needed; generate a new id here
      final id = CouchbaseDocument.generateId();
      final doc = MutableDocument.withId(
        id,
        localDynamicSection.toDocument(),
      );
      await _databaseProvider.dynamicSectionCollection.saveDocument(doc);
      return true;
    } catch (e) {
      debugPrint('Error removing dynamic image url: $e');
      return false;
    }
  }
}
