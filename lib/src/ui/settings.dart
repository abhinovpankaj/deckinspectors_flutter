import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/users_bloc.dart';
import '../resources/couchbase/couchbase_services.dart';
import '../resources/couchbase/database_provider.dart';
import '../resources/couchbase/replicator_provider.dart';
import '../services/app_logger.dart';
import 'login.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late ImageQuality selectedQuality;
  bool isLowQuality = false;
  bool isHighQuality = false;
  bool isMediumQuality = true;
  PackageInfo _packageInfo = PackageInfo(
    appName: 'Unknown',
    packageName: 'Unknown',
    version: 'Unknown',
    buildNumber: 'Unknown',
    buildSignature: 'Unknown',
    installerStore: 'Unknown',
  );

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
  }

  Future<void> _loadImageSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      var quality = prefs.getString('imagequality') ?? 'medium';
      var repQuality = prefs.getInt('reportimagequality') ?? 100;
      reportImageQuality = reportQulityList.firstWhere(
        (element) => element == repQuality,
      );
      var count = prefs.getInt('imageCount') ?? 4;
      imageCount = imageCountList.firstWhere((element) => element == count);

      var compName = prefs.getString('companyName') ?? 'DeckInspectors';
      companyName = list.firstWhere((element) => element == compName);
      var appSync = prefs.getString('appSync') ?? 'true';
      isSyncOn = appSync == 'true';
      appSettings.currentQuality = ImageQuality.values.byName(quality);
      switch (quality) {
        case 'medium':
          isHighQuality = false;
          isLowQuality = false;
          isMediumQuality = true;
          break;
        case 'high':
          isHighQuality = true;
          isLowQuality = false;
          isMediumQuality = false;
          break;
        case 'low':
          isHighQuality = false;
          isLowQuality = true;
          isMediumQuality = false;
          break;

        default:
      }
    });

    ///var dayInString = describeEnum(Day.monday);
  }

  Future<void> savereportSettings() async {
    appSettings.companyName = companyName;
    appSettings.imageinRowCount = imageCount;
    appSettings.reportImageQuality = reportImageQuality;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('reportimagequality', reportImageQuality);
    await prefs.setString('companyName', companyName);
    await prefs.setInt('imageCount', imageCount);
  }

  Future<void> _applyImageSettings(String quality) async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      appSettings.currentQuality = ImageQuality.values.byName(quality);

      switch (quality) {
        case 'medium':
          isHighQuality = false;
          isLowQuality = false;
          isMediumQuality = true;
          break;
        case 'high':
          isHighQuality = true;
          isLowQuality = false;
          isMediumQuality = false;
          break;
        case 'low':
          isHighQuality = false;
          isLowQuality = true;
          isMediumQuality = false;
          break;

        default:
      }

      ///var dayInString = describeEnum(Day.monday);
    });
    await prefs.setString('imagequality', quality);
  }

  int reportImageQuality = 100;
  int imageCount = 4;
  String companyName = 'DeckInspectors';
  late CouchbaseServices couchbaseServices;
  bool isImageUploading = false;
  @override
  void initState() {
    super.initState();
    _initPackageInfo();
    couchbaseServices = Provider.of<CouchbaseServices>(context, listen: false);
    imageCount = imageCountList.first;
    companyName = list.first;
    reportImageQuality = reportQulityList.first;

    _loadImageSettings();
    // realmServices.addListener(() {
    //   isImageUploading = App.isImageUploading;
    // });
  }

  void setImageQuality(String quality) {
    _applyImageSettings(quality);
  }

  final _exportLogsKey = GlobalKey();

  Future<void> _exportLogs() async {
    final files = await AppLogger.instance.getLogFiles();
    if (files.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No log files found to export.')),
      );
      return;
    }

    await AppLogger.instance.info(
      'Settings',
      'User requested log export (${files.length} files)',
    );
    final xFiles = files.map((file) => XFile(file.path)).toList();
    final box = _exportLogsKey.currentContext?.findRenderObject() as RenderBox?;
    await Share.shareXFiles(
      xFiles,
      text: 'Deck Inspectors diagnostic logs',
      subject: 'Deck Inspectors Logs',
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(App.isImageUploading.toString());
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 20,
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'App Settings',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: Center(
        child: ListView(
          children: [
            Column(
              children: [
                const SizedBox(height: 4),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Image Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const Divider(
                  color: Color.fromARGB(255, 222, 213, 213),
                  height: 0,
                  thickness: 1,
                  indent: 2,
                  endIndent: 2,
                ),
                SizedBox(
                  height: 200,
                  child: ListView(
                    padding: const EdgeInsets.all(8),
                    children: <Widget>[
                      ListTile(
                        onTap: () => {setImageQuality('high')},
                        selected: isHighQuality,
                        leading:
                            isHighQuality
                                ? const Icon(Icons.check, color: Colors.blue)
                                : const SizedBox(width: 40),
                        title: const Text('High Quality'),
                      ),
                      ListTile(
                        onTap: () => {setImageQuality('medium')},
                        selected: isMediumQuality,
                        leading:
                            isMediumQuality
                                ? const Icon(Icons.check, color: Colors.blue)
                                : const SizedBox(width: 40),
                        title: const Text('Medium Quality'),
                      ),
                      ListTile(
                        onTap: () => {setImageQuality('low')},
                        selected: isLowQuality,
                        leading:
                            isLowQuality
                                ? const Icon(Icons.check, color: Colors.blue)
                                : const SizedBox(width: 40),
                        title: const Text('Low Quality'),
                      ),
                    ],
                  ),
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Sync Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const Divider(
                  color: Color.fromARGB(255, 222, 213, 213),
                  height: 0,
                  thickness: 1,
                  indent: 2,
                  endIndent: 2,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    const Text('Offline ', style: TextStyle(fontSize: 15)),
                    Switch(
                      onChanged: (value) {
                        toggleSwitch(value);
                      },
                      value: isSyncOn,
                    ),
                    const Text('Online', style: TextStyle(fontSize: 15)),
                  ],
                ),
                Visibility(
                  visible: App.isImageUploading,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.orange,
                      color: Colors.blue,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide.none,
                    minimumSize: const Size.fromHeight(40),
                    backgroundColor: Colors.white,
                    shadowColor: Colors.blue,
                    elevation: 0,
                  ),
                  key: _exportLogsKey,
                  onPressed: _exportLogs,
                  icon: const Icon(Icons.upload_file, color: Colors.blue),
                  label: const Text(
                    'Export Logs',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),

                // OutlinedButton.icon(
                //     style: OutlinedButton.styleFrom(
                //         side: BorderSide.none,
                //         // the height is 50, the width is full
                //         minimumSize: const Size.fromHeight(40),
                //         backgroundColor: Colors.white,
                //         shadowColor: Colors.blue,
                //         elevation: 0),
                //     onPressed: () {
                //       forceSync(context, realmServices);
                //     },
                //     icon: const Icon(
                //       Icons.sync_alt_rounded,
                //       color: Colors.blue,
                //     ),
                //     label: const Text(
                //       'Force Sync',
                //       style: TextStyle(color: Colors.blue),
                //     )),
                const SizedBox(height: 30),
                const Divider(
                  color: Color.fromARGB(255, 222, 213, 213),
                  height: 0,
                  thickness: 1,
                  indent: 2,
                  endIndent: 2,
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide.none,
                    // the height is 50, the width is full
                    minimumSize: const Size.fromHeight(40),
                    backgroundColor: Colors.white,
                    shadowColor: Colors.orange,
                    elevation: 0,
                  ),
                  onPressed: () async {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                    );

                    var result = await usersBloc.logout(
                      usersBloc.userDetails.username as String,
                    );
                    if (result) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Logged out successfully'),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to clear the user session.'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.logout_outlined, color: Colors.blue),
                  label: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.orange),
                  ),
                ),

                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide.none,
                    minimumSize: const Size.fromHeight(40),
                    backgroundColor: Colors.white,
                    shadowColor: Colors.orange,
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder:
                          (ctx) => AlertDialog(
                            title: const Text('Reset & Re-sync'),
                            content: const Text(
                              'This will delete all local data and re-download everything from the server. Use this if recently migrated data is not appearing.\n\nContinue?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text(
                                  'Reset',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                    );
                    if (confirm == true) {
                      await ReplicatorProvider.stopActiveReplicator();
                      await DatabaseProvider().deleteAndResetDatabase();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
                          ),
                          (route) => false,
                        );
                      }
                    }
                  },
                  icon: const Icon(
                    Icons.sync_problem_outlined,
                    color: Colors.red,
                  ),
                  label: const Text(
                    'Reset & Re-sync',
                    style: TextStyle(color: Colors.red),
                  ),
                ),

                const SizedBox(height: 30),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'App Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const Divider(
                  color: Color.fromARGB(255, 222, 213, 213),
                  height: 0,
                  thickness: 1,
                  indent: 2,
                  endIndent: 2,
                ),
                _infoTile('App name', _packageInfo.appName),
                _infoTile('Package name', _packageInfo.packageName),
                _infoTile('App version', _packageInfo.version),
                _infoTile('Build number', _packageInfo.buildNumber),
                _infoTile('Build signature', _packageInfo.buildSignature),
                _infoTile('Created On', '18th May 24'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(String title, String subtitle) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle.isEmpty ? 'Not set' : subtitle),
    );
  }

  List<String> list = <String>['DeckInspectors', 'Wicr'];
  List<int> reportQulityList = <int>[100, 50, 25];
  List<int> imageCountList = <int>[4, 3, 5];

  bool isSyncOn = true;
  void toggleSwitch(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final nextSyncOn = !isSyncOn;

    setState(() {
      isSyncOn = nextSyncOn;
      couchbaseServices.toggleOnlineState(nextSyncOn);
    });

    appSettings.isAppOfflineMode = !nextSyncOn;
    DatabaseProvider.offlineModeOn = !nextSyncOn;
    await AppLogger.instance.info(
      'SyncMode',
      'switch toggled -> ${nextSyncOn ? 'ONLINE MODE' : 'OFFLINE MODE'} '
          '(activeConnection=${appSettings.activeConnection}, appOfflineMode=${appSettings.isAppOfflineMode})',
    );

    if (!nextSyncOn) {
      await AppLogger.instance.info(
        'SyncMode',
        'OFFLINE MODE enabled -> requesting replicator stop',
      );
      await ReplicatorProvider.stopActiveReplicator();
      await AppLogger.instance.info(
        'SyncMode',
        'OFFLINE MODE enabled -> replicator stop request completed',
      );
    } else {
      await appSettings.refreshConnectivity();
      await AppLogger.instance.info(
        'SyncMode',
        'ONLINE MODE enabled -> attempting resume '
            '(activeConnection=${appSettings.activeConnection}, appOfflineMode=${appSettings.isAppOfflineMode})',
      );
      await ReplicatorProvider.resumeActiveReplicatorIfAllowed();
    }

    await prefs.setString('appSync', isSyncOn.toString());
  }
}
