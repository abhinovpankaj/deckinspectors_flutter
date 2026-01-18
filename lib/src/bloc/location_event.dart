import 'package:equatable/equatable.dart';

abstract class LocationEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadLocationEvent extends LocationEvent {
  final String locationId;
  LoadLocationEvent(this.locationId);
  @override
  List<Object?> get props => [locationId];
}

class RefreshLocationEvent extends LocationEvent {
  final String locationId;
  RefreshLocationEvent(this.locationId);
  @override
  List<Object?> get props => [locationId];
}
