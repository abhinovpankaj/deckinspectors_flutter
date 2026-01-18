import 'package:equatable/equatable.dart';
import '../models/couchbase/couchbase_models.dart';

abstract class DynamicVisualSectionState extends Equatable {
  const DynamicVisualSectionState();
  @override
  List<Object?> get props => [];
}

class DynamicVisualSectionInitial extends DynamicVisualSectionState {}

class DynamicVisualSectionLoading extends DynamicVisualSectionState {}

class DynamicVisualSectionLoaded extends DynamicVisualSectionState {
  final DynamicVisualSection section;
  const DynamicVisualSectionLoaded(this.section);
  @override
  List<Object?> get props => [section];
}

class DynamicVisualSectionSaved extends DynamicVisualSectionState {}

class DynamicVisualSectionDeleted extends DynamicVisualSectionState {}

class DynamicVisualSectionError extends DynamicVisualSectionState {
  final String message;
  const DynamicVisualSectionError(this.message);
  @override
  List<Object?> get props => [message];
}
