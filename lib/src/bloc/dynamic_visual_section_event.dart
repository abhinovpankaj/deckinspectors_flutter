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
  final String userFullName;
  final bool isNewSection;
  final List<Question> questions;
  final bool unitUnavailable;
  const SaveDynamicVisualSection(this.section, this.userFullName,
      this.isNewSection, this.questions, this.unitUnavailable);
  @override
  List<Object?> get props =>
      [section, userFullName, isNewSection, questions, unitUnavailable];
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
