import 'package:flutter_bloc/flutter_bloc.dart';
import '../resources/couchbase/invasive_section_repository.dart';
import 'invasive_section_event.dart';
import 'invasive_section_state.dart';

class InvasiveSectionBloc
    extends Bloc<InvasiveSectionEvent, InvasiveSectionState> {
  final InvasiveSectionRepository invasiveSectionRepository;

  InvasiveSectionBloc({required this.invasiveSectionRepository})
    : super(const InvasiveSectionInitial()) {
    on<LoadInvasiveSectionEvent>(_onLoadInvasiveSection);
    on<SaveInvasiveSectionEvent>(_onSaveInvasiveSection);
    on<DeleteInvasiveSectionEvent>(_onDeleteInvasiveSection);
  }

  Future<void> _onLoadInvasiveSection(
    LoadInvasiveSectionEvent event,
    Emitter<InvasiveSectionState> emit,
  ) async {
    emit(const InvasiveSectionLoading());
    try {
      final section = await invasiveSectionRepository.getInvasiveSection(
        event.sectionId,
      );
      if (section != null) {
        emit(InvasiveSectionLoaded(section));
      } else {
        emit(const InvasiveSectionError('Section not found'));
      }
    } catch (e) {
      emit(InvasiveSectionError('Failed to load section: ${e.toString()}'));
    }
  }

  Future<void> _onSaveInvasiveSection(
    SaveInvasiveSectionEvent event,
    Emitter<InvasiveSectionState> emit,
  ) async {
    emit(const InvasiveSectionSaving());
    try {
      final updatedSection = await invasiveSectionRepository
          .addupdateInvasiveSection(
            section: event.section,
            description: event.description,
            postInvasiveRepairsRequired: event.postInvasiveRepairsRequired,
            invasiveImages: event.invasiveImages,
            isNewSection: event.isNewSection,
          );
      emit(InvasiveSectionSaveSuccess(updatedSection));
    } catch (e) {
      emit(
        InvasiveSectionSaveFailure('Failed to save section: ${e.toString()}'),
      );
    }
  }

  Future<void> _onDeleteInvasiveSection(
    DeleteInvasiveSectionEvent event,
    Emitter<InvasiveSectionState> emit,
  ) async {
    emit(const InvasiveSectionDeleting());
    try {
      await invasiveSectionRepository.deleteInvasiveSection(event.section);
      emit(const InvasiveSectionDeleteSuccess());
    } catch (e) {
      emit(
        InvasiveSectionDeleteFailure(
          'Failed to delete section: ${e.toString()}',
        ),
      );
    }
  }
}
