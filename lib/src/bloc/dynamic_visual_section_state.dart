import 'package:equatable/equatable.dart';
import '../models/couchbase/couchbase_models.dart';

abstract class DynamicVisualSectionState extends Equatable {
  const DynamicVisualSectionState();
  @override
  List<Object?> get props => [];
}

class DynamicVisualSectionInitial extends DynamicVisualSectionState {}

class DynamicVisualSectionLoading extends DynamicVisualSectionState {}

class DynamicVisualSectionSaving extends DynamicVisualSectionState {}

class DynamicVisualSectionLoaded extends DynamicVisualSectionState {
  final DynamicVisualSection section;
  const DynamicVisualSectionLoaded(this.section);
  @override
  List<Object?> get props => [section];
}

class DynamicVisualSectionSaveSuccess extends DynamicVisualSectionState {
  final DynamicVisualSection section;
  const DynamicVisualSectionSaveSuccess(this.section);
  @override
  List<Object?> get props => [section];
}

class DynamicVisualSectionSaveFailure extends DynamicVisualSectionState {
  final String error;
  const DynamicVisualSectionSaveFailure(this.error);
  @override
  List<Object?> get props => [error];
}

class DynamicVisualSectionDeleteSuccess extends DynamicVisualSectionState {}

class DynamicVisualSectionDeleteFailure extends DynamicVisualSectionState {
  final String error;
  const DynamicVisualSectionDeleteFailure(this.error);
  @override
  List<Object?> get props => [error];
}

class DynamicVisualSectionError extends DynamicVisualSectionState {
  final String message;
  const DynamicVisualSectionError(this.message);
  @override
  List<Object?> get props => [message];
}

// kept for backward compatibility — alias to DynamicVisualSectionDeleteSuccess
class DynamicVisualSectionDeleted extends DynamicVisualSectionState {}
