import 'dart:convert';

import 'dart:io';
import 'package:http/http.dart' show Client;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../bloc/users_bloc.dart';
import '../models/error_response.dart';
import '../models/project_model.dart';
import '../models/success_response.dart';
import 'urls.dart';

class ProjectsApiProvider {
  Client client = Client();

  Future<Projects> fetchProjects() async {
    final baseUrl = Uri.parse(URLS.allProjectsUrl);
    final response = await client.get(baseUrl);
    //print(response.body.toString());

    if (response.statusCode == 201) {
      return Projects.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load projects');
    }
  }

  Future<Object> getProject(String id) async {
    var endPoint = URLS.manageProjectsUrl + id;
    final baseUrl = Uri.parse(endPoint);
    final response = await client.get(baseUrl);

    if (response.statusCode == 201) {
      return ProjectResponse.fromJson(json.decode(response.body));
    } else {
      return ErrorResponse(message: 'failed', code: response.statusCode);
    }
  }

  Future<Object> addProject(Project project) async {
    final projectObject = jsonEncode({
      'name': project.name,
      'description': project.description,
      'address': project.address,
      'url': project.url,
      'projectType': project.projecttype,
      'createdby': project.createdby,
    });
    final baseUrl = Uri.parse(URLS.addProjectsUrl);
    final response = await client.post(
      baseUrl,
      body: projectObject,
      headers: {'Content-Type': 'application/json'},
    );
    //print(response.body.toString());

    if (response.statusCode == 201) {
      return SuccessResponse.fromJson(json.decode(response.body));
    } else {
      return ErrorResponse.fromJson(json.decode(response.body));
    }
  }

  Future<Object> updateProject(Project project, String id) async {
    final projectObject = jsonEncode({
      'name': project.name,
      'description': project.description,
      'address': project.address,
      'url': project.url,
      'lasteditedby': project.lasteditedby,
    });
    var endPoint = URLS.manageProjectsUrl + id;
    final baseUrl = Uri.parse(endPoint);
    final response = await client.put(
      baseUrl,
      body: projectObject,
      headers: {'Content-Type': 'application/json'},
    );
    //print(response.body.toString());

    if (response.statusCode == 201) {
      return SuccessResponse.fromJson(json.decode(response.body));
    } else {
      return ErrorResponse.fromJson(json.decode(response.body));
    }
  }

  deleteProject(Object requestBody, String id) async {
    var endPoint = '${URLS.manageProjectsUrl}id/toggleVisibility';
    final baseUrl = Uri.parse(endPoint);
    final response = await client.post(
      baseUrl,
      body: requestBody,
      headers: {'Content-Type': 'application/json'},
    );
    //print(response.body.toString());

    if (response.statusCode == 201) {
      return SuccessResponse.fromJson(json.decode(response.body));
    } else {
      return ErrorResponse.fromJson(json.decode(response.body));
    }
  }

  Future<Object> deleteProjectPermanently(String id) async {
    var endPoint = '${URLS.manageProjectsUrl}$id';
    final baseUrl = Uri.parse(endPoint);
    final response = await client.delete(
      baseUrl,
      headers: {'Content-Type': 'application/json'},
    );
    //print(response.body.toString());

    if (response.statusCode == 201) {
      return SuccessResponse.fromJson(json.decode(response.body));
    } else {
      return ErrorResponse.fromJson(json.decode(response.body));
    }
  }

  Future<Object> downloadReport(
    String projectName,
    String id,
    String fileType,
    int quality,
    int imageFactor,
    String reportType,
    String companyName,
  ) async {
    try {
      var endPoint = '${URLS.manageProjectsUrl}/generatereporthtml';
      final baseUrl = Uri.parse(endPoint);
      final reportBody = jsonEncode({
        'id': id,
        'companyName': companyName,
        'reportType': reportType,
        'sectionImageProperties': {
          'compressionQuality':
              100, //quality, for timebeing till the optimization is done.
          'imageFactor': imageFactor,
        },
      });

      final response = await client
          .post(
            baseUrl,
            body: reportBody,
            headers: {
              'Content-Type': 'application/json',
              'authorization': usersBloc.userDetails.token as String,
            },
          )
          .timeout(const Duration(seconds: 600));
      //print(response.body.toString());

      if (response.statusCode == 200) {
        //save file
        Directory? directory = await getApplicationDocumentsDirectory();

        var destDirectory = await Directory(
          path.join(directory.path, companyName),
        ).create(recursive: true);
        final now = DateTime.now();
        var reportFile = path.join(
          destDirectory.path,
          '$projectName-$reportType-$now.html',
        );
        final file = File(reportFile);

        //print("HTML_RESULT ${response.body}");
        var writtenFile = await file.writeAsString(
          response.body,
          encoding: utf8,
        );
        return SuccessResponse(code: 200, message: writtenFile.path);
      } else if (response.statusCode == 500) {
        return ErrorResponse(message: response.body, code: response.statusCode);
      } else {
        return ErrorResponse(code: 502, message: response.body);
      }
    } catch (e) {
      return ErrorResponse(message: e.toString(), code: 502);
    }
  }
}
