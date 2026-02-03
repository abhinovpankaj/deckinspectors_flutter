import 'package:equatable/equatable.dart';
import '../models/couchbase/couchbase_models.dart';

abstract class DynamicSectionState extends Equatable {
  const DynamicSectionState();

  @override
  List<Object?> get props => [];
}

class DynamicSectionInitial extends DynamicSectionState {
  const DynamicSectionInitial();
}

class DynamicSectionLoading extends DynamicSectionState {
  const DynamicSectionLoading();
}

class DynamicSectionLoaded extends DynamicSectionState {
  final DynamicVisualSection section;

  const DynamicSectionLoaded(this.section);

  @override
  List<Object?> get props => [section];
}

class DynamicSectionError extends DynamicSectionState {
  final String message;

  const DynamicSectionError(this.message);

  @override
  List<Object?> get props => [message];
}

class DynamicSectionSaving extends DynamicSectionState {
  const DynamicSectionSaving();
}

class DynamicSectionSaveSuccess extends DynamicSectionState {
  final DynamicVisualSection section;

  const DynamicSectionSaveSuccess(this.section);

  @override
  List<Object?> get props => [section];
}

class DynamicSectionSaveFailure extends DynamicSectionState {
  final String message;

  const DynamicSectionSaveFailure(this.message);

  @override
  List<Object?> get props => [message];
}

class DynamicSectionDeleting extends DynamicSectionState {
  const DynamicSectionDeleting();
}

class DynamicSectionDeleteSuccess extends DynamicSectionState {
  const DynamicSectionDeleteSuccess();
}

class DynamicSectionDeleteFailure extends DynamicSectionState {
  final String message;

  const DynamicSectionDeleteFailure(this.message);

  @override
  List<Object?> get props => [message];
}
