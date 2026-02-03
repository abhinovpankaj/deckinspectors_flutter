import 'package:flutter_bloc/flutter_bloc.dart';
import '../resources/couchbase/section_repository.dart';
import 'section_event.dart';
import 'section_state.dart';

class SectionBloc extends Bloc<SectionEvent, SectionState> {
  final SectionRepository sectionRepository;

  SectionBloc({required this.sectionRepository}) : super(SectionInitial()) {
    on<LoadSectionEvent>(_onLoadSection);
    on<SaveSectionEvent>(_onSaveSection);
    on<DeleteSectionEvent>(_onDeleteSection);
  }

  Future<void> _onLoadSection(
    LoadSectionEvent event,
    Emitter<SectionState> emit,
  ) async {
    emit(SectionLoading());
    try {
      final section = await sectionRepository.getVisualSection(event.sectionId);
      if (section != null) {
        emit(SectionLoaded(section));
      } else {
        emit(const SectionError('Section not found'));
      }
    } catch (e) {
      emit(SectionError(e.toString()));
    }
  }

  Future<void> _onSaveSection(
    SaveSectionEvent event,
    Emitter<SectionState> emit,
  ) async {
    emit(SectionSaving());
    try {
      final ok = await sectionRepository.addupdateVisualSection(
        event.section,
        event.name,
        event.concerns,
        event.exteriorElements,
        event.waterproofingElements,
        event.review,
        event.assessment,
        event.eee,
        event.lbc,
        event.awe,
        event.invasiveReviewRequired,
        event.hasSignsOfLeak,
        event.isNewSection,
        event.userFullName,
        event.unitUnavailable,
      );
      if (ok) {
        emit(SectionSaveSuccess(event.section));
      } else {
        emit(const SectionSaveFailure('Failed to save section'));
      }
    } catch (e) {
      emit(SectionSaveFailure(e.toString()));
    }
  }

  Future<void> _onDeleteSection(
    DeleteSectionEvent event,
    Emitter<SectionState> emit,
  ) async {
    emit(SectionLoading());
    try {
      final result = await sectionRepository.deleteVisualSection(event.section);
      if (result == 'success') {
        emit(SectionDeleteSuccess());
      } else {
        emit(const SectionDeleteFailure('Failed to delete section'));
      }
    } catch (e) {
      emit(SectionDeleteFailure(e.toString()));
    }
  }
}
