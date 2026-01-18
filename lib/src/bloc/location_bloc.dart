import 'package:flutter_bloc/flutter_bloc.dart';
import 'location_event.dart';
import 'location_state.dart';
import '../resources/couchbase/location_repository.dart';

class LocationBloc extends Bloc<LocationEvent, LocationState> {
  final LocationRepository locationRepository;

  LocationBloc({required this.locationRepository}) : super(LocationInitial()) {
    on<LoadLocationEvent>(_onLoadLocation);
    on<RefreshLocationEvent>(_onRefreshLocation);
  }

  Future<void> _onLoadLocation(
      LoadLocationEvent event, Emitter<LocationState> emit) async {
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
      RefreshLocationEvent event, Emitter<LocationState> emit) async {
    add(LoadLocationEvent(event.locationId));
  }
}
