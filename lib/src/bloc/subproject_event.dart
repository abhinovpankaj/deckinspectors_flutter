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
  const SaveSubProjectEvent(this.subProject, this.name, this.description,
      this.isNewBuilding, this.fullUserName);
  @override
  List<Object?> get props =>
      [subProject, name, description, isNewBuilding, fullUserName];
}

class DeleteSubProjectEvent extends SubProjectEvent {
  final SubProject subProject;
  const DeleteSubProjectEvent(this.subProject);
  @override
  List<Object?> get props => [subProject];
}
