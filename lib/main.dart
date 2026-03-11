import 'dart:convert';
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:provider/provider.dart';
import 'src/app.dart';
import 'src/resources/couchbase/couchbase_services.dart';
import 'src/services/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLogger.instance.init();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(
      AppLogger.instance.error(
        'FlutterError',
        details.exceptionAsString(),
        error: details.exception,
        stackTrace: details.stack,
      ),
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(
      AppLogger.instance.error(
        'PlatformError',
        'Unhandled platform error',
        error: error,
        stackTrace: stack,
      ),
    );
    return true;
  };

  final couchbaseConfig = json.decode(
    await rootBundle.loadString('assets/config/couchbaseConfig.json'),
  );
  String syncGatewayUrl = couchbaseConfig['syncGatewayUrl'];

  // Always initialize Awesome Notifications
  //await NotificationController.initializeLocalNotifications();
  //await NotificationController.initializeIsolateReceivePort();
  final GoogleMapsFlutterPlatform mapsImplementation =
      GoogleMapsFlutterPlatform.instance;
  if (mapsImplementation is GoogleMapsFlutterAndroid) {
    // Force Hybrid Composition mode.
    mapsImplementation.useAndroidViewSurface = true;
  }
  await runZonedGuarded(
    () async {
      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CouchbaseServices>(
              create: (_) => CouchbaseServices(syncGatewayUrl),
            ),
          ],
          child: const App(),
        ),
      );
    },
    (error, stackTrace) {
      unawaited(
        AppLogger.instance.error(
          'ZoneError',
          'Unhandled zone error',
          error: error,
          stackTrace: stackTrace,
        ),
      );
    },
  );
}
