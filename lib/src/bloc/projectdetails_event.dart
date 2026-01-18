part of 'projectdetails_bloc.dart';

abstract class ProjectDetailsEvent extends Equatable {
  const ProjectDetailsEvent();
  @override
  List<Object?> get props => [];
}

class LoadProjectDetails extends ProjectDetailsEvent {
  final String projectId;
  const LoadProjectDetails(this.projectId);
  @override
  List<Object?> get props => [projectId];
}

class UpdateProjectDetails extends ProjectDetailsEvent {
  final Project project;
  const UpdateProjectDetails(this.project);
  @override
  List<Object?> get props => [project];
}
