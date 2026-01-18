import 'package:equatable/equatable.dart';

import '../models/couchbase/couchbase_models.dart';

abstract class SubProjectState extends Equatable {
  const SubProjectState();
  @override
  List<Object?> get props => [];
}

class SubProjectInitial extends SubProjectState {}

class SubProjectLoading extends SubProjectState {}

class SubProjectLoaded extends SubProjectState {
  final SubProject subProject;
  const SubProjectLoaded(this.subProject);
  @override
  List<Object?> get props => [subProject];
}

class SubProjectSaving extends SubProjectState {}

class SubProjectSuccess extends SubProjectState {}

class SubProjectFailure extends SubProjectState {
  final String error;
  const SubProjectFailure(this.error);
  @override
  List<Object?> get props => [error];
}
