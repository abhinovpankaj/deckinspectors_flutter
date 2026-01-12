import 'package:equatable/equatable.dart';
import '../models/project_model.dart';

abstract class ProjectsEvent extends Equatable {
  const ProjectsEvent();
  @override
  List<Object?> get props => [];
}

class LoadProjectsEvent extends ProjectsEvent {}
