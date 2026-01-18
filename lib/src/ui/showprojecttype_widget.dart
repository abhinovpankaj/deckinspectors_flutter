import 'package:flutter/material.dart';
import '../bloc/settings_bloc.dart';

class ProjectType extends StatefulWidget {
  const ProjectType({super.key});

  @override
  State<ProjectType> createState() => _ProjectTypeState();
}

class _ProjectTypeState extends State<ProjectType>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  //late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    // _fadeAnimation = CurvedAnimation(
    //   parent: _fadeController,
    //   curve: Curves.linear,
    // );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return
    // FadeTransition(
    //   opacity: _fadeAnimation,
    //   // Wrap the ListTile in a Material widget so the ListTile has someplace
    //   // to draw the animated colors during the fade transition.
    //   child:
    Material(
      child: ListTile(
        visualDensity: const VisualDensity(vertical: -4),
        minLeadingWidth: 100,
        title:
            appSettings.isInvasiveMode
                ? const Text('Invasive Mode', textAlign: TextAlign.center)
                : const Text('Visual Mode', textAlign: TextAlign.center),
        selectedTileColor:
            appSettings.isInvasiveMode ? Colors.orange : Colors.blue,
        selectedColor: Colors.white,
        selected: true,
      ),
    );
  }
}
