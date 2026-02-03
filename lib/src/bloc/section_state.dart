import 'package:equatable/equatable.dart';
import '../models/couchbase/couchbase_models.dart';

abstract class SectionState extends Equatable {
  const SectionState();

  @override
  List<Object?> get props => [];
}

class SectionInitial extends SectionState {}

class SectionLoading extends SectionState {}

class SectionLoaded extends SectionState {
  final VisualSection section;
  const SectionLoaded(this.section);

  @override
  List<Object?> get props => [section];
}

class SectionError extends SectionState {
  final String message;
  const SectionError(this.message);

  @override
  List<Object?> get props => [message];
}

class SectionSaving extends SectionState {}

class SectionSaveSuccess extends SectionState {
  final VisualSection section;
  const SectionSaveSuccess(this.section);

  @override
  List<Object?> get props => [section];
}

class SectionSaveFailure extends SectionState {
  final String error;
  const SectionSaveFailure(this.error);

  @override
  List<Object?> get props => [error];
}

class SectionDeleteSuccess extends SectionState {}

class SectionDeleteFailure extends SectionState {
  final String error;
  const SectionDeleteFailure(this.error);

  @override
  List<Object?> get props => [error];
}
