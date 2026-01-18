import 'package:equatable/equatable.dart';
import '../models/couchbase/couchbase_models.dart';

abstract class LocationState extends Equatable {
  @override
  List<Object?> get props => [];
}

class LocationInitial extends LocationState {}

class LocationLoading extends LocationState {}

class LocationLoaded extends LocationState {
  final Location location;
  LocationLoaded(this.location);
  @override
  List<Object?> get props => [location];
}

class LocationError extends LocationState {
  final String message;
  LocationError(this.message);
  @override
  List<Object?> get props => [message];
}
