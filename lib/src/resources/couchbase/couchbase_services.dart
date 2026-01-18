import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Service class for Couchbase Sync Gateway authentication
/// Replaces Realm Device Sync with Couchbase Lite + Sync Gateway
class CouchbaseServices with ChangeNotifier {
  String syncGatewayUrl;
  String? currentUserEmail;
  String? currentUserPassword;
  String? userSessionToken;
  bool isAuthenticated = false;
  bool isOffline = false;
  //final _controller = StreamController<AuthenticationStatus>();

  CouchbaseServices(this.syncGatewayUrl);
  // Stream<AuthenticationStatus> get status async* {
  //   await Future<void>.delayed(const Duration(milliseconds: 20));
  //   yield AuthenticationStatus.unauthenticated;
  //   yield* _controller.stream;
  // }

  void logInUser() {
    isAuthenticated = true;
    notifyListeners();
  }

  /// Login user with email and password
  /// This authenticates against Sync Gateway which will sync documents
  Future<bool> logInUserEmailPassword(String email, String password) async {
    try {
      final Uri url = Uri.parse('$syncGatewayUrl/db/_session');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'name': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        userSessionToken = responseData['session_id'];
        currentUserEmail = email;
        currentUserPassword = password;
        isAuthenticated = true;
        notifyListeners();
        return true;
      } else {
        debugPrint('Login failed: ${response.statusCode} - ${response.body}');
        isAuthenticated = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('Error during login: $e');
      isAuthenticated = false;
      notifyListeners();
      return false;
    }
  }

  /// Register a new user
  /// This creates a new user in Couchbase Sync Gateway
  Future<bool> registerUserEmailPassword(String email, String password) async {
    try {
      final Uri url = Uri.parse('$syncGatewayUrl/db/_user/$email');

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': email,
          'password': password,
          'email': email,
          'admin_roles': [],
          'roles': ['user'],
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Registration successful, now login
        return await logInUserEmailPassword(email, password);
      } else {
        debugPrint(
            'Registration failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error during registration: $e');
      return false;
    }
  }

  /// Login anonymously
  /// Creates an anonymous session for Sync Gateway
  Future<bool> logInAnonymously() async {
    try {
      isAuthenticated = true;
      currentUserEmail = 'anonymous_${DateTime.now().millisecondsSinceEpoch}';
      currentUserPassword = 'anonymous';
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error during anonymous login: $e');
      isAuthenticated = false;
      notifyListeners();
      return false;
    }
  }

  /// Logout the current user
  /// Clears session and credentials
  Future<void> logOut() async {
    try {
      if (userSessionToken != null) {
        final Uri url = Uri.parse('$syncGatewayUrl/db/_session');
        await http.delete(
          url,
          headers: {
            'Cookie': 'SyncGatewaySession=$userSessionToken',
          },
        );
      }

      userSessionToken = null;
      currentUserEmail = null;
      currentUserPassword = null;
      isAuthenticated = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error during logout: $e');
      isAuthenticated = false;
      notifyListeners();
    }
  }

  /// Get current authentication headers for API calls
  Map<String, String> getAuthHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (userSessionToken != null) {
      headers['Cookie'] = 'SyncGatewaySession=$userSessionToken';
    } else if (currentUserEmail != null && currentUserPassword != null) {
      // Basic auth as fallback
      final credentials =
          base64Encode(utf8.encode('$currentUserEmail:$currentUserPassword'));
      headers['Authorization'] = 'Basic $credentials';
    }

    return headers;
  }

  /// Notify listeners for offline mode changes
  void notifyinCaseofOfflineMode() {
    isOffline = true;
    notifyListeners();
  }
}

enum AuthenticationStatus {
  unknown,
  authenticated,
  unauthenticated,
  authenticatedFailed,
  logout
}
