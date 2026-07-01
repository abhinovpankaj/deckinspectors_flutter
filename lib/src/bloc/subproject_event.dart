import 'package:equatable/equatable.dart';

import '../models/couchbase/couchbase_models.dart';

abstract class SubProjectEvent extends Equatable {
  const SubProjectEvent();
  @override
  List<Object?> get props => [];
}

class LoadSubProjectEvent extends SubProjectEvent {
  final String subProjectId;
  const LoadSubProjectEvent(this.subProjectId);
  @override
  List<Object?> get props => [subProjectId];
}

class SaveSubProjectEvent extends SubProjectEvent {
  final SubProject subProject;
  final String name;
  final String description;
  final bool isNewBuilding;
  final String fullUserName;
  final String imageURL;
  final bool imageChanged;
  final String? originalImagePath;
  const SaveSubProjectEvent(
    this.subProject,
    this.name,
    this.description,
    this.isNewBuilding,
    this.fullUserName,
    this.imageURL,
    this.imageChanged,
    this.originalImagePath,
  );
  @override
  List<Object?> get props => [
    subProject,
    name,
    description,
    isNewBuilding,
    fullUserName,
    imageURL,
    imageChanged,
    originalImagePath,
  ];
}

class DeleteSubProjectEvent extends SubProjectEvent {
  final SubProject subProject;
  const DeleteSubProjectEvent(this.subProject);
  @override
  List<Object?> get props => [subProject];
}
