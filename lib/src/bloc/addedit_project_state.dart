import 'package:equatable/equatable.dart';
import '../models/couchbase/couchbase_models.dart';

abstract class AddEditProjectState extends Equatable {
  const AddEditProjectState();
  @override
  List<Object?> get props => [];
}

class AddEditProjectInitial extends AddEditProjectState {}

class AddEditProjectLoading extends AddEditProjectState {}

class AddEditProjectLoaded extends AddEditProjectState {
  /// Null when adding a new project (use widget's initial project in UI).
  final Project? project;
  final List<LocationForm> forms;
  const AddEditProjectLoaded({
    this.project,
    this.forms = const [],
  });
  @override
  List<Object?> get props => [project, forms];
}

class AddEditProjectSaving extends AddEditProjectState {}

class AddEditProjectDeleting extends AddEditProjectState {}

class AddEditProjectSuccess extends AddEditProjectState {}

class DeleteProjectSuccess extends AddEditProjectState {}

class AddEditProjectFailure extends AddEditProjectState {
  final String error;
  const AddEditProjectFailure({required this.error});
  @override
  List<Object?> get props => [error];
}
