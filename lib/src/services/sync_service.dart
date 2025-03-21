import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
//import 'package:http/http.dart' as http;
import 'package:realm/realm.dart';
import 'package:socket_io_client/socket_io_client.dart';

import '../models/realm/realm_schemas.dart';
import 'realm_local_services.dart';

class SyncService {
  final RealmLocalServices realmServices;
  late Socket socket;
  SyncService(this.realmServices);

  void initSocket() {
    debugPrint("Initializing WebSocket connection...");

    try {
      socket = io(
        'http://localhost:3000',
        OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .build(),
      );

      socket.onConnect((_) {
        debugPrint("Connected to WebSocket Server");
        syncUnsyncedData(); // Sync unsynced data when connected
      });

      socket.on("projectUpdated", (data) {
        updateLocalRealm(data);
      });

      socket.onConnectError((error) {
        debugPrint("Connect Error: $error");
      });
      socket.onDisconnect((_) => debugPrint("Disconnected from WebSocket"));
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  void sendUpdate(Map<String, dynamic> project) {
    socket.emit("updateProject", project);
    markAsSynced(project['id']);
  }

  //downlaod data from server
  void updateLocalRealm(dynamic data) {
    final project = realmServices.realm.write(() {
      return realmServices.realm.add<Project>(
        Project(
          ObjectId.fromHexString(data['_id']),
          data['companyIdentifier'],
          name: data['name'],
          projecttype: data['projecttype'],
          description: data['description'],
          address: data['address'],
          createdby: data['createdby'],
          createdat: data['createdat'],
          url: data['url'],
          editedat: data['editedat'],
          lasteditedby: data['lasteditedby'],
          assignedto: Set<String>.from(data['assignedto']),
          children: [], // Parse children if needed
          sections: [], // Parse sections if needed
          latitude: data['latitude'],
          longitude: data['longitude'],
          formId: ObjectId.fromHexString(data['formId']),
          isSynced: true,
        ),
        update: true,
      );
    });

    debugPrint("Updated Realm with new data: ${project.name}");
  }

  void markAsSynced(ObjectId id) {
    realmServices.realm.write(() {
      final project = realmServices.realm.find<Project>(id);
      if (project != null) {
        project.isSynced = true;
      }
    });
  }

  void syncUnsyncedData() {
    final unsyncedProjects =
        realmServices.realm.all<Project>().where((p) => !p.isSynced).toList();

    for (var project in unsyncedProjects) {
      sendUpdate({
        "id": project.id.hexString,
        "name": project.name,
        "editedat": project.editedat,
        "isSynced": true,
      });
    }
  }

  void connect() {
    socket.connect();
  }

  void disconnect() {
    socket.disconnect();
  }

  Future<void> syncData() async {
    final syncData = realmServices.getUnsyncedData();

    if (syncData.projects.isEmpty &&
        syncData.subProjects.isEmpty &&
        syncData.locations.isEmpty &&
        syncData.visualSections.isEmpty &&
        syncData.invasiveSections.isEmpty &&
        syncData.conclusiveSections.isEmpty &&
        syncData.deckImages.isEmpty &&
        syncData.dynamicVisualSections.isEmpty &&
        syncData.locationForms.isEmpty) {
      return;
    }
  }

  void startSync() {
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      if (results.isNotEmpty &&
          results.any((result) => result != ConnectivityResult.none)) {
        syncData();
      }
    });
  }
}
