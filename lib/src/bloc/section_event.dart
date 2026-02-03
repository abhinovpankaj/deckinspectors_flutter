import 'package:equatable/equatable.dart';
import '../models/couchbase/couchbase_models.dart';
import '../models/enums.dart';
import '../models/exteriorelements.dart';

abstract class SectionEvent extends Equatable {
  const SectionEvent();

  @override
  List<Object?> get props => [];
}

class LoadSectionEvent extends SectionEvent {
  final String sectionId;
  const LoadSectionEvent(this.sectionId);

  @override
  List<Object?> get props => [sectionId];
}

class SaveSectionEvent extends SectionEvent {
  final VisualSection section;
  final String name;
  final String concerns;
  final List<ElementModel> exteriorElements;
  final List<ElementModel> waterproofingElements;
  final VisualReview? review;
  final ConditionalAssessment? assessment;
  final ExpectancyYears? eee;
  final ExpectancyYears? lbc;
  final ExpectancyYears? awe;
  final bool invasiveReviewRequired;
  final bool hasSignsOfLeak;
  final bool isNewSection;
  final String userFullName;
  final bool unitUnavailable;

  const SaveSectionEvent({
    required this.section,
    required this.name,
    required this.concerns,
    required this.exteriorElements,
    required this.waterproofingElements,
    required this.review,
    required this.assessment,
    required this.eee,
    required this.lbc,
    required this.awe,
    required this.invasiveReviewRequired,
    required this.hasSignsOfLeak,
    required this.isNewSection,
    required this.userFullName,
    required this.unitUnavailable,
  });

  @override
  List<Object?> get props => [
    section,
    name,
    concerns,
    exteriorElements,
    waterproofingElements,
    review,
    assessment,
    eee,
    lbc,
    awe,
    invasiveReviewRequired,
    hasSignsOfLeak,
    isNewSection,
    userFullName,
    unitUnavailable,
  ];
}

class DeleteSectionEvent extends SectionEvent {
  final VisualSection section;
  const DeleteSectionEvent(this.section);

  @override
  List<Object?> get props => [section];
}
