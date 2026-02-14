import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/couchbase/couchbase_models.dart';
import '../resources/couchbase/project_repository.dart';
import '../resources/couchbase/subproject_repository.dart';
import '../resources/couchbase/location_repository.dart';
import '../resources/repository.dart';

part 'projectdetails_event.dart';
part 'projectdetails_state.dart';

class ProjectDetailsBloc
    extends Bloc<ProjectDetailsEvent, ProjectDetailsState> {
  final ProjectRepository projectRepository;
  final SubprojectRepository subprojectRepository;
  final LocationRepository locationRepository;
  final Repository globalRepository;
  StreamSubscription<String>? _projectChangesSubscription;
  StreamSubscription<String>? _subprojectChangesSubscription;
  StreamSubscription<String>? _locationChangesSubscription;
  ProjectDetailsBloc({
    required this.projectRepository,
    required this.subprojectRepository,
    required this.locationRepository,
    required this.globalRepository,
  }) : super(ProjectDetailsInitial()) {
    on<LoadProjectDetails>((event, emit) async {
      emit(ProjectDetailsLoading());
      try {
        // load initial project snapshot
        final project = await projectRepository.fetchProjectById(
          event.projectId,
        );
        if (project != null) {
          emit(ProjectDetailsLoaded(project));

          // Subscribe to collection changes to auto-refresh when children change
          final projectStream =
              await projectRepository.watchProjectCollectionDocumentIds();
          _projectChangesSubscription?.cancel();
          _projectChangesSubscription = projectStream.listen((changedDocId) {
            if (changedDocId == event.projectId) {
              add(LoadProjectDetails(event.projectId));
            }
          });

          final subprojectStream =
              await subprojectRepository.watchSubprojectCollectionDocumentIds();
          _subprojectChangesSubscription?.cancel();
          _subprojectChangesSubscription = subprojectStream.listen((
            changedDocId,
          ) {
            // Check if this subproject is a child of the current project
            if (project.children.any(
              (child) => child.id == changedDocId && child.type == 'subproject',
            )) {
              add(LoadProjectDetails(event.projectId));
            }
          });

          final locationStream =
              await locationRepository.watchLocationCollectionDocumentIds();
          _locationChangesSubscription?.cancel();
          _locationChangesSubscription = locationStream.listen((changedDocId) {
            // Check if this location is a child of the current project
            if (project.children.any(
              (child) =>
                  child.id == changedDocId && child.type == 'projectlocation',
            )) {
              add(LoadProjectDetails(event.projectId));
            }
          });
        } else {
          //emit(const ProjectDetailsError('Failed to load project details'));
        }
      } catch (e) {
        emit(const ProjectDetailsError('Failed to load project details'));
      }
    });
    on<UpdateProjectDetails>((event, emit) async {
      emit(ProjectDetailsLoaded(event.project));
    });
    on<UpdateProjectAssignment>((event, emit) async {
      // indicate loading while assignment is being updated
      emit(ProjectDetailsLoading());
      try {
        final success = await projectRepository.updateAssignment(
          event.projectId,
          event.assignees,
        );
        if (success) {
          // reload project and emit saved notification
          final updated = await projectRepository.fetchProjectById(
            event.projectId,
          );
          emit(ProjectDetailsSaved());
          if (updated != null) emit(ProjectDetailsLoaded(updated));
        } else {
          emit(const ProjectDetailsError('Failed to update assignment'));
        }
      } catch (e) {
        emit(ProjectDetailsError(e.toString()));
      }
    });
    //   on<UpdateProjectDetails>((event, emit) async {
    //     emit(ProjectDetailsLoading());
    //     try {
    //       final success = await projectRepository.addupdateProject(event.project,
    //        event.projectName as String,
    //   event.projectAddress as String,
    //   event.description as String,
    //   event.userName,
    //   double longitude,
    //   double latitude,
    //   String? formId,
    //   bool isNewProject,);
    //       if (success) {
    //         emit(ProjectDetailsSaved());
    //       } else {
    //         emit(const ProjectDetailsError('Failed to save project'));
    //       }
    //     } catch (e) {
    //       emit(const ProjectDetailsError('Failed to save project'));
    //     }
    //   });
    // }
  }

  @override
  Future<void> close() async {
    await _projectChangesSubscription?.cancel();
    await _subprojectChangesSubscription?.cancel();
    await _locationChangesSubscription?.cancel();
    return super.close();
  }
}
