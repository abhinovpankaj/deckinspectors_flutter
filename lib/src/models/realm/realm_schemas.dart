import 'package:realm/realm.dart';
part 'realm_schemas.g.dart';

@RealmModel()
class _Project {
  @MapTo('_id')
  @PrimaryKey()
  late ObjectId id;

  late String? name;
  late String? projecttype;
  late String? description;
  late String? address;
  late String? createdby;
  late String? createdat;
  late String? url;
  late String? editedat;
  String? lasteditedby;
  late Set<String> assignedto;
  List<_Child> children = [];
  bool iscomplete = false;
  // List<_Child> invasiveChildren = [];
  bool isInvasive = false;
  List<_Section> sections = [];
  // List<_Section> invasiveSections = [];
}

@RealmModel(ObjectType.embeddedObject)
class _Child {
  @MapTo('_id')
  late ObjectId id;
  late String? name;
  late String? type;
  late String? description;
  late String? url;
  late bool isInvasive;
  String? sequenceNo;
}

@RealmModel()
class _SubProject {
  @PrimaryKey()
  @MapTo('_id')
  late ObjectId id;
  String? name;
  String? type;
  String? description;
  late ObjectId parentid;
  String? parenttype;
  String? createdby;
  String? createdat;
  String? url;
  late Set<String> assignedto;
  String? editedat;
  String? lasteditedby;
  late bool isInvasive;
  List<_Child> children = [];
  //List<_Child> invasiveChildren = [];
}

@RealmModel()
class _Location {
  @PrimaryKey()
  @MapTo('_id')
  late ObjectId id;

  String? name;
  String? type;
  String? description;
  late ObjectId parentid;
  String? parenttype;
  String? createdby;
  String? createdat;
  String? url;
  String? editedat;
  String? lasteditedby;
  late bool isInvasive;
  List<_Section> sections = [];
  // List<_Section> invasiveSections = [];
}

@RealmModel(ObjectType.embeddedObject)
class _Section {
  @MapTo('_id')
  late ObjectId id;
  late String? name;
  late bool isInvasive;
  bool visualsignsofleak = false;
  bool furtherinvasivereviewrequired = false;
  String? conditionalassessment;
  String? visualreview;
  String? coverUrl;
  int count = 0;
  //@Ignored()
  bool isuploading = false;
  String? sequenceNo;
}

@RealmModel()
class _VisualSection {
  @PrimaryKey()
  @MapTo('_id')
  late ObjectId id;
  String? name;
  late List<String> images;
  late List<String> exteriorelements;
  late List<String> waterproofingelements;
  String? additionalconsiderations;
  String? visualreview;
  bool visualsignsofleak = false;
  bool furtherinvasivereviewrequired = true;
  String? conditionalassessment;
  late String eee;
  late String lbc;
  late String awe;
  late ObjectId parentid;
  String? createdby;
  String? createdat;
  String parenttype = '';
  late bool unitUnavailable;
  // InvasiveSection? invasiveSection;
  // ConclusiveSection? conclusiveSection;
  String? editedat;
  String? lasteditedby;
}

@RealmModel()
class _InvasiveSection {
  @PrimaryKey()
  @MapTo('_id')
  late ObjectId id;
  late ObjectId parentid; //visualsectionid
  bool postinvasiverepairsrequired = false;
  late String invasiveDescription;
  late List<String> invasiveimages;
}

@RealmModel()
class _ConclusiveSection {
  @PrimaryKey()
  @MapTo('_id')
  late ObjectId id;
  late ObjectId parentid; //visualsectionid
  bool propowneragreed = false;
  bool invasiverepairsinspectedandcompleted = false;
  late String conclusiveconsiderations;
  late String eeeconclusive;
  late String lbcconclusive;
  late String aweconclusive;
  late List<String> conclusiveimages;
}

@RealmModel()
class _DeckImage {
  @PrimaryKey()
  @MapTo('_id')
  late ObjectId id;
  late String imageLocalPath;
  late String onlinePath;
  late bool isUploaded;
  late ObjectId parentId;
  late String parentType;
  late String entityName;
  late String containerName;
  late String uploadedBy;
}
