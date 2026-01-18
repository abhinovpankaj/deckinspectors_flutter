import 'dart:convert';
import 'package:http/http.dart' show Client;
import '../models/error_response.dart';
import '../models/subproject_model.dart';
import '../models/success_response.dart';
import 'urls.dart';

class SubProjectApiProvider {
  Client client = Client();

  Future<SubProjectResponse> getSubProject(String id) async {
    var endPoint = URLS.manageSubprojectUrl + id;
    final baseUrl = Uri.parse(endPoint);
    final response = await client.get(baseUrl);

    if (response.statusCode == 201) {
      return SubProjectResponse.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to get location');
    }
  }

  Future<Object> addSubProject(SubProject subProject) async {
    var endPoint = '${URLS.manageSubprojectUrl}add';
    final baseUrl = Uri.parse(endPoint);
    final subProjectObject = jsonEncode({
      'name': subProject.name,
      'description': subProject.description,
      'parentid': subProject.parentid,
      'parenttype': subProject.parenttype,
      'url': subProject.url,
      'createdby': subProject.createdby,
    });
    final response = await client.post(
      baseUrl,
      body: subProjectObject,
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 201) {
      return SuccessResponse.fromJson(json.decode(response.body));
    } else {
      return ErrorResponse.fromJson(json.decode(response.body));
    }
  }

  Future<Object> updateSubProject(SubProject subProject, String id) async {
    final subProjectObject = jsonEncode({
      'name': subProject.name,
      'description': subProject.description,
      'url': subProject.url,
      'lasteditedby': subProject.lasteditedby,
    });
    var endPoint = URLS.manageSubprojectUrl + id;
    final baseUrl = Uri.parse(endPoint);
    final response = await client.put(
      baseUrl,
      body: subProjectObject,
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 201) {
      return SuccessResponse.fromJson(json.decode(response.body));
    } else {
      return ErrorResponse.fromJson(json.decode(response.body));
    }
  }

  Future<Object> deleteSubProject(Object requestBody, String id) async {
    var endPoint = '${URLS.manageSubprojectUrl}id/toggleVisibility';
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
