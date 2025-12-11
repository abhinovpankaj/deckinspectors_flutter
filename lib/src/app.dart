import 'package:flutter/material.dart';
import 'bloc/notificationcontroller.dart';
import 'ui/login.dart';
import 'ui/navigation_observer.dart';

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
    //NotificationController.startListeningNotificationEvents();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // final currentUser =
    //     Provider.of<RealmProjectServices?>(context, listen: false)?.currentUser;

    return GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: MaterialApp(
          navigatorObservers: [NavigationObserver()],
          debugShowCheckedModeBanner: false,
          title: 'E3 Inspections',
          builder: (context, child) {
            final MediaQueryData data = MediaQuery.of(context);

            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  boldText: false,
                  textScaleFactor:
                      data.textScaleFactor > 2 ? 1.2 : data.textScaleFactor),
              child: child!,
            );
          },
          home: const SafeArea(child: LoginPage()),
        ));
  }
}
