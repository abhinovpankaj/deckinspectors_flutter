import 'package:flutter_bloc/flutter_bloc.dart';
import '../resources/couchbase/location_repository.dart';
import '../models/couchbase/couchbase_models.dart';
import 'locations_event.dart';
import 'locations_state.dart';

class LocationsBloc extends Bloc<LocationsEvent, LocationsState> {
  final LocationRepository locationRepository;

  LocationsBloc({required this.locationRepository})
    : super(LocationsInitial()) {
    on<SaveLocationEvent>(_onSaveLocation);
    on<DeleteLocationEvent>(_onDeleteLocation);
  }

  Future<void> _onSaveLocation(
    SaveLocationEvent event,
    Emitter<LocationsState> emit,
  ) async {
    emit(LocationsLoading());
    try {
      await locationRepository.addupdateLocation(
        event.location,
        event.name,
        event.description,
        event.fullUserName,
        event.isNew,
      );

      emit(LocationSaveSuccess());
    } catch (e) {
      emit(LocationSaveFailure(e.toString()));
    }
  }

  Future<void> _onDeleteLocation(
    DeleteLocationEvent event,
    Emitter<LocationsState> emit,
  ) async {
    emit(LocationsLoading());
    try {
      await locationRepository.deleteLocation(event.location);
      emit(LocationDeleteSuccess());
    } catch (e) {
      emit(LocationDeleteFailure(e.toString()));
    }
  }
}
