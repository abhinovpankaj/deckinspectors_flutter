import 'package:equatable/equatable.dart';
import '../models/couchbase/couchbase_models.dart';

abstract class LocationsEvent extends Equatable {
  const LocationsEvent();

  @override
  List<Object?> get props => [];
}

class SaveLocationEvent extends LocationsEvent {
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

class DeleteLocationEvent extends LocationsEvent {
  final Location location;
  const DeleteLocationEvent(this.location);

  @override
  List<Object?> get props => [location];
}
