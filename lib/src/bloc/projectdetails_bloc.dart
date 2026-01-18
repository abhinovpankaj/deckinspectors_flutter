import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/couchbase/couchbase_models.dart';
import '../resources/couchbase/project_repository.dart';
import '../resources/repository.dart';

part 'projectdetails_event.dart';
part 'projectdetails_state.dart';

class ProjectDetailsBloc
    extends Bloc<ProjectDetailsEvent, ProjectDetailsState> {
  final ProjectRepository projectRepository;
  final Repository globalRepository;
  ProjectDetailsBloc({
    required this.projectRepository,
    required this.globalRepository,
  }) : super(ProjectDetailsInitial()) {
    on<LoadProjectDetails>((event, emit) async {
      emit(ProjectDetailsLoading());
      try {
        final project = await projectRepository.fetchProjectById(
          event.projectId,
        );
        emit(ProjectDetailsLoaded(project as Project));
      } catch (e) {
        emit(const ProjectDetailsError('Failed to load project details'));
      }
    });
    on<UpdateProjectDetails>((event, emit) async {
      emit(ProjectDetailsLoading());
      try {
        final success = await projectRepository.addupdateProject(event.project);
        if (success) {
          emit(ProjectDetailsSaved());
        } else {
          emit(const ProjectDetailsError('Failed to save project'));
        }
      } catch (e) {
        emit(const ProjectDetailsError('Failed to save project'));
      }
    });
  }
}
