import 'package:equatable/equatable.dart';
import '../models/project_model.dart';

abstract class ProjectsEvent extends Equatable {
  const ProjectsEvent();
  @override
  List<Object?> get props => [];
}

class LoadProjectsEvent extends ProjectsEvent {}

class AddProjectEvent extends ProjectsEvent {
  final Project project;
  const AddProjectEvent(this.project);
  @override
  List<Object?> get props => [project];
}

class UpdateProjectEvent extends ProjectsEvent {
  final Project project;
  const UpdateProjectEvent(this.project);
  @override
  List<Object?> get props => [project];
}

class DeleteProjectEvent extends ProjectsEvent {
  final String projectId;
  const DeleteProjectEvent(this.projectId);
  @override
  List<Object?> get props => [projectId];
}
