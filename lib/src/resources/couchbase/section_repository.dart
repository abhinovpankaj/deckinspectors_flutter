import 'package:cbl/cbl.dart';
import 'package:flutter/material.dart';
import '../../bloc/users_bloc.dart';
import '../../models/couchbase/couchbase_models.dart';
import '../../models/enums.dart';
import '../../models/exteriorelements.dart';
import 'database_provider.dart';
import 'image_repository.dart';
import 'location_repository.dart';
import 'subproject_repository.dart';

class SectionRepository {
  final DatabaseProvider _databaseProvider;
  final SubprojectRepository _subprojectRepository;
  final ImageRepository _imageRepository;
  final LocationRepository _locationRepository;
  final UsersBloc _usersBloc;
  //final AppSettings _appSettings;

  SectionRepository(
    this._databaseProvider,
    this._locationRepository,
    this._subprojectRepository,
    this._imageRepository,
    this._usersBloc,
  );
  final String locationDocumentType = 'location';
  final String attributeDocumentType = 'documentType';

  Future<void> createVisualSection(VisualSection visualSection) async {
    try {
      final doc = MutableDocument.withId(
        visualSection.id as String,
        visualSection.toDocument(),
      );
      await _databaseProvider.visualSectionCollection.saveDocument(doc);
    } catch (e) {
      debugPrint('Error creating visual section: $e');
    }
  }

