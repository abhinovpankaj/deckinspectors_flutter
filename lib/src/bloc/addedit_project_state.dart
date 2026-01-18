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
  final Project project;
  const AddEditProjectLoaded({required this.project});
  @override
  List<Object?> get props => [project];
}

class AddEditProjectSaving extends AddEditProjectState {}

class AddEditProjectDeleting extends AddEditProjectState {}

class AddEditProjectSuccess extends AddEditProjectState {}

class AddEditProjectFailure extends AddEditProjectState {
  final String error;
  const AddEditProjectFailure({required this.error});
  @override
  List<Object?> get props => [error];
}
