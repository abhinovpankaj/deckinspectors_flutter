import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'projects.dart';
import 'reports_screen.dart';
import 'settings.dart';
import '../resources/couchbase/project_repository.dart';

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
    final pages = [
      BlocProvider(
        create:
            (_) => ProjectsBloc(
              projectRepository: context.read<ProjectRepository>(),
            )..add(LoadProjectsEvent()),
        child: const Center(child: ProjectsPage()),
      ),
      const Center(child: ReportsPage()),
      const Center(child: SettingsPage()),
    ];
    return Scaffold(
      body: SafeArea(child: pages[_currentIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
