import 'package:equatable/equatable.dart';

abstract class LocationsState extends Equatable {
  const LocationsState();

  @override
  List<Object?> get props => [];
}

class LocationsInitial extends LocationsState {}

class LocationsLoading extends LocationsState {}

class LocationSaveSuccess extends LocationsState {}

class LocationSaveFailure extends LocationsState {
  final String error;
  const LocationSaveFailure(this.error);
  @override
  List<Object?> get props => [error];
}

class LocationDeleteSuccess extends LocationsState {}

class LocationDeleteFailure extends LocationsState {
  final String error;
  const LocationDeleteFailure(this.error);
  @override
  List<Object?> get props => [error];
}
