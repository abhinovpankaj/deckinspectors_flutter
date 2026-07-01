import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../resources/couchbase/project_repository.dart';
import 'addedit_project_event.dart';
import 'addedit_project_state.dart';
// projects bloc wiring removed — presentation layer will trigger reloads

class AddEditProjectBloc
    extends Bloc<AddEditProjectEvent, AddEditProjectState> {
  final ProjectRepository projectRepository;

  AddEditProjectBloc({required this.projectRepository})
    : super(AddEditProjectInitial()) {
    on<LoadProject>(_onLoadProject);
    on<UpdateProjectField>(_onUpdateProjectField);
    on<SaveProject>(_onSaveProject);
    on<DeleteProject>(_onDeleteProject);
    on<ResetAddEditProject>(_onReset);
  }

  Future<void> _onLoadProject(
    LoadProject event,
    Emitter<AddEditProjectState> emit,
  ) async {
    emit(AddEditProjectLoading());
    try {
      final forms = await projectRepository.getAllForms();
      if (event.projectId != null && event.projectId!.isNotEmpty) {
        final project = await projectRepository.fetchProjectById(
          event.projectId!,
        );
        if (project != null) {
          emit(AddEditProjectLoaded(project: project, forms: forms));
          return;
        }
      }
      // New project or not found: still emit loaded state with forms so dropdown works
      emit(AddEditProjectLoaded(project: null, forms: forms));
    } catch (e) {
      emit(AddEditProjectFailure(error: e.toString()));
    }
  }

  Future<void> _onUpdateProjectField(
    UpdateProjectField event,
    Emitter<AddEditProjectState> emit,
  ) async {
    // This handler allows UI to update fields locally; keep current loaded project
    final current = state;
    if (current is AddEditProjectLoaded && current.project != null) {
      final project = current.project!;
      // Apply update based on field name
      switch (event.field) {
        case 'name':
          project.name = event.value as String?;
          break;
        case 'description':
          project.description = event.value as String?;
          break;
        case 'address':
          project.address = event.value as String?;
          break;
        case 'latitude':
          project.latitude = (event.value as num).toDouble();
          break;
        case 'longitude':
          project.longitude = (event.value as num).toDouble();
          break;
        case 'url':
          project.url = event.value as String?;
          break;
        default:
          break;
      }
      emit(AddEditProjectLoaded(project: project, forms: current.forms));
    }
  }

  Future<void> _onSaveProject(
    SaveProject event,
    Emitter<AddEditProjectState> emit,
  ) async {
    emit(AddEditProjectSaving());
    try {
      var saveResult = await projectRepository.addupdateProject(
        event.project,
        event.name,
        event.address,
        event.description,
        event.userName,
        event.longitude,
        event.latitude,
        event.formId,
        event.isNewProject,
      );

      if (saveResult && event.imageChanged && event.imageURL.isNotEmpty && !event.imageURL.startsWith('assets/')) {
        await projectRepository.updateProjectUrl(
          event.project,
          event.imageURL,
          originalImagePath: event.originalImagePath,
        );
      }

      if (!saveResult) {
        emit(const AddEditProjectFailure(error: "failed to save the project"));
      } else {
        emit(AddEditProjectSuccess());
      }
    } catch (e) {
      emit(AddEditProjectFailure(error: e.toString()));
    }
  }

  Future<void> _onReset(
    ResetAddEditProject event,
    Emitter<AddEditProjectState> emit,
  ) async {
    emit(AddEditProjectInitial());
  }

  Future<void> _onDeleteProject(
    DeleteProject event,
    Emitter<AddEditProjectState> emit,
  ) async {
    emit(AddEditProjectDeleting());
    try {
      if (event.projectId != null && event.projectId!.isNotEmpty) {
        await projectRepository.deleteProject(event.projectId!);
        emit(DeleteProjectSuccess());
      } else {
        emit(
          const AddEditProjectFailure(error: 'Invalid project ID for deletion'),
        );
      }
    } catch (e) {
      emit(AddEditProjectFailure(error: e.toString()));
    }
  }
}
