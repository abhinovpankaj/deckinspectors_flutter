import 'package:flutter_bloc/flutter_bloc.dart';
import '../resources/couchbase/dynamic_repository.dart';
import 'dynamic_visual_section_event.dart';
import 'dynamic_visual_section_state.dart';

class DynamicVisualSectionBloc
    extends Bloc<DynamicVisualSectionEvent, DynamicVisualSectionState> {
  final DynamicRepository repository;

  DynamicVisualSectionBloc(this.repository)
    : super(DynamicVisualSectionInitial()) {
    on<LoadDynamicVisualSection>(_onLoad);
    on<SaveDynamicVisualSection>(_onSave);
    on<DeleteDynamicVisualSection>(_onDelete);
    on<AddDynamicVisualSectionImages>(_onAddImages);
    on<RemoveDynamicVisualSectionImage>(_onRemoveImage);
  }

  Future<void> _onLoad(
    LoadDynamicVisualSection event,
    Emitter<DynamicVisualSectionState> emit,
  ) async {
    emit(DynamicVisualSectionLoading());
    try {
      final section = await repository.getDynamicSection(event.sectionId);
      if (section != null) {
        emit(DynamicVisualSectionLoaded(section));
      } else {
        emit(const DynamicVisualSectionError('Section not found'));
      }
    } catch (e) {
      emit(DynamicVisualSectionError(e.toString()));
    }
  }

  Future<void> _onSave(
    SaveDynamicVisualSection event,
    Emitter<DynamicVisualSectionState> emit,
  ) async {
    emit(DynamicVisualSectionSaving());
    try {
      final section = await repository.addupdateDynamicVisualSection(
        section: event.section,
        name: event.name,
        concerns: event.concerns,
        questions: event.questions,
        invasiveReviewRequired: event.invasiveReviewRequired,
        unitUnavailable: event.unitUnavailable,
        isNewSection: event.isNewSection,
        userFullName: event.userFullName,
      );
      emit(DynamicVisualSectionSaveSuccess(section));
    } catch (e) {
      emit(DynamicVisualSectionSaveFailure(e.toString()));
    }
  }

  Future<void> _onDelete(
    DeleteDynamicVisualSection event,
    Emitter<DynamicVisualSectionState> emit,
  ) async {
    emit(DynamicVisualSectionLoading());
    try {
      final sectionId = event.section.id;
      if (sectionId == null) {
        emit(const DynamicVisualSectionDeleteFailure('Section id is null'));
        return;
      }
      final result = await repository.deleteDynamicSectionById(sectionId);
      if (result == 'success') {
        emit(DynamicVisualSectionDeleteSuccess());
      } else {
        emit(
          const DynamicVisualSectionDeleteFailure('Failed to delete section'),
        );
      }
    } catch (e) {
      emit(DynamicVisualSectionDeleteFailure(e.toString()));
    }
  }

  Future<void> _onAddImages(
    AddDynamicVisualSectionImages event,
    Emitter<DynamicVisualSectionState> emit,
  ) async {
    emit(DynamicVisualSectionLoading());
    try {
      final sectionId = event.section.id;
      if (sectionId == null) {
        emit(const DynamicVisualSectionError('Section id is null'));
        return;
      }

      final result = await repository.addDynamicImagesUrl(
        event.section.name ?? '',
        sectionId,
        event.section,
        event.imagePaths,
        const [],
      );
      if (result) {
        emit(DynamicVisualSectionLoaded(event.section));
      } else {
        emit(const DynamicVisualSectionError('Failed to add images'));
      }
    } catch (e) {
      emit(DynamicVisualSectionError(e.toString()));
    }
  }

  Future<void> _onRemoveImage(
    RemoveDynamicVisualSectionImage event,
    Emitter<DynamicVisualSectionState> emit,
  ) async {
    emit(DynamicVisualSectionLoading());
    try {
      final result = await repository.removeDynamicImageUrl(
        event.section,
        event.imagePath,
      );
      if (result) {
        emit(DynamicVisualSectionLoaded(event.section));
      } else {
        emit(const DynamicVisualSectionError('Failed to remove image'));
      }
    } catch (e) {
      emit(DynamicVisualSectionError(e.toString()));
    }
  }
}
