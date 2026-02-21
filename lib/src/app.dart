import 'package:flutter/material.dart';
//import 'bloc/notificationcontroller.dart';
import 'ui/login.dart';
import 'ui/navigation_observer.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'resources/couchbase/database_provider.dart';
import 'resources/couchbase/image_repository.dart';
import 'resources/couchbase/project_repository.dart';
import 'resources/couchbase/subproject_repository.dart';
import 'resources/couchbase/location_repository.dart';
import 'resources/couchbase/section_repository.dart';
import 'bloc/users_bloc.dart';
import 'bloc/settings_bloc.dart';
import 'resources/repository.dart';
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
    // When connectivity is restored, retry any images saved locally while offline.
    // ImageSyncService uses the DatabaseProvider singleton internally.
    appSettings.onConnectivityRestored = () {
      ImageSyncService().retryPendingUploads();
    };
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
          builder: (context, child) {
            final MediaQueryData data = MediaQuery.of(context);

            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                boldText: false,
                textScaler: data.textScaler.clamp(
                  minScaleFactor: 1,
                  maxScaleFactor: 1.2,
                ),
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
