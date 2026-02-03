import 'package:equatable/equatable.dart';
import '../models/couchbase/couchbase_models.dart';

abstract class DynamicSectionEvent extends Equatable {
  const DynamicSectionEvent();

  @override
  List<Object?> get props => [];
}

class LoadDynamicSectionEvent extends DynamicSectionEvent {
  final String sectionId;

  const LoadDynamicSectionEvent(this.sectionId);

  @override
  List<Object?> get props => [sectionId];
}

class SaveDynamicSectionEvent extends DynamicSectionEvent {
  final DynamicVisualSection section;
  final String name;
  final String concerns;
  final List<Question> questions;
  final bool invasiveReviewRequired;
  final bool isNewSection;
  final String userFullName;
  final bool unitUnavailable;

  const SaveDynamicSectionEvent({
    required this.section,
    required this.name,
    required this.concerns,
    required this.questions,
    required this.invasiveReviewRequired,
    required this.isNewSection,
    required this.userFullName,
    required this.unitUnavailable,
  });

  @override
  List<Object?> get props => [
    section,
    name,
    concerns,
    questions,
    invasiveReviewRequired,
    isNewSection,
    userFullName,
    unitUnavailable,
  ];
}

class DeleteDynamicSectionEvent extends DynamicSectionEvent {
  final DynamicVisualSection section;

  const DeleteDynamicSectionEvent(this.section);

  @override
  List<Object?> get props => [section];
}
