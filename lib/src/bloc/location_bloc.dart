import 'package:flutter_bloc/flutter_bloc.dart';
import 'location_event.dart';
import 'location_state.dart';
import '../resources/couchbase/location_repository.dart';

class LocationBloc extends Bloc<LocationEvent, LocationState> {
  final LocationRepository locationRepository;

  LocationBloc({required this.locationRepository}) : super(LocationInitial()) {
    on<LoadLocationEvent>(_onLoadLocation);
    on<RefreshLocationEvent>(_onRefreshLocation);
    on<SaveLocationEvent>(_onSaveLocation);
    on<DeleteLocationEvent>(_onDeleteLocation);
  }

  Future<void> _onLoadLocation(
    LoadLocationEvent event,
    Emitter<LocationState> emit,
  ) async {
    emit(LocationLoading());
    try {
      final loc = await locationRepository.fetchLocationById(event.locationId);
      if (loc != null) {
        emit(LocationLoaded(loc));
      } else {
        emit(LocationError('Location not found'));
      }
    } catch (e) {
      emit(LocationError(e.toString()));
    }
  }

  Future<void> _onRefreshLocation(
    RefreshLocationEvent event,
    Emitter<LocationState> emit,
  ) async {
    add(LoadLocationEvent(event.locationId));
  }

  Future<void> _onSaveLocation(
    SaveLocationEvent event,
    Emitter<LocationState> emit,
  ) async {
    emit(LocationSaving());
    try {
      final ok = await locationRepository.addupdateLocation(
        event.location,
        event.name,
        event.description,
        event.fullUserName,
        event.isNew,
      );
      if (ok) {
        // Persist the image URL and update the parent child reference
        if (event.imageURL.isNotEmpty &&
            !event.imageURL.startsWith('assets/')) {
          await locationRepository.updateLocationUrl(
            event.location,
            event.imageURL,
          );
        }
        emit(LocationSaveSuccess());
      } else {
        emit(const LocationSaveFailure('Failed to save location'));
      }
    } catch (e) {
      emit(LocationSaveFailure(e.toString()));
    }
  }

  Future<void> _onDeleteLocation(
    DeleteLocationEvent event,
    Emitter<LocationState> emit,
  ) async {
    try {
      final res = await locationRepository.deleteLocation(event.location);
      if (res == 'success') {
        emit(LocationDeleteSuccess());
      } else {
        emit(const LocationDeleteFailure('Failed to delete location'));
      }
    } catch (e) {
      emit(LocationDeleteFailure(e.toString()));
    }
  }
}
