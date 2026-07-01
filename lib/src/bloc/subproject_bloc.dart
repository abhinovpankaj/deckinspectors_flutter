import 'package:flutter_bloc/flutter_bloc.dart';

import '../resources/couchbase/subproject_repository.dart';
import 'subproject_event.dart';
import 'subproject_state.dart';

class SubProjectBloc extends Bloc<SubProjectEvent, SubProjectState> {
  final SubprojectRepository subprojectRepository;

  SubProjectBloc({required this.subprojectRepository})
    : super(SubProjectInitial()) {
    on<LoadSubProjectEvent>(_onLoad);
    on<SaveSubProjectEvent>(_onSave);
    on<DeleteSubProjectEvent>(_onDelete);
  }

  Future<void> _onLoad(
    LoadSubProjectEvent event,
    Emitter<SubProjectState> emit,
  ) async {
    emit(SubProjectLoading());
    try {
      final subProject = await subprojectRepository.getSubProject(
        event.subProjectId,
      );
      if (subProject != null) {
        emit(SubProjectLoaded(subProject));
      } else {
        emit(const SubProjectFailure('SubProject not found'));
      }
    } catch (e) {
      emit(SubProjectFailure(e.toString()));
    }
  }

  Future<void> _onSave(
    SaveSubProjectEvent event,
    Emitter<SubProjectState> emit,
  ) async {
    emit(SubProjectSaving());
    try {
      final ok = await subprojectRepository.addupdateSubProject(
        event.subProject,
        event.name,
        event.description,
        event.isNewBuilding,
        event.fullUserName,
      );
      if (ok) {
        // Upload and persist the image URL when a new local image was captured
        if (event.imageChanged &&
            event.imageURL.isNotEmpty &&
            !event.imageURL.startsWith('assets/')) {
          await subprojectRepository.updateSubProjectUrl(
            event.subProject,
            event.imageURL,
            originalImagePath: event.originalImagePath,
          );
        }
        emit(SubProjectSuccess());
      } else {
        emit(const SubProjectFailure('Failed to save subproject'));
      }
    } catch (e) {
      emit(SubProjectFailure(e.toString()));
    }
  }

  Future<void> _onDelete(
    DeleteSubProjectEvent event,
    Emitter<SubProjectState> emit,
  ) async {
    emit(SubProjectLoading());
    try {
      final res = await subprojectRepository.deleteSubProject(event.subProject);
      if (res == 'success') {
        emit(SubProjectDeleteSuccess());
      } else {
        emit(const SubProjectDeleteFailure('Failed to delete subproject'));
      }
    } catch (e) {
      emit(SubProjectDeleteFailure(e.toString()));
    }
  }
}
