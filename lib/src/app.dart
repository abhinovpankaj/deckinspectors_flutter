import 'dart:async';

import 'package:flutter/material.dart';
//import 'bloc/notificationcontroller.dart';
import 'ui/app_theme.dart';
import 'ui/login.dart';
import 'ui/navigation_observer.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'resources/couchbase/database_provider.dart';
import 'resources/couchbase/image_repository.dart';
import 'resources/couchbase/project_repository.dart';
import 'resources/couchbase/subproject_repository.dart';
import 'resources/couchbase/location_repository.dart';
import 'resources/couchbase/section_repository.dart';
import 'resources/couchbase/replicator_provider.dart';
import 'bloc/users_bloc.dart';
import 'bloc/settings_bloc.dart';
import 'resources/repository.dart';
import 'services/app_logger.dart';
import 'services/image_sync_service.dart';

class App extends StatefulWidget {
  const App({super.key});

  // The navigator key is necessary to navigate using static methods
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static bool isImageUploading = false;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void initState() {
    super.initState();
    appSettings.onConnectivityRestored = () {
      unawaited(
        AppLogger.instance.info(
          'Connectivity',
          'restored callback fired '
              '(activeConnection=${appSettings.activeConnection}, appOfflineMode=${appSettings.isAppOfflineMode})',
        ),
      );
      if (appSettings.isAppOfflineMode) {
        unawaited(
          AppLogger.instance.info(
            'Connectivity',
            'app is in OFFLINE MODE -> skip image sync and replicator resume',
          ),
        );
        return;
      }
      unawaited(
        AppLogger.instance.info(
          'Connectivity',
          'app is ONLINE MODE -> retry image sync and resume replicator',
        ),
      );
      ImageSyncService().retryPendingUploads();
      ReplicatorProvider.resumeActiveReplicatorIfAllowed();
    };
    appSettings.initConnectivity();
  }

  @override
  Widget build(BuildContext context) {
    // final currentUser =
    //     Provider.of<RealmProjectServices?>(context, listen: false)?.currentUser;

    // Create repositories here to provide them globally above MaterialApp
    final dbProvider = DatabaseProvider();
    final imageRepo = ImageRepository(dbProvider);
    final projectRepository = ProjectRepository(dbProvider, imageRepo);
    final subprojectRepository = SubprojectRepository(
      dbProvider,
      projectRepository,
      imageRepo,
      usersBloc,
      appSettings,
    );
    final locationRepository = LocationRepository(
      dbProvider,
      projectRepository,
      subprojectRepository,
      imageRepo,
      usersBloc,
      appSettings,
    );
    final sectionRepository = SectionRepository(
      dbProvider,
      locationRepository,
      subprojectRepository,
      imageRepo,
      usersBloc,
    );
    final globalRepository = Repository();

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: MultiRepositoryProvider(
        providers: [
          RepositoryProvider<ProjectRepository>.value(value: projectRepository),
          RepositoryProvider<SubprojectRepository>.value(
            value: subprojectRepository,
          ),
          RepositoryProvider<LocationRepository>.value(
            value: locationRepository,
          ),
          RepositoryProvider<SectionRepository>.value(value: sectionRepository),
          RepositoryProvider<ImageRepository>.value(value: imageRepo),
          RepositoryProvider<Repository>.value(value: globalRepository),
        ],
        child: MaterialApp(
          navigatorObservers: [NavigationObserver()],
          debugShowCheckedModeBanner: false,
          title: 'E3 Inspections',
          theme: AppTheme.lightTheme,
          builder: (context, child) {
            final MediaQueryData data = MediaQuery.of(context);
            final double clampedScale =
                data.textScaler.scale(1.0).clamp(1.0, 1.2).toDouble();

            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                boldText: false,
                textScaler: TextScaler.linear(clampedScale),
              ),
              child: child!,
            );
          },
          home: const SafeArea(child: LoginPage()),
        ),
      ),
    );
  }
}
