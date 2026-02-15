import 'package:cbl/cbl.dart';
import 'package:flutter/material.dart';
import '../../bloc/settings_bloc.dart';
import '../../bloc/users_bloc.dart';
import '../../models/couchbase/couchbase_models.dart';
import '../../models/enums.dart';
import '../../models/exteriorelements.dart';
import 'database_provider.dart';
import 'image_repository.dart';
import 'location_repository.dart';
import 'subproject_repository.dart';

class VisualSectionRepository {
  final DatabaseProvider _databaseProvider;
  final SubprojectRepository _subprojectRepository;
  final ImageRepository _imageRepository;
  final LocationRepository _locationRepository;
  final UsersBloc _usersBloc;
  final AppSettings _appSettings;

  VisualSectionRepository(
    this._databaseProvider,
    this._locationRepository,
    this._subprojectRepository,
    this._imageRepository,
    this._usersBloc,
    this._appSettings,
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
        return VisualSection.fromDocument(doc.toPlainMap());
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

  bool addImagesUrl(
    VisualSection localVisualSection,
    List<String> localPaths,
    List<String> onlinePaths,
  ) {
    try {
      for (int i = 0; i < localPaths.length; i++) {
        final image = DeckImage(
          localUrl: localPaths[i],
          remoteUrl: onlinePaths[i],
          isuploaded: true,
          parentid: localVisualSection.id,
          parenttype: 'visualSection',
          sectiontype: 'visualSectionImage',
          sectionname: localVisualSection.name,
          uploadedBy: _usersBloc.userDetails.username,
        );
        _imageRepository.saveImage(image);
      }
      return true;
    } catch (e) {
      debugPrint('Error adding images url: $e');
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
      _locationRepository.updateLocationSection(
        visualSection.parenttype,
        visualSection.id as String,
        visualSection.parentid,
        visualSection.name,
        visualSection.visualreview,
        visualSection.visualsignsofleak,
        visualSection.furtherinvasivereviewrequired,
        visualSection.conditionalassessment,
        visualSection.images.length,
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
}
