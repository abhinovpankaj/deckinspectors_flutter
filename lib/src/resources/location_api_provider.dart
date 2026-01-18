import 'dart:convert';
import 'package:http/http.dart' show Client;
import '../models/error_response.dart';
import '../models/location_model.dart';
import '../models/success_response.dart';
import 'urls.dart';

class LocationsApiProvider {
  Client client = Client();

  Future<LocationResponse> getLocation(String id) async {
    var endPoint = URLS.manageLocationUrl + id;
    final baseUrl = Uri.parse(endPoint);
    final response = await client.get(baseUrl);

    if (response.statusCode == 201) {
      return LocationResponse.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to get location');
    }
  }

  Future<Object> addLocation(Location location) async {
    final locationObject = jsonEncode({
      'name': location.name,
      'description': location.description,
      'parentid': location.parentid,
      'parenttype': location.parenttype,
      'url': location.url,
      'createdby': location.createdby,
      'type': location.type,
    });
    var endPoint = '${URLS.manageLocationUrl}add';
    final baseUrl = Uri.parse(endPoint);
    final response = await client.post(
      baseUrl,
      body: locationObject,
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 201) {
      return SuccessResponse.fromJson(json.decode(response.body));
    } else {
      return ErrorResponse.fromJson(json.decode(response.body));
    }
  }

  Future<Object> updateLocation(Location location, String id) async {
    final locationObject = jsonEncode({
      'name': location.name,
      'description': location.description,
      'url': location.url,
      'lasteditedby': location.lasteditedby,
    });
    var endPoint = URLS.manageLocationUrl + id;
    final baseUrl = Uri.parse(endPoint);
    final response = await client.put(
      baseUrl,
      body: locationObject,
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 201) {
      return SuccessResponse.fromJson(json.decode(response.body));
    } else {
      return ErrorResponse.fromJson(json.decode(response.body));
    }
  }

  Future<Object> deleteLocation(Object requestBody, String id) async {
    var endPoint = '${URLS.manageLocationUrl}$id/toggleVisibility';
    final baseUrl = Uri.parse(endPoint);
    final response = await client.post(
      baseUrl,
      body: requestBody,
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 201) {
      return SuccessResponse.fromJson(json.decode(response.body));
    } else {
      return ErrorResponse.fromJson(json.decode(response.body));
    }
  }
}
