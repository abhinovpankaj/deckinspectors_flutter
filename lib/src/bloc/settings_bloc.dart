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
  late StreamSubscription<List<ConnectivityResult>> connectivitySubscription;

  Future<void> initConnectivity() async {
    // Platform messages may fail, so we use a try/catch PlatformException.
    connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
    late List<ConnectivityResult> result;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      result = await _connectivity.checkConnectivity();
    } on PlatformException catch (e) {
      debugPrint('Couldn\'t check connectivity status + $e');
      return;
    }

    return _updateConnectionStatus(result);
  }

  Future<void> _updateConnectionStatus(List<ConnectivityResult> result) async {
    connectionStatus = result;
    //start the sync only on wifi .
    activeConnection = connectionStatus.contains(ConnectivityResult.wifi);
    if (activeConnection) {
      notifyListeners();
    }
  }
}

enum ImageQuality { high, medium, low }

final appSettings = AppSettings();
