import 'package:E3InspectionsMultiTenant/src/ui/projects.dart';
//import 'package:E3InspectionsMultiTenant/src/ui/reports_screen.dart';
import 'package:E3InspectionsMultiTenant/src/ui/settings.dart';
// import 'package:google_fonts/google_fonts.dart';
//import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'reports_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final pages = [
    const Center(child: ProjectsPage()),
    //Center(child: OfflineModePage()),
    const Center(child: ReportsPage()),
    const Center(child: SettingsPage()),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
          child: pages[_currentIndex],
        ),
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
            }));
  }
}
