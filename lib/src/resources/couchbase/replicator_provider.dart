import 'dart:async';

import 'package:cbl/cbl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../bloc/users_bloc.dart';
import 'database_provider.dart';

class ReplicatorProvider {
  ReplicatorProvider({required this.databaseProvider});

  final DatabaseProvider databaseProvider;

  Replicator? _replicator;
  ReplicatorConfiguration? _replicatorConfiguration;
  ListenerToken? statusChangedToken;
  ListenerToken? documentReplicationToken;

  //init - NOTE:  YOU MUST modify the replicator configuration prior to starting the replicator
  // or it will not function properly.
  Future<void> init() async {
    try {
      debugPrint('${DateTime.now()} [ReplicatorProvider] info: starting init.');
      var db = databaseProvider.e3inspectionsDatabase;
      var user = usersBloc.getCurrentUser();
      if (db != null && user != null) {
        // Load certificate for App Services
        var pem = await rootBundle.load('assets/syncinspectionsdata-qa.pem');
        //wss://kksvdl6h3dascsw.apps.cloud.couchbase.com:4984/syncinspectionsdata-qa
        // Replicator endpoint
        var url = Uri(
          scheme: 'wss',
          port: 4984,
          host: 'kksvdl6h3dascsw.apps.cloud.couchbase.com',
          path: 'syncinspectionsdata-qa',
        );
        var basicAuthenticator = BasicAuthenticator(
          username: 'p5nadmin', //user.username,
          password: 'Deck@123', //user.password,
        );
        var endPoint = UrlEndpoint(url);

        // Specify collections to replicate

        // Create ReplicatorConfiguration with required parameters
        final config = ReplicatorConfiguration(
          target: endPoint,
          authenticator: basicAuthenticator,
          continuous: true,
          replicatorType: ReplicatorType.pushAndPull,
          heartbeat: const Duration(seconds: 60),
          pinnedServerCertificate: pem.buffer.asUint8List(),
        );

        // Add each collection to the configuration
        final collectionNames = [
          'Project',
          'Location',
          'SubProject',
          'VisualSection',
          'ConclusiveSection',
          'InvasiveSection',
          'DynamicVisualSection',
        ];
        for (final name in collectionNames) {
          final collection = await db.collection(name, 'inventory-qa');
          if (collection != null) {
            config.addCollection(collection);
          }
        }

        _replicatorConfiguration = config;
        if (_replicatorConfiguration != null) {
          _replicator = await Replicator.createAsync(_replicatorConfiguration!);
        }
      }
    } catch (e) {
      debugPrint(
        '${DateTime.now()} [ReplicatorProvider] exception: starting init.${e.toString()}',
      );
    }
  }

  FutureOr<bool> companyFilter(Document doc, Set<DocumentFlag> flags) {
    if (flags.contains(DocumentFlag.deleted)) {
      return true;
    }
    if (doc.value('docType') == 'Project') {
      return doc.value('companyIdentifier') ==
              usersBloc.getCurrentUser()?.companyIdentifier &&
          doc.value('assignedto') != null &&
          (doc.value('assignedto') as List).contains(
            usersBloc.getCurrentUser()?.username,
          );
    }
    return doc.value('companyIdentifier') ==
        usersBloc.getCurrentUser()?.companyIdentifier;
  }

  // callbacks are used to get information on status of replication
  // and what documents are being replicated through the replicator
  Future<void> startReplicator({
    required Function(ReplicatorChange change)? onStatusChange,
    required Function(DocumentReplication document)? onDocument,
  }) async {
    debugPrint(
      '${DateTime.now()} [ReplicatorProvider] info: starting replicator.',
    );

    var replicator = _replicator;
    if (replicator != null) {
      statusChangedToken = await replicator.addChangeListener((change) {
        final status = change.status;
        debugPrint('[Replicator Status] Activity: \\${status.activity}');
        debugPrint(
          '[Replicator Status] Progress: \\${status.progress.completed} / \\${status.progress.progress}',
        );
        if (status.error != null) {
          debugPrint('[Replicator Status] Error: \\${status.error}');
        }
        if (onStatusChange != null) {
          onStatusChange(change);
        }
      });
      if (onDocument != null) {
        var function = onDocument;
        replicator.addDocumentReplicationListener(function);
      }
      await replicator.start();

      debugPrint(
        '${DateTime.now()} [ReplicatorProvider] info: started replicator.',
      );
    } else {
      debugPrint(
        '${DateTime.now()} [ReplicatorProvider] error: cannot start replicator, it is null.',
      );
    }
  }

  Future<void> stopReplicator() async {
    var replicator = _replicator;
    if (replicator != null) {
      debugPrint(
        '${DateTime.now()} [ReplicatorProvider] info: stopping replicator.',
      );

      //remove change listeners before stopping replicator, this should
      //automatically be done with stopping, but just to be safe
      await removeDocumentReplicationListener();
      await removeStatusChangeListener();

      await replicator.stop();

      //null out tokens so they can be reused
      statusChangedToken = null;
      documentReplicationToken = null;

      debugPrint(
        '${DateTime.now()} [ReplicatorProvider] info: stopped replicator.',
      );
    } else {
      debugPrint(
        '${DateTime.now()} [ReplicatorProvider] warning: tried to stop replicator but it was null.',
      );
    }
  }

  Future<void> removeStatusChangeListener() async {
    var replicator = _replicator;
    var token = statusChangedToken;
    if (replicator != null && replicator.isClosed && token != null) {
      replicator.removeChangeListener(token);
    } else {
      debugPrint(
        '${DateTime.now()} [ReplicatorProvider] warning: tried to remove statusChangeListener but something was null',
      );
    }
  }

  Future<void> removeDocumentReplicationListener() async {
    var replicator = _replicator;
    var token = documentReplicationToken;
    if (replicator != null && replicator.isClosed && token != null) {
      replicator.removeChangeListener(token);
    } else {
      debugPrint(
        '${DateTime.now()} [ReplicatorProvider] warning: tried to remove documentChangeListener but something was null',
      );
    }
  }
}
