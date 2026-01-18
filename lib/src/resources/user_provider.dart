import 'dart:convert';
import 'package:http/http.dart' show Client;

//import '../models/error_response.dart';
import '../models/login_response.dart';
import '../models/users_response.dart';
import 'urls.dart';

class UsersApiProvider {
  Client client = Client();
  final _baseUrl = Uri.parse(URLS.userLogin);
  final _logoutUrl = Uri.parse(URLS.userLogout);
  final _regUrl = Uri.parse(URLS.registerUser);
  final _allUsersUrl = Uri.parse(URLS.getAllUsers);
  Future<LoginResponse> login(Object requestBody) async {
    final response = await client.post(
      _baseUrl,
      body: requestBody,
      headers: {'Content-Type': 'application/json'},
    );
    //print(response.body.toString());

    if (response.statusCode == 201) {
      return LoginResponse.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      return LoginResponse(username: 'loggedin', token: response.body);
    } else {
      return LoginResponse(id: null, username: null);
    }
  }

  Future<bool> logout(Object requestBody) async {
    final response = await client.post(
      _logoutUrl,
      body: requestBody,
      headers: {'Content-Type': 'application/json'},
    );
    //print(response.body.toString());

    if (response.statusCode == 201) {
      return true;
    } else {
      return false;
    }
  }

  Future<RegisterResponse> register(Object requestBody) async {
    final response = await client.post(
      _regUrl,
      body: requestBody,
      headers: {'Content-Type': 'application/json'},
    );
    //print(response.body.toString());

    if (response.statusCode == 201) {
      return RegisterResponse.fromJson(json.decode(response.body));
    } else {
      return RegisterResponse(acknowledged: false, insertedId: null);
    }
  }

  Future<UsersResponse> getAllUsers(String token) async {
    final response = await client.get(
      _allUsersUrl,
      headers: {'Content-Type': 'application/json', 'authorization': token},
    );
    //print(response.body.toString());

    if (response.statusCode == 200) {
      return UsersResponse.userFromJson(response.body);
    } else {
      return UsersResponse.userFromJson('[]');
    }
  }
}
