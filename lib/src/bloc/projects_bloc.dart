import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/users_bloc.dart';
import '../resources/couchbase/project_repository.dart';
import 'projects_event.dart';
import 'projects_state.dart';

class ProjectsBloc extends Bloc<ProjectsEvent, ProjectsState> {
  final ProjectRepository projectRepository;

  ProjectsBloc({required this.projectRepository}) : super(ProjectsInitial()) {
    on<LoadProjectsEvent>(_onLoadProjects);
    on<AddProjectEvent>(_onAddProject);
    //on<UpdateProjectEvent>(_onUpdateProject);
    on<DeleteProjectEvent>(_onDeleteProject);
  }

  Future<void> _onLoadProjects(
    LoadProjectsEvent event,
    Emitter<ProjectsState> emit,
  ) async {
    emit(ProjectsLoading());
    try {
      // Fetch all projects from the repository (implement this method as needed)
      final projects = await projectRepository.fetchAllProjects();
      emit(ProjectsLoaded(projects));
    } catch (e) {
      emit(ProjectsError(e.toString()));
    }
  }

  Future<void> _onAddProject(
    AddProjectEvent event,
    Emitter<ProjectsState> emit,
  ) async {
    emit(ProjectsLoading());
    try {
      // Ensure created metadata is set for new projects
      try {
        final user = usersBloc.userDetails;
        final fullName =
            "${user.firstname ?? ''} ${user.lastname ?? ''}".trim();
        event.project.createdby ??= fullName;
        event.project.companyIdentifier ??= user.companyidentifer;
        if (event.project.createdat == null || event.project.createdat == '') {
          event.project.createdat = DateTime.now().toIso8601String();
        }
        // Ensure assignedto contains username
        final username = user.username;
        if (username != null &&
            username.isNotEmpty &&
            !event.project.assignedto.contains(username)) {
          event.project.assignedto.add(username);
        }
      } catch (_) {}

      await projectRepository.createOrUpdateProject(event.project);
      final projects = await projectRepository.fetchAllProjects();
      emit(ProjectsLoaded(projects));
    } catch (e) {
      emit(ProjectsError(e.toString()));
    }
  }

  // Future<void> _onUpdateProject(
  //     UpdateProjectEvent event, Emitter<ProjectsState> emit) async {
  //   emit(ProjectsLoading());
  //   try {
  //     // update edited metadata
  //     try {
  //       final user = usersBloc.userDetails;
  //       final fullName = "${user.firstname ?? ''} ${user.lastname ?? ''}".trim();
  //       event.project.lasteditedby = fullName;
  //       event.project.editedat = DateTime.now().toIso8601String();
  //     } catch (_) {}

  //     await projectRepository.createOrUpdateProject(event.project);
  //     final projects = await projectRepository.fetchAllProjects();
  //     emit(ProjectsLoaded(projects));
  //   } catch (e) {
  //     emit(ProjectsError(e.toString()));
  //   }
  // }

  Future<void> _onDeleteProject(
    DeleteProjectEvent event,
    Emitter<ProjectsState> emit,
  ) async {
    emit(ProjectsLoading());
    try {
      await projectRepository.deleteProject(event.projectId);
      final projects = await projectRepository.fetchAllProjects();
      emit(ProjectsLoaded(projects));
    } catch (e) {
      emit(ProjectsError(e.toString()));
    }
  }
}
