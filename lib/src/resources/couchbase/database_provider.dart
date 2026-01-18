import 'dart:io';
import 'dart:async';
import 'package:E3InspectionsMultiTenant/src/models/users_response.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cbl_flutter/cbl_flutter.dart';
import 'package:cbl/cbl.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseProvider {
  // Singleton instance
  static final DatabaseProvider _instance = DatabaseProvider._internal();

  /// Returns the shared DatabaseProvider instance.
  factory DatabaseProvider() => _instance;

  DatabaseProvider._internal();

  //database information
  final String defaultInspectionDatabaseName = 'e3inspections';
  String currentInspectionDatabaseName = 'e3inspections';

  //index names
  final String documentTypeIndexName = 'idxDocumentType';
  final String documentTypeAttributeName = 'documentType';
  final String companyIndexName = 'idxCompany';
  final String companyAttributeName = 'company';
  final String projectIdAttributeName = 'projectId';

  static bool offlineModeOn = false;
  //directory and file information
  String cblPreBuiltDatabasePath = "";
  String databaseFileName = "db.sqlite3";
  late Directory cblLogsDirectory;
  late Directory cblDatabaseDirectory;

  late Collection subProjectCollection;
  late Collection projectCollection;
  late Collection locationCollection;
  late Collection deckImageCollection;
  late Collection visualSectionCollection;
  late Collection invasiveSectionCollection;
  late Collection dynamicSectionCollection;
  late Collection conclusiveSectionCollection;
  late Collection formCollection;

  //database pointers
  AsyncDatabase? e3inspectionsDatabase;
  //AsyncDatabase? warehouseDatabase;

  bool isInitialized = false;
  bool isReplicatorStarted = false;

  Future<void> initialize() async {
    //init Couchbase Lite for use with databases
    try {
      if (!isInitialized) {
        isInitialized = true;
        await Future.wait([
          setupFileSystem(),
          CouchbaseLiteFlutter.init(),
        ]);
        _setupCouchbaseLogging();
      }
      final prefs = await SharedPreferences.getInstance();
      offlineModeOn = prefs.getString('appSync') == 'false';
    } catch (e) {
      debugPrint('Error initializing database provider: $e');
    }
  }

  String getInventoryDatabasePath() =>
      '${cblDatabaseDirectory.path}/$currentInspectionDatabaseName';

  /* setupFileSystem - used to calculate the path to save database and log files on the device */
  Future<void> setupFileSystem() async {
    final databaseDirectory = await getApplicationDocumentsDirectory();
    final logsDirectory = await getApplicationDocumentsDirectory();
    cblDatabaseDirectory = Directory('${databaseDirectory.path}/databases');
    if (!cblDatabaseDirectory.existsSync()) {
      cblDatabaseDirectory.createSync(recursive: true);
    }
    cblLogsDirectory = Directory('${logsDirectory.path}/logs/cbl');
    if (!cblLogsDirectory.existsSync()) {
      cblLogsDirectory.createSync(recursive: true);
    }
    cblPreBuiltDatabasePath =
        "${cblDatabaseDirectory.path}/$defaultInspectionDatabaseName.cblite2";
    debugPrint(
        '${DateTime.now()} [DatabaseProvider] info: database directory: ${cblDatabaseDirectory.path}');
  }

  //setup and open the database file(s)
  Future<void> initDatabases({required User user}) async {
    try {
      debugPrint(
          '${DateTime.now()} [DatabaseProvider] info: initializing databases');

      final dbConfig =
          DatabaseConfiguration(directory: cblDatabaseDirectory.path);

      //calculate database name based on current logged in users team name
      final companyName = user.companyIdentifier?.toLowerCase().trim();
      currentInspectionDatabaseName =
          "${companyName}_$defaultInspectionDatabaseName";

      /* create or open a database to share between team members to store
      projects, assets, and user profiles */
      e3inspectionsDatabase =
          await Database.openAsync(currentInspectionDatabaseName, dbConfig);
      // initialize collections (create if missing)
      projectCollection = await _getOrCreateCollection('projects');
      subProjectCollection = await _getOrCreateCollection('subProjects');
      locationCollection = await _getOrCreateCollection('locations');
      deckImageCollection = await _getOrCreateCollection('deckImages');
      visualSectionCollection = await _getOrCreateCollection('visualSections');
      formCollection = await _getOrCreateCollection('forms');
      invasiveSectionCollection =
          await _getOrCreateCollection('invasiveSections');
      dynamicSectionCollection =
          await _getOrCreateCollection('dynamicSections');
      conclusiveSectionCollection =
          await _getOrCreateCollection('conclusiveSections');
      //create indexes for queries
      await _createDocumentTypeIndex();
      await _createCompanyDocumentTypeIndex();

      debugPrint(
          '${DateTime.now()} [DatabaseProvider] info: databases initialized');
    } catch (e) {
      debugPrint('${DateTime.now()} [DatabaseProvider] error: ${e.toString()}');
    }
  }

  /// Initialize databases at app startup when no user is logged in yet.
  /// Opens a default inspection database without company prefix so the
  /// app can use Couchbase Lite early. This does not depend on a User.
  Future<void> initDatabasesForAppStartup() async {
    try {
      if (e3inspectionsDatabase != null) return;
      final dbConfig =
          DatabaseConfiguration(directory: cblDatabaseDirectory.path);
      e3inspectionsDatabase =
          await Database.openAsync(defaultInspectionDatabaseName, dbConfig);

      projectCollection = await _getOrCreateCollection('projects');
      subProjectCollection = await _getOrCreateCollection('subProjects');
      locationCollection = await _getOrCreateCollection('locations');
      deckImageCollection = await _getOrCreateCollection('deckImages');
      visualSectionCollection = await _getOrCreateCollection('visualSections');
      formCollection = await _getOrCreateCollection('forms');
      invasiveSectionCollection =
          await _getOrCreateCollection('invasiveSections');
      dynamicSectionCollection =
          await _getOrCreateCollection('dynamicSections');
      conclusiveSectionCollection =
          await _getOrCreateCollection('conclusiveSections');

      await _createDocumentTypeIndex();
      await _createCompanyDocumentTypeIndex();
      debugPrint(
          '${DateTime.now()} [DatabaseProvider] info: startup databases initialized');
    } catch (e) {
      debugPrint(
          '${DateTime.now()} [DatabaseProvider] error initializing startup DB: ${e.toString()}');
    }
  }

  /* _unzipPrebuiltDatabase - unzip the prebuilt database included in the asset/database folder to the application database directory */
  // Future<void> _unzipPrebuiltDatabase() async {
  //   //get the prebuild database zip file back from asset folder
  //   var pbdbWarehousesZip = await rootBundle.load(assetsDatabaseFileName);

  //   if (pbdbWarehousesZip.lengthInBytes > 0) {
  //     //decompress the zip file into a bytes and then convert into a List which is required by the Archive framework
  //     final archive =
  //         ZipDecoder().decodeBytes(pbdbWarehousesZip.buffer.asUint8List());

  //     //loop through directory and files in the zip file and create them
  //     for (final file in archive) {
  //       final fileName = file.name;
  //       if (file.isFile) {
  //         final fileData = file.content as List<int>;
  //         File('${cblDatabaseDirectory.path}/$fileName')
  //           ..createSync(recursive: true)
  //           ..writeAsBytesSync(fileData);
  //       } else {
  //         Directory(cblDatabaseDirectory.path).createSync(recursive: true);
  //       }
  //     }
  //   }
  // }

  /* closeDatabases - close the databases */
  Future<void> closeDatabases() async {
    try {
      debugPrint(
          '${DateTime.now()} [DatabaseProvider] info: closing databases');

      if (e3inspectionsDatabase != null) {
        await e3inspectionsDatabase?.close();
      }
      debugPrint('${DateTime.now()} [DatabaseProvider] info: databases closed');
    } catch (e) {
      debugPrint(
          '${DateTime.now()} [DatabaseProvider] error: trying to close databases ${e.toString()}');
    }
    e3inspectionsDatabase = null;
  }

  Future<void> _createDocumentTypeIndex() async {
    final expression = Expression.property(documentTypeAttributeName);
    final valueIndexItems = {ValueIndexItem.expression(expression)};
    final index = IndexBuilder.valueIndex(valueIndexItems);

    var e3inspectionsDb = e3inspectionsDatabase;
    if (e3inspectionsDb != null) {
      final indexes = await e3inspectionsDb.indexes;
      if (!(indexes.contains(documentTypeIndexName))) {
        await e3inspectionsDb.createIndex(documentTypeIndexName, index);
      }
    }
  }

  Future<void> _createCompanyDocumentTypeIndex() async {
    final documentTypeExpression =
        Expression.property(documentTypeAttributeName); //<1>
    final companyExpression = Expression.property(companyAttributeName); //<2>
    final valueIndexItems = {
      ValueIndexItem.expression(documentTypeExpression),
      ValueIndexItem.expression(companyExpression)
    }; //<3>
    final index = IndexBuilder.valueIndex(valueIndexItems); //<4>
    var e3inspectionsDb = e3inspectionsDatabase; //<5>
    if (e3inspectionsDb != null) {
      //<6>
      final indexes = await e3inspectionsDb.indexes; //<7>
      if (!(indexes.contains(companyIndexName))) {
        //<8>
        await e3inspectionsDb.createIndex(companyIndexName, index); //<9>
      }
    }
  }

  /* _setupCouchbaseLogging - For Flutter apps `Database.log.custom` is setup with a logger, which logs to `print`, but only at log level `warning`. */
  void _setupCouchbaseLogging() {
    // Use for dev builds only. Guard against null handlers on some
    // platform implementations to avoid runtime exceptions.
    try {
      final dbLog = Database.log;
      // Set verbose level if available
      try {
        if (dbLog.custom != null) {
          dbLog.custom!.level = LogLevel.verbose;
        }
      } catch (_) {
        // ignore if underlying implementation doesn't support custom/file logs
      }

      // Configure file logging if available
      try {
        if (dbLog.file != null) {
          dbLog.file.config = LogFileConfiguration(
              directory: cblLogsDirectory.path, usePlainText: true);
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('Error configuring Couchbase logging: $e');
    }
  }

  bool isAppOfflineMode() {
    return offlineModeOn;
  }
}

// Helper extension methods below
extension on DatabaseProvider {
  Future<Collection> _getOrCreateCollection(String name) async {
    try {
      // Try to get existing collection
      final existing = await e3inspectionsDatabase?.collection(name);
      if (existing != null) return existing;

      // If not present, attempt to create it
      try {
        // Some platform implementations expose `createCollection`.
        // Use no-scope collection creation if available.
        final createMethod = e3inspectionsDatabase?.createCollection;
        if (createMethod != null) {
          // ignore: invalid_use_of_protected_member
          await e3inspectionsDatabase?.createCollection(name);
        } else {
          // Fallback: call collection access again (may auto-create on some platforms)
        }
      } catch (e) {
        debugPrint('Could not call createCollection for $name: $e');
      }

      // Try to read it again
      final created = await e3inspectionsDatabase?.collection(name);
      if (created != null) return created;

      // As a last resort throw an informative error
      throw StateError('Failed to obtain or create collection: $name');
    } catch (e) {
      debugPrint('Error getting/creating collection $name: $e');
      rethrow;
    }
  }
}
