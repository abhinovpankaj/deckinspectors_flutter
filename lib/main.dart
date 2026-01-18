import 'dart:convert';

import 'package:E3InspectionsMultiTenant/src/bloc/settings_bloc.dart';
import 'package:E3InspectionsMultiTenant/src/bloc/users_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:provider/provider.dart';
import 'src/app.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'src/bloc/locations_bloc.dart';
import 'src/bloc/notificationcontroller.dart';
import 'src/resources/couchbase/couchbase_services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final couchbaseConfig = json.decode(
    await rootBundle.loadString('assets/config/couchbaseConfig.json'),
  );
  String syncGatewayUrl = couchbaseConfig['syncGatewayUrl'];
  String syncGatewayUsername = couchbaseConfig['syncGatewayUsername'];
  String syncGatewayPassword = couchbaseConfig['syncGatewayPassword'];

  // Always initialize Awesome Notifications
  //await NotificationController.initializeLocalNotifications();
  //await NotificationController.initializeIsolateReceivePort();
  final GoogleMapsFlutterPlatform mapsImplementation =
      GoogleMapsFlutterPlatform.instance;
  if (mapsImplementation is GoogleMapsFlutterAndroid) {
    // Force Hybrid Composition mode.
    mapsImplementation.useAndroidViewSurface = true;
  }
  return runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<CouchbaseServices>(
          create: (_) => CouchbaseServices(syncGatewayUrl),
        ),
      ],
      child: const App(),
    ),
  );
}
