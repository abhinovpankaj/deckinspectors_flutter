import 'package:equatable/equatable.dart';
import '../models/couchbase/couchbase_models.dart';

abstract class DynamicVisualSectionEvent extends Equatable {
  const DynamicVisualSectionEvent();
  @override
  List<Object?> get props => [];
}

class LoadDynamicVisualSection extends DynamicVisualSectionEvent {
  final String sectionId;
  const LoadDynamicVisualSection(this.sectionId);
  @override
  List<Object?> get props => [sectionId];
}

class SaveDynamicVisualSection extends DynamicVisualSectionEvent {
  final DynamicVisualSection section;
  final String name;
  final String concerns;
  final List<Question> questions;
  final bool invasiveReviewRequired;
  final bool unitUnavailable;
  final bool isNewSection;
  final String userFullName;

  const SaveDynamicVisualSection({
    required this.section,
    required this.name,
    required this.concerns,
    required this.questions,
    required this.invasiveReviewRequired,
    required this.unitUnavailable,
    required this.isNewSection,
    required this.userFullName,
  });

  @override
  List<Object?> get props => [
    section,
    name,
    concerns,
    questions,
    invasiveReviewRequired,
    unitUnavailable,
    isNewSection,
    userFullName,
  ];
}

class DeleteDynamicVisualSection extends DynamicVisualSectionEvent {
  final DynamicVisualSection section;
  const DeleteDynamicVisualSection(this.section);
  @override
  List<Object?> get props => [section];
}

class AddDynamicVisualSectionImages extends DynamicVisualSectionEvent {
  final DynamicVisualSection section;
  final List<String> imagePaths;
  const AddDynamicVisualSectionImages(this.section, this.imagePaths);
  @override
  List<Object?> get props => [section, imagePaths];
}

class RemoveDynamicVisualSectionImage extends DynamicVisualSectionEvent {
  final DynamicVisualSection section;
  final String imagePath;
  const RemoveDynamicVisualSectionImage(this.section, this.imagePath);
  @override
  List<Object?> get props => [section, imagePath];
}
