import 'package:E3InspectionsMultiTenant/src/bloc/settings_bloc.dart';
import 'package:E3InspectionsMultiTenant/src/bloc/users_bloc.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:provider/provider.dart';
import 'src/app.dart';
import 'src/bloc/notificationcontroller.dart';
import 'src/services/realm_local_services.dart';
import 'src/services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Always initialize Awesome Notifications
  await NotificationController.initializeLocalNotifications();
  await NotificationController.initializeIsolateReceivePort();
  final GoogleMapsFlutterPlatform mapsImplementation =
      GoogleMapsFlutterPlatform.instance;
  if (mapsImplementation is GoogleMapsFlutterAndroid) {
    // Force Hybrid Composition mode.
    mapsImplementation.useAndroidViewSurface = true;
  }
  return runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSettings>(create: (_) => AppSettings()),
        ChangeNotifierProxyProvider<AppSettings, RealmLocalServices?>(
          create: (context) => null,
          update: (
            BuildContext context,
            AppSettings appSettings,
            RealmLocalServices? realmServices,
          ) {
            if (usersBloc.userDetails.username != null) {
              realmServices = RealmLocalServices(
                usersBloc.userDetails.username as String,
                usersBloc.userDetails.companyidentifer as String,
              );
              realmServices.uploadLocalImages();
              final syncService = SyncService(realmServices);
              syncService.initSocket();
              //syncService.startSync();
            }
            return realmServices;
          },
        ),
      ],
      child: const App(),
    ),
  );
}
