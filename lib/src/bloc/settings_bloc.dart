import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppSettings extends ChangeNotifier {
  static AppSettings? _instance;

  AppSettings._internal();

  factory AppSettings() {
    _instance ??= AppSettings._internal();
    return _instance!;
  }
  ImageQuality currentQuality = ImageQuality.high;
  bool isAppOfflineMode = false;
  bool isInvasiveMode = false;
  String companyName = 'DeckInspectors';
  int reportImageQuality = 100;
  int imageinRowCount = 4;
  bool activeConnection = true;
  bool isImageUploading = false;
  List<ConnectivityResult> connectionStatus = [ConnectivityResult.none];

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  Future<void> initConnectivity() async {
    _connectivitySubscription ??= _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
    await refreshConnectivity();
  }

  /// Updates [activeConnection] from a fresh connectivity check. Call before
  /// deciding to upload so the decision uses current state, not stale.
  Future<void> refreshConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      await _updateConnectionStatus(result);
    } on PlatformException catch (e) {
      debugPrint('Couldn\'t check connectivity status: $e');
    }
  }

  Future<void> _updateConnectionStatus(List<ConnectivityResult> result) async {
    connectionStatus = result;
    // Accept WiFi, mobile data, and ethernet — not just WiFi
    activeConnection = connectionStatus.any(
      (r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet,
    );
    if (activeConnection && !isAppOfflineMode) {
      notifyListeners();
      // Trigger retry of any images that were saved locally while offline
      onConnectivityRestored?.call();
    }
  }

  /// Callback invoked when the device comes back online.
  /// Register this in app.dart to retry pending image uploads.
  VoidCallback? onConnectivityRestored;
}

enum ImageQuality { high, medium, low }

final appSettings = AppSettings();
