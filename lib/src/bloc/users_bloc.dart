import 'dart:convert';
import '../models/login_response.dart';
import '../models/users_response.dart';
import '../resources/repository.dart';

class UsersBloc {
  late String password;
  final Repository _repository = Repository();

  //final _usersFetcher = PublishSubject<LoginResponse>();
  LoginResponse userDetails = LoginResponse();
  String? currentFormId;

  Future<LoginResponse> login(
    String username,
    String pass,
    String deviceId,
  ) async {
    password = pass;
    //print('called login api');
    final loginObject = jsonEncode({
      'username': username,
      'password': password,
      'isMobile': true,
      'deviceId': deviceId,
    });
    LoginResponse response = await _repository.login(loginObject);
    userDetails = response;

    return response;
  }

  getCurrentUser() {
    return {
      'username': userDetails.username,
      'token': userDetails.token,
      'firstName': userDetails.firstname,
      'lastName': userDetails.lastname,
      'email': userDetails.email,
      'role': userDetails.role,
      'companyIdentifier': userDetails.companyidentifer,
    };
  }

  Future<bool> logout(String username) async {
    username = username;
    //print('called login api');
    final loginObject = jsonEncode({
      'username': username,
      'password': password,
    });
    return await _repository.logout(loginObject);
  }

  register(
    String username,
    String password,
    String firstName,
    String lastName,
    String emailId,
  ) async {
    final loginObject = jsonEncode({
      'username': username,
      'password': password,
      'email': emailId,
      'first_name': firstName,
      'last_name': lastName,
      'access_type': 'mobile',
    });
    RegisterResponse response = await _repository.register(loginObject);
    return response;
  }

  getAllUsers() async {
    UsersResponse userResponse = await _repository.usersApiProvider.getAllUsers(
      userDetails.token as String,
    );

    return userResponse;
  }

  // dispose() {
  //   _usersFetcher.close();
  // }
}

final usersBloc = UsersBloc();
