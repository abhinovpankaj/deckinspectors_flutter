import 'package:equatable/equatable.dart';
import '../models/couchbase/couchbase_models.dart';

abstract class InvasiveSectionState extends Equatable {
  const InvasiveSectionState();

  @override
  List<Object?> get props => [];
}

class InvasiveSectionInitial extends InvasiveSectionState {
  const InvasiveSectionInitial();
}

class InvasiveSectionLoading extends InvasiveSectionState {
  const InvasiveSectionLoading();
}

class InvasiveSectionLoaded extends InvasiveSectionState {
  final InvasiveSection section;

  const InvasiveSectionLoaded(this.section);

  @override
  List<Object?> get props => [section];
}

class InvasiveSectionError extends InvasiveSectionState {
  final String message;

  const InvasiveSectionError(this.message);

  @override
  List<Object?> get props => [message];
}

class InvasiveSectionSaving extends InvasiveSectionState {
  const InvasiveSectionSaving();
}

class InvasiveSectionSaveSuccess extends InvasiveSectionState {
  final InvasiveSection section;

  const InvasiveSectionSaveSuccess(this.section);

  @override
  List<Object?> get props => [section];
}

class InvasiveSectionSaveFailure extends InvasiveSectionState {
  final String message;

  const InvasiveSectionSaveFailure(this.message);

  @override
  List<Object?> get props => [message];
}

class InvasiveSectionDeleting extends InvasiveSectionState {
  const InvasiveSectionDeleting();
}

class InvasiveSectionDeleteSuccess extends InvasiveSectionState {
  const InvasiveSectionDeleteSuccess();
}

class InvasiveSectionDeleteFailure extends InvasiveSectionState {
  final String message;

  const InvasiveSectionDeleteFailure(this.message);

  @override
  List<Object?> get props => [message];
}
