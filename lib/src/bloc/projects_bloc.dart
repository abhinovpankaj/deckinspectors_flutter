import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/project_model.dart';
import '../resources/couchbase/project_repository.dart';
import 'projects_event.dart';
import 'projects_state.dart';

class ProjectsBloc extends Bloc<ProjectsEvent, ProjectsState> {
  final ProjectRepository projectRepository;

  ProjectsBloc({required this.projectRepository}) : super(ProjectsInitial()) {
    on<LoadProjectsEvent>(_onLoadProjects);
  }

  Future<void> _onLoadProjects(
      LoadProjectsEvent event, Emitter<ProjectsState> emit) async {
    emit(ProjectsLoading());
    try {
      // Fetch all projects from the repository (implement this method as needed)
      final projects = await projectRepository.fetchAllProjects();
      emit(ProjectsLoaded(projects));
    } catch (e) {
      emit(ProjectsError(e.toString()));
    }
  }
}

final projectsBloc = ProjectsBloc();
