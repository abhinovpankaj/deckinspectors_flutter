part of 'projectdetails_bloc.dart';

abstract class ProjectDetailsState extends Equatable {
  const ProjectDetailsState();
  @override
  List<Object?> get props => [];
}

class ProjectDetailsInitial extends ProjectDetailsState {}

class ProjectDetailsLoading extends ProjectDetailsState {}

class ProjectDetailsLoaded extends ProjectDetailsState {
  final Project project;
  const ProjectDetailsLoaded(this.project);
  @override
  List<Object?> get props => [project];
}

class ProjectDetailsSaved extends ProjectDetailsState {}

class ProjectDetailsError extends ProjectDetailsState {
  final String message;
  const ProjectDetailsError(this.message);
  @override
  List<Object?> get props => [message];
}