  Future<VisualSection?> getVisualSection(String id) async {
    try {
      final doc = await _databaseProvider.visualSectionCollection.document(id);
      if (doc != null) {
        final model = VisualSection.fromDocument(doc.toPlainMap());
        model.id = doc.id;
        return model;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching visual section: $e');
      return null;
    }
  }

  /// Create or update visual section
  Future<void> createOrUpdateVisualSection(VisualSection section) async {
    try {
      final doc = MutableDocument.withId(
        section.id as String,
        section.toDocument(),
      );
      await _databaseProvider.visualSectionCollection.saveDocument(doc);
    } catch (e) {
      debugPrint('Error saving visual section: $e');
    }
  }

  Future<String> deleteVisualSection(VisualSection visualSection) async {
    try {
      // remove from parent project children
      await _subprojectRepository.deleteProjectChildren(
        visualSection.id as String,
        visualSection.parentid,
      );
      final doc = await _databaseProvider.visualSectionCollection.document(
        visualSection.id as String,
      );
      if (doc != null) {
        await _databaseProvider.visualSectionCollection.deleteDocument(doc);
      }
      return 'success';
    } catch (e) {
      debugPrint('Error deleting visual section: $e');
      return 'failed';
    }
  }

  Future<bool> addImagesUrl(
    VisualSection localVisualSection,
    List<String> localPaths,
    List<String> onlinePaths,
  ) async {
    try {
      for (int i = 0; i < localPaths.length; i++) {
        final persistedPath = onlinePaths[i];
        final image = DeckImage(
          localUrl: localPaths[i],
          remoteUrl: persistedPath,
          isuploaded: persistedPath.startsWith('http'),
          parentid: localVisualSection.id,
          parenttype: 'visualSection',
          sectiontype: 'visualSectionImage',
          sectionname: localVisualSection.name,
          uploadedBy: _usersBloc.userDetails.username,
        );
        _imageRepository.saveImage(image);

        if (localVisualSection.images.contains(localPaths[i])) {
          final index = localVisualSection.images.indexOf(localPaths[i]);
          localVisualSection.images[index] = onlinePaths[i];
        } else {
          localVisualSection.images.add(onlinePaths[i]);
        }
      }

      final doc = MutableDocument.withId(
        localVisualSection.id as String,
        localVisualSection.toDocument(),
      );
      _databaseProvider.visualSectionCollection.saveDocument(doc);

      // Update coverUrl on the parent section with the first remote image
      final newCoverUrl =
          localVisualSection.images.isNotEmpty
              ? localVisualSection.images.last
              : '';
      await _locationRepository.updateImageCount(
        localVisualSection.parenttype,
        localVisualSection.id as String,
        localVisualSection.parentid,
        localVisualSection.images.length,
        newCoverUrl,
      );

      return true;
    } catch (e) {
      debugPrint('Error adding images url: $e');
      return false;
    }
  }

  Future<bool> removeImageUrl(VisualSection section, String url) async {
    try {
      section.images.remove(url);
      final newCoverUrl = section.images.isNotEmpty ? section.images.last : '';
      _locationRepository.updateLocationSection(
        section.parenttype,
        section.id as String,
        section.parentid,
        section.name,
        section.visualreview,
        section.visualsignsofleak,
        section.furtherinvasivereviewrequired,
        section.conditionalassessment,
        section.images.length,
        coverUrl: newCoverUrl,
      );

      final doc = MutableDocument.withId(
        section.id as String,
        section.toDocument(),
      );
      await _databaseProvider.visualSectionCollection.saveDocument(doc);
      return true;
    } catch (e) {
      debugPrint('Error removing image url: $e');
      return false;
    }
  }

  Future<bool> addupdateVisualSection(
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
  ) async {
    try {
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

      // update parent with the section detail
      final coverUrl =
          visualSection.images.isNotEmpty ? visualSection.images.first : null;
      await _locationRepository.updateLocationSection(
        visualSection.parenttype,
        visualSection.id as String,
        visualSection.parentid,
        visualSection.name,
        visualSection.visualreview,
        visualSection.visualsignsofleak,
        visualSection.furtherinvasivereviewrequired,
        visualSection.conditionalassessment,
        visualSection.images.length,
        coverUrl: coverUrl,
      );

      final doc = MutableDocument.withId(
        visualSection.id as String,
        visualSection.toDocument(),
      );
      await _databaseProvider.visualSectionCollection.saveDocument(doc);

      return true;
    } catch (e) {
      debugPrint('Error adding/updating visual section: $e');
      return false;
    }
  }

  Future<InvasiveSection> getNewInvasiveSection(String sectionId) async {
    final section = InvasiveSection(
      parentid: sectionId,
      invasiveDescription: "",
      postinvasiverepairsrequired: false,
      invasiveimages: const [],
    );
    section.id = CouchbaseDocument.generateId();
    return section;
  }

  Future<ConclusiveSection> getNewConclusiveSection(String sectionId) async {
    final section = ConclusiveSection(
      parentid: sectionId,
      conclusiveconsiderations: "",
      eeeconclusive: "",
      lbcconclusive: "",
      aweconclusive: "",
      propowneragreed: false,
      invasiverepairsinspectedandcompleted: false,
      conclusiveimages: const [],
    );
    section.id = CouchbaseDocument.generateId();
    return section;
  }

  Future<bool> addInvasiveImagesUrl(
    String visualSectionName,
    InvasiveSection currentInvasiveSection,
    List<String> urls,
  ) async {
    try {
      for (var url in urls) {
        final persistedPath = url;
        final image = DeckImage(
          localUrl: null,
          remoteUrl: persistedPath,
          isuploaded: persistedPath.startsWith('http'),
          parentid: currentInvasiveSection.id,
          parenttype: 'invasiveSection',
          sectiontype: 'invasiveSectionImage',
          sectionname: visualSectionName,
          uploadedBy: _usersBloc.userDetails.username,
        );
        await _imageRepository.saveImage(image);
      }
      currentInvasiveSection.invasiveimages.addAll(urls);

      final doc = MutableDocument.withId(
        currentInvasiveSection.id as String,
        currentInvasiveSection.toDocument(),
      );
      await _databaseProvider.invasiveSectionCollection.saveDocument(doc);
      return true;
    } catch (e) {
      debugPrint('Error adding invasive images url: $e');
      return false;
    }
  }

  Future<bool> addConclusiveImagesUrl(
    String visualSectionName,
    ConclusiveSection currentConclusiveSection,
    List<String> urls,
  ) async {
    try {
      for (var url in urls) {
        final persistedPath = url;
        final image = DeckImage(
          localUrl: null,
          remoteUrl: persistedPath,
          isuploaded: persistedPath.startsWith('http'),
          parentid: currentConclusiveSection.id,
          parenttype: 'conclusiveSection',
          sectiontype: 'conclusiveSectionImage',
          sectionname: visualSectionName,
          uploadedBy: _usersBloc.userDetails.username,
        );
        await _imageRepository.saveImage(image);
      }
      currentConclusiveSection.conclusiveimages.addAll(urls);

      final doc = MutableDocument.withId(
        currentConclusiveSection.id as String,
        currentConclusiveSection.toDocument(),
      );
      await _databaseProvider.conclusiveSectionCollection.saveDocument(doc);
      return true;
    } catch (e) {
      debugPrint('Error adding conclusive images url: $e');
      return false;
    }
  }

  Future<InvasiveSection?> getInvasiveSection(String sectionId) async {
    try {
      final query = QueryBuilder.createAsync()
          .select(SelectResult.all())
          .from(
            DataSource.collection(
              _databaseProvider.invasiveSectionCollection,
            ).as('InvasiveSection'),
          )
          .where(
            Expression.property(
              'parentid',
            ).equalTo(Expression.string(sectionId)),
          );
      final result = await query.execute();
      final results = await result.allResults();
      if (results.isEmpty) {
        return await getNewInvasiveSection(sectionId);
      }
      final rowMap = results.first.toPlainMap();
      final data =
          (rowMap['InvasiveSection'] as Map<String, dynamic>?) ?? rowMap;
      final model = InvasiveSection.fromDocument(data);

      if (model.id == null || model.id!.isEmpty) {
        model.id = CouchbaseDocument.generateId();
      }
      return model;
    } catch (e) {
      debugPrint('Error fetching invasive section: $e');
      return null;
    }
  }

  Future<ConclusiveSection?> getConclusiveSection(String sectionId) async {
    try {
      final query = QueryBuilder.createAsync()
          .select(SelectResult.all())
          .from(
            DataSource.collection(
              _databaseProvider.conclusiveSectionCollection,
            ).as('ConclusiveSection'),
          )
          .where(
            Expression.property(
              'parentid',
            ).equalTo(Expression.string(sectionId)),
          );
      final result = await query.execute();
      final results = await result.allResults();
      if (results.isEmpty) {
        return await getNewConclusiveSection(sectionId);
      }
      final rowMap = results.first.toPlainMap();
      final data =
          (rowMap['ConclusiveSection'] as Map<String, dynamic>?) ?? rowMap;
      final model = ConclusiveSection.fromDocument(data);
      if (model.id == null || model.id!.isEmpty) {
        model.id = CouchbaseDocument.generateId();
      }
      return model;
    } catch (e) {
      debugPrint('Error fetching conclusive section: $e');
      return null;
    }
  }

  Future<bool> addupdateInvasiveSection(
    InvasiveSection currentInvasiveSection,
    String description,
    bool postInvasiveRepairsRequired,
  ) async {
    try {
      currentInvasiveSection.postinvasiverepairsrequired =
          postInvasiveRepairsRequired;
      currentInvasiveSection.invasiveDescription = description;

      final doc = MutableDocument.withId(
        currentInvasiveSection.id as String,
        currentInvasiveSection.toDocument(),
      );
      await _databaseProvider.invasiveSectionCollection.saveDocument(doc);
      return true;
    } catch (e) {
      debugPrint('Error adding/updating invasive section: $e');
      return false;
    }
  }

  Future<bool> addupdateConclusiveSection(
    ConclusiveSection currentConclusiveSection,
    bool propOwnerAgreed,
    bool invasiveRepairsCompleted,
    String eeeConclusive,
    String lbcConclusive,
    String aweConclusive,
    String description,
  ) async {
    try {
      currentConclusiveSection.propowneragreed = propOwnerAgreed;
      currentConclusiveSection.invasiverepairsinspectedandcompleted =
          invasiveRepairsCompleted;
      currentConclusiveSection.aweconclusive = aweConclusive;
      currentConclusiveSection.eeeconclusive = eeeConclusive;
      currentConclusiveSection.lbcconclusive = lbcConclusive;
      currentConclusiveSection.conclusiveconsiderations = description;

      final doc = MutableDocument.withId(
        currentConclusiveSection.id as String,
        currentConclusiveSection.toDocument(),
      );
      await _databaseProvider.conclusiveSectionCollection.saveDocument(doc);
      return true;
    } catch (e) {
      debugPrint('Error adding/updating conclusive section: $e');
      return false;
    }
  }

  Future<bool> removeConclusiveImageUrl(
    ConclusiveSection localConclusiveSection,
    String url,
  ) async {
    try {
      localConclusiveSection.conclusiveimages.remove(url);

      final doc = MutableDocument.withId(
        localConclusiveSection.id as String,
        localConclusiveSection.toDocument(),
      );
      await _databaseProvider.conclusiveSectionCollection.saveDocument(doc);
      return true;
    } catch (e) {
      debugPrint('Error removing conclusive image url: $e');
      return false;
    }
  }

  Future<bool> removeInvasiveImageUrl(
    InvasiveSection localInvasiveSection,
    String url,
  ) async {
    try {
      localInvasiveSection.invasiveimages.remove(url);

      final doc = MutableDocument.withId(
        localInvasiveSection.id as String,
        localInvasiveSection.toDocument(),
      );
      await _databaseProvider.invasiveSectionCollection.saveDocument(doc);
      return true;
    } catch (e) {
      debugPrint('Error removing invasive image url: $e');
      return false;
    }
  }
}
