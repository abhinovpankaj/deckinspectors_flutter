import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/couchbase/couchbase_models.dart';
import '../resources/couchbase/dynamic_repository.dart';
import 'dynamic_section_event.dart';
import 'dynamic_section_state.dart';

class DynamicSectionBloc
    extends Bloc<DynamicSectionEvent, DynamicSectionState> {
  final DynamicRepository dynamicRepository;

  DynamicSectionBloc({required this.dynamicRepository})
    : super(const DynamicSectionInitial()) {
    on<LoadDynamicSectionEvent>(_onLoadDynamicSection);
    on<SaveDynamicSectionEvent>(_onSaveDynamicSection);
    on<DeleteDynamicSectionEvent>(_onDeleteDynamicSection);
  }

  Future<void> _onLoadDynamicSection(
    LoadDynamicSectionEvent event,
    Emitter<DynamicSectionState> emit,
  ) async {
    emit(const DynamicSectionLoading());
    try {
      final section = await dynamicRepository.getDynamicVisualSection(
        event.sectionId,
      );
      if (section != null) {
        emit(DynamicSectionLoaded(section));
      } else {
        emit(const DynamicSectionError('Section not found'));
      }
    } catch (e) {
      emit(DynamicSectionError('Failed to load section: ${e.toString()}'));
    }
  }

  Future<void> _onSaveDynamicSection(
    SaveDynamicSectionEvent event,
    Emitter<DynamicSectionState> emit,
  ) async {
    emit(const DynamicSectionSaving());
    try {
      final updatedSection = await dynamicRepository
          .addupdateDynamicVisualSection(
            section: event.section,
            name: event.name,
            concerns: event.concerns,
            questions: event.questions,
            invasiveReviewRequired: event.invasiveReviewRequired,
            isNewSection: event.isNewSection,
            userFullName: event.userFullName,
            unitUnavailable: event.unitUnavailable,
          );
      emit(DynamicSectionSaveSuccess(updatedSection));
    } catch (e) {
      emit(
        DynamicSectionSaveFailure('Failed to save section: ${e.toString()}'),
      );
    }
  }

  Future<void> _onDeleteDynamicSection(
    DeleteDynamicSectionEvent event,
    Emitter<DynamicSectionState> emit,
  ) async {
    emit(const DynamicSectionDeleting());
    try {
      await dynamicRepository.deleteDynamicVisualSection(event.section);
      emit(const DynamicSectionDeleteSuccess());
    } catch (e) {
      emit(
        DynamicSectionDeleteFailure(
          'Failed to delete section: ${e.toString()}',
        ),
      );
    }
  }
}
