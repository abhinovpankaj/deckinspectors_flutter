import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'projects.dart';
import 'reports_screen.dart';
import 'settings.dart';
import '../resources/couchbase/database_provider.dart';
import '../resources/couchbase/image_repository.dart';
import '../resources/couchbase/project_repository.dart';
import '../resources/couchbase/subproject_repository.dart';
import '../resources/couchbase/location_repository.dart';
import '../bloc/users_bloc.dart';
import '../bloc/settings_bloc.dart';
import '../resources/repository.dart';
import '../bloc/projects_bloc.dart';
import '../bloc/projects_event.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Create repositories here so we can provide the ProjectsBloc to the
    // embedded ProjectsPage when HomePage is used as the app's shell.
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

    final globalRepository = Repository();

    final pages = [
      RepositoryProvider<ProjectRepository>.value(
        value: projectRepository,
        child: RepositoryProvider<SubprojectRepository>.value(
          value: subprojectRepository,
          child: RepositoryProvider<LocationRepository>.value(
            value: locationRepository,
            child: RepositoryProvider<Repository>.value(
              value: globalRepository,
              child: BlocProvider(
                create:
                    (_) =>
                        ProjectsBloc(projectRepository: projectRepository)
                          ..add(LoadProjectsEvent()),
                child: const Center(child: ProjectsPage()),
              ),
            ),
          ),
        ),
      ),
      //Center(child: OfflineModePage()),
      const Center(child: ReportsPage()),
      const Center(child: SettingsPage()),
    ];
    return Scaffold(
      body: SafeArea(child: pages[_currentIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        iconSize: 30,
        selectedFontSize: 16,
        unselectedFontSize: 14,
        fixedColor: Colors.blue,
        unselectedItemColor: Colors.lightBlueAccent,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
            // backgroundColor: Colors.orange
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.document_scanner),
            label: 'Reports',
            // backgroundColor: Colors.blueAccent
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
            // backgroundColor: Colors.blue
          ),
        ],
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });

          // if (index == 1) {
          //   appSettings.isAppOfflineMode = true;
          // } else {
          //   appSettings.isAppOfflineMode = false;
          // }
        },
      ),
    );
  }
}
