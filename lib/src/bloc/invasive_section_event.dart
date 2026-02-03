import 'package:equatable/equatable.dart';
import '../models/couchbase/couchbase_models.dart';

abstract class InvasiveSectionEvent extends Equatable {
  const InvasiveSectionEvent();

  @override
  List<Object?> get props => [];
}

class LoadInvasiveSectionEvent extends InvasiveSectionEvent {
  final String sectionId;

  const LoadInvasiveSectionEvent(this.sectionId);

  @override
  List<Object?> get props => [sectionId];
}

class SaveInvasiveSectionEvent extends InvasiveSectionEvent {
  final InvasiveSection section;
  final String description;
  final bool postInvasiveRepairsRequired;
  final List<String> invasiveImages;
  final bool isNewSection;

  const SaveInvasiveSectionEvent({
    required this.section,
    required this.description,
    required this.postInvasiveRepairsRequired,
    required this.invasiveImages,
    required this.isNewSection,
  });

  @override
  List<Object?> get props => [
    section,
    description,
    postInvasiveRepairsRequired,
    invasiveImages,
    isNewSection,
  ];
}

class DeleteInvasiveSectionEvent extends InvasiveSectionEvent {
  final InvasiveSection section;

  const DeleteInvasiveSectionEvent(this.section);

  @override
  List<Object?> get props => [section];
}
