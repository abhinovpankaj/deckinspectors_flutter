import 'package:equatable/equatable.dart';
import '../models/couchbase/couchbase_models.dart';

abstract class LocationEvent extends Equatable {
  const LocationEvent();
  @override
  List<Object?> get props => [];
}

class LoadLocationEvent extends LocationEvent {
  final String locationId;
  const LoadLocationEvent(this.locationId);
  @override
  List<Object?> get props => [locationId];
}

class RefreshLocationEvent extends LocationEvent {
  final String locationId;
  const RefreshLocationEvent(this.locationId);
  @override
  List<Object?> get props => [locationId];
}

class SaveLocationEvent extends LocationEvent {
  final Location location;
  final bool isNew;
  final String fullUserName;
  final String description;
  final String name;

  const SaveLocationEvent({
    required this.location,
    required this.isNew,
    required this.name,
    required this.fullUserName,
    required this.description,
  });

  @override
  List<Object?> get props => [location, isNew, fullUserName, description, name];
}

class DeleteLocationEvent extends LocationEvent {
  final Location location;
  const DeleteLocationEvent(this.location);

  @override
  List<Object?> get props => [location];
}
