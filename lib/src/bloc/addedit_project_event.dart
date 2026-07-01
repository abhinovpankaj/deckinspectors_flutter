import 'package:equatable/equatable.dart';
import '../models/couchbase/couchbase_models.dart';

abstract class AddEditProjectEvent extends Equatable {
  const AddEditProjectEvent();
  @override
  List<Object?> get props => [];
}

class LoadProject extends AddEditProjectEvent {
  final String? projectId;
  const LoadProject({this.projectId});
  @override
  List<Object?> get props => [projectId];
}

class DeleteProject extends AddEditProjectEvent {
  final String? projectId;
  const DeleteProject({this.projectId});
  @override
  List<Object?> get props => [projectId];
}

class UpdateProjectField extends AddEditProjectEvent {
  final String field;
  final dynamic value;
  const UpdateProjectField({required this.field, required this.value});
  @override
  List<Object?> get props => [field, value];
}

class SaveProject extends AddEditProjectEvent {
  final Project project;
  final String name;
  final String address;
  final String description;
  final String userName;
  final double longitude;
  final double latitude;
  final String? formId;
  final bool isNewProject;
  final String imageURL;
  final bool imageChanged;
  final String? originalImagePath;
  const SaveProject({
    required this.project,
    required this.name,
    required this.address,
    required this.description,
    required this.userName,
    required this.longitude,
    required this.latitude,
    required this.formId,
    required this.isNewProject,
    required this.imageURL,
    required this.imageChanged,
    this.originalImagePath,
  });
  @override
  List<Object?> get props => [
        project,
        name,
        address,
        description,
        userName,
        longitude,
        latitude,
        formId,
        isNewProject,
        imageURL,
        imageChanged,
        originalImagePath,
      ];
}

class ResetAddEditProject extends AddEditProjectEvent {}
