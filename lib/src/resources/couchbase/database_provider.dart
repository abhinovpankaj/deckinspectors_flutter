import 'dart:io';
import 'dart:async';
import 'package:E3InspectionsMultiTenant/src/models/users_response.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cbl_flutter/cbl_flutter.dart';
import 'package:cbl/cbl.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseProvider {
  DatabaseProvider();

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
  }

  //setup and open the database file(s)
  Future<void> initDatabases({required User user}) async {
    try {
      debugPrint(
          '${DateTime.now()} [DatabaseProvider] info: initializing databases');

      final dbConfig =
          DatabaseConfiguration(directory: cblDatabaseDirectory.path);

      // create the warehouse database if it doesn't already exist
      // if (!File("$cblPreBuiltDatabasePath/$databaseFileName").existsSync()) {
      //   await _unzipPrebuiltDatabase();
      //   await _copyWarehouseDatabase();
      // }
      // //open the warehouse database
      // warehouseDatabase =
      //     await Database.openAsync(warehouseDatabaseName, dbConfig);

      //calculate database name based on current logged in users team name
      final companyName = user.companyIdentifier?.toLowerCase().trim();
      currentInspectionDatabaseName =
          "${companyName}_$defaultInspectionDatabaseName";

      /* create or open a database to share between team members to store
      projects, assets, and user profiles */
      e3inspectionsDatabase =
          await Database.openAsync(currentInspectionDatabaseName, dbConfig);
      //initialize collections

      projectCollection =
          (await e3inspectionsDatabase?.collection('projects'))!;
      subProjectCollection =
          (await e3inspectionsDatabase?.collection('subProjects'))!;
      locationCollection =
          (await e3inspectionsDatabase?.collection('locations'))!;
      deckImageCollection =
          (await e3inspectionsDatabase?.collection('deckImages'))!;
      visualSectionCollection =
          (await e3inspectionsDatabase?.collection('visualSections'))!;
      formCollection = (await e3inspectionsDatabase?.collection('forms'))!;

      invasiveSectionCollection =
          (await e3inspectionsDatabase?.collection('invasiveSections'))!;
      dynamicSectionCollection =
          (await e3inspectionsDatabase?.collection('dynamicSections'))!;
      conclusiveSectionCollection =
          (await e3inspectionsDatabase?.collection('conclusiveSections'))!;
      //create indexes for queries
      await _createDocumentTypeIndex();
      await _createCompanyDocumentTypeIndex();

      debugPrint(
          '${DateTime.now()} [DatabaseProvider] info: databases initialized');
    } catch (e) {
      debugPrint('${DateTime.now()} [DatabaseProvider] error: ${e.toString()}');
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
    //use for dev builds only!!
    Database.log.custom!.level = LogLevel.verbose;
    Database.log.file.config = LogFileConfiguration(
        directory: cblLogsDirectory.path, usePlainText: true);
  }

  bool isAppOfflineMode() {
    return offlineModeOn;
  }
}
