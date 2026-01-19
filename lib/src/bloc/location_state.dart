import 'package:equatable/equatable.dart';
import '../models/couchbase/couchbase_models.dart';

abstract class LocationState extends Equatable {
  const LocationState();
  @override
  List<Object?> get props => [];
}

class LocationInitial extends LocationState {}

class LocationLoading extends LocationState {}

class LocationLoaded extends LocationState {
  final Location location;
  const LocationLoaded(this.location);
  @override
  List<Object?> get props => [location];
}

class LocationError extends LocationState {
  final String message;
  const LocationError(this.message);
  @override
  List<Object?> get props => [message];
}

class LocationSaving extends LocationState {}

class LocationSaveSuccess extends LocationState {}

class LocationSaveFailure extends LocationState {
  final String error;
  const LocationSaveFailure(this.error);
  @override
  List<Object?> get props => [error];
}

class LocationDeleteSuccess extends LocationState {}

class LocationDeleteFailure extends LocationState {
  final String error;
  const LocationDeleteFailure(this.error);
  @override
  List<Object?> get props => [error];
}
