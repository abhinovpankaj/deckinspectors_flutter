import 'dart:async';
import 'package:E3InspectionsMultiTenant/src/bloc/settings_bloc.dart';
import 'package:E3InspectionsMultiTenant/src/models/project_model.dart';
import 'package:E3InspectionsMultiTenant/src/models/section_model.dart';
import 'package:E3InspectionsMultiTenant/src/models/subproject_model.dart';
import 'package:E3InspectionsMultiTenant/src/models/users_response.dart';
import 'package:E3InspectionsMultiTenant/src/resources/couchbase/database_provider.dart';
import 'package:E3InspectionsMultiTenant/src/resources/project_api_provider.dart';
import 'package:E3InspectionsMultiTenant/src/resources/user_provider.dart';
import '../models/location_model.dart';
import '../models/login_response.dart';
import 'image_api_provider.dart';
import 'location_api_provider.dart';
import 'section_api_provider.dart';
import 'subproject_api_provider.dart';

class Repository {
  //Projects
  final projectsApiProvider = ProjectsApiProvider();

  Future<Projects> fetchAllProjects() {
    return projectsApiProvider.fetchProjects();
  }

  Future<Object> getProject(String id) {
    return projectsApiProvider.getProject(id);
  }

  Future<Object> addProject(Project project) {
    return projectsApiProvider.addProject(project);
  }

  Future<Object> updateProject(Project project, String id) {
    return projectsApiProvider.updateProject(project, id);
  }

  Future<Object> deleteProject(Object projectObject, String id) {
    return projectsApiProvider.deleteProjectPermanently(id);
    //return projectsApiProvider.deleteProject(projectObject, id);
  }

  Future<Object> deleteOnlineProjectPermanently(String id) {
    return projectsApiProvider.deleteProjectPermanently(id);
  }

//local fetches

//Locations
  final locationApiProvider = LocationsApiProvider();

  Future<Object> getLocation(String id) {
    return locationApiProvider.getLocation(id);
  }

  Future<Object> addLocation(Location location) {
    return locationApiProvider.addLocation(location);
  }

  Future<Object> updateLocation(Location location, String id) {
    return locationApiProvider.updateLocation(location, id);
  }

  Future<Object> deleteLocation(Object locationObject, String id) {
    return locationApiProvider.deleteLocation(locationObject, id);
  }

  //Sections
  final sectionApiProvider = SectionsApiProvider();

  Future<Object> getSection(String id) {
    return sectionApiProvider.getSection(id);
  }

  Future<Object> addSection(VisualSection visualSection) {
    return sectionApiProvider.addSection(visualSection);
  }

  Future<Object> updateSection(VisualSection visualSection, String id) {
    return sectionApiProvider.updateSection(visualSection, id);
  }

  Future<Object> deleteSection(Object visualObject, String id) {
    return sectionApiProvider.deleteSection(visualObject, id);
  }

  //SubProject
  final subProjectApiProvider = SubProjectApiProvider();

  Future<Object> getSubProject(String id) {
    return subProjectApiProvider.getSubProject(id);
  }

  Future<Object> addSubProject(SubProject subProject) {
    return subProjectApiProvider.addSubProject(subProject);
  }

  Future<Object> updateSubProject(SubProject subProject, String id) {
    return subProjectApiProvider.updateSubProject(subProject, id);
  }

  Future<Object> deleteSubProject(Object subProjectObject, String id) {
    return subProjectApiProvider.deleteSubProject(subProjectObject, id);
  }

  //Users
  final usersApiProvider = UsersApiProvider();
  Future<LoginResponse> login(Object loginReq) =>
      usersApiProvider.login(loginReq);
  Future<bool> logout(Object loginReq) => usersApiProvider.logout(loginReq);

  final imageApiProvider = ImagesApiProvider();

  Future<Object> uploadImage(String path, String containerName, String uploader,
      String id, String parentType, String entityName) {
    if (DatabaseProvider.offlineModeOn || !appSettings.activeConnection) {
      return imageApiProvider.uploadImageLocally(
          path, containerName, uploader, id, parentType, entityName);
    } else {
      return imageApiProvider.uploadImage(
          path, containerName, uploader, id, parentType, entityName);
    }
  }

  Future<Object> saveImageLocal(String path, String containerName,
      String uploader, String id, String parentType, String entityName) {
    return imageApiProvider.uploadImageLocally(
        path, containerName, uploader, id, parentType, entityName);
  }

  Future<Object> downloadProjectReport(String name, String id, String fileType,
      int quality, int imageFactor, String reportType, String companyName) {
    return projectsApiProvider.downloadReport(
        name, id, fileType, quality, imageFactor, reportType, companyName);
  }

  Future<UsersResponse> getAllUsers(String token) {
    return usersApiProvider.getAllUsers(token);
  }

  Future<RegisterResponse> register(Object registerObject) {
    return usersApiProvider.register(registerObject);
  }
}



///home/site/wwwroot/routes/project-endpoint.js:333:29 {