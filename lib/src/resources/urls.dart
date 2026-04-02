class URLS {
  static const String baseUrl =
      'https://deckmultitenantwebservices.azurewebsites.net/api';
  //static const String baseUrl = 'http://localhost:3000/api';
  static const String allProjectsUrl = '$baseUrl/project/allprojects';
  static const String addProjectsUrl = '$baseUrl/project/add';
  static const String manageProjectsUrl = '$baseUrl/project/';

  static const String userLogout = '$baseUrl/login/logout';
  static const String userLogin = '$baseUrl/login/login';
  static const String registerUser = '$baseUrl/user/register';
  static const String getAllUsers = '$baseUrl/user/allusers';
  static const String addLocationnUrl = '$baseUrl/location/add';
  static const String manageLocationUrl = '$baseUrl/location/';

  static const String addSubprojectUrl = '$baseUrl/subproject/add';
  static const String manageSubprojectUrl = '$baseUrl/subproject/';

  static const String addSectiontUrl = '$baseUrl/section/add';
  static const String manageSectionUrl = '$baseUrl/section/';

  static const String manageImagesUrl = '$baseUrl/image/';
}
