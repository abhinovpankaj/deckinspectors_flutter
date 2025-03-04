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
  late String? companyIdentifier;
  String? lasteditedby;
  late Set<String> assignedto;
  List<_Child> children = [];
  bool iscomplete = false;
  bool isInvasive = false;
  List<_Section> sections = [];
  late double? latitude;
  late double? longitude;
  ObjectId? formId;
  bool isSynced = false;

  Map<String, dynamic> toJson() {
    return {
      'id': id.toString(),
      'name': name,
      'projecttype': projecttype,
      'description': description,
      'address': address,
      'createdby': createdby,
      'createdat': createdat,
      'url': url,
      'editedat': editedat,
      'companyIdentifier': companyIdentifier,
      'lasteditedby': lasteditedby,
      'assignedto': assignedto.toList(),
      'children': children.map((e) => e.toJson()).toList(),
      'iscomplete': iscomplete,
      'isInvasive': isInvasive,
      'sections': sections.map((e) => e.toJson()).toList(),
      'latitude': latitude,
      'longitude': longitude,
      'formId': formId?.toString(),
      'isSynced': isSynced,
    };
  }
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

  Map<String, dynamic> toJson() {
    return {
      'id': id.toString(),
      'name': name,
      'type': type,
      'description': description,
      'url': url,
      'isInvasive': isInvasive,
      'sequenceNo': sequenceNo,
    };
  }
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
  bool isSynced = false;

  Map<String, dynamic> toJson() {
    return {
      'id': id.toString(),
      'name': name,
      'type': type,
      'description': description,
      'parentid': parentid.toString(),
      'parenttype': parenttype,
      'createdby': createdby,
      'createdat': createdat,
      'url': url,
      'assignedto': assignedto.toList(),
      'editedat': editedat,
      'lasteditedby': lasteditedby,
      'isInvasive': isInvasive,
      'isSynced': isSynced,
      'children': children.map((e) => e.toJson()).toList(),
    };
  }
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
  bool isSynced = false;
  // List<_Section> invasiveSections = [];

  Map<String, dynamic> toJson() {
    return {
      'id': id.toString(),
      'name': name,
      'type': type,
      'description': description,
      'parentid': parentid.toString(),
      'parenttype': parenttype,
      'createdby': createdby,
      'createdat': createdat,
      'url': url,
      'editedat': editedat,
      'lasteditedby': lasteditedby,
      'isInvasive': isInvasive,
      'isSynced': isSynced,
      'sections': sections.map((e) => e.toJson()).toList(),
    };
  }
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
  //bool isSynced = false;

  Map<String, dynamic> toJson() {
    return {
      'id': id.toString(),
      'name': name,
      'isInvasive': isInvasive,
      'visualsignsofleak': visualsignsofleak,
      'furtherinvasivereviewrequired': furtherinvasivereviewrequired,
      'conditionalassessment': conditionalassessment,
      'visualreview': visualreview,
      'coverUrl': coverUrl,
      'count': count,
      'isuploading': isuploading,
      'sequenceNo': sequenceNo,
    };
  }
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
  bool isSynced = false;
  String parenttype = '';
  late bool unitUnavailable;
  // InvasiveSection? invasiveSection;
  // ConclusiveSection? conclusiveSection;
  String? editedat;
  String? lasteditedby;

  Map<String, dynamic> toJson() {
    return {
      'id': id.toString(),
      'name': name,
      'images': images,
      'exteriorelements': exteriorelements,
      'waterproofingelements': waterproofingelements,
      'additionalconsiderations': additionalconsiderations,
      'visualreview': visualreview,
      'visualsignsofleak': visualsignsofleak,
      'furtherinvasivereviewrequired': furtherinvasivereviewrequired,
      'conditionalassessment': conditionalassessment,
      'eee': eee,
      'lbc': lbc,
      'awe': awe,
      'isSynced': isSynced,
      'parentid': parentid.toString(),
      'createdby': createdby,
      'createdat': createdat,
      'parenttype': parenttype,
      'unitUnavailable': unitUnavailable,
      'editedat': editedat,
      'lasteditedby': lasteditedby,
    };
  }
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
  bool isSynced = false;
  Map<String, dynamic> toJson() {
    return {
      'id': id.toString(),
      'parentid': parentid.toString(),
      'postinvasiverepairsrequired': postinvasiverepairsrequired,
      'invasiveDescription': invasiveDescription,
      'invasiveimages': invasiveimages,
      'isSynced': isSynced,
    };
  }
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
  bool isSynced = false;
  Map<String, dynamic> toJson() {
    return {
      'id': id.toString(),
      'parentid': parentid.toString(),
      'propowneragreed': propowneragreed,
      'invasiverepairsinspectedandcompleted':
          invasiverepairsinspectedandcompleted,
      'conclusiveconsiderations': conclusiveconsiderations,
      'eeeconclusive': eeeconclusive,
      'lbcconclusive': lbcconclusive,
      'aweconclusive': aweconclusive,
      'conclusiveimages': conclusiveimages,
      'isSynced': isSynced,
    };
  }
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
  bool isSynced = false;

  Map<String, dynamic> toJson() {
    return {
      'id': id.toString(),
      'imageLocalPath': imageLocalPath,
      'onlinePath': onlinePath,
      'isUploaded': isUploaded,
      'parentId': parentId.toString(),
      'parentType': parentType,
      'entityName': entityName,
      'containerName': containerName,
      'uploadedBy': uploadedBy,
      'isSynced': isSynced,
    };
  }
}

@RealmModel(ObjectType.embeddedObject)
class _Question {
  @MapTo('_id')
  late ObjectId id;
  late String type;
  late String name;
  late String answer;
  late List<String> multipleAnswers;
  late List<String> allowedValues;
  bool isMandatory = false;

  Map<String, dynamic> toJson() {
    return {
      'id': id.toString(),
      'type': type,
      'name': name,
      'answer': answer,
      'multipleAnswers': multipleAnswers,
      'allowedValues': allowedValues,
      'isMandatory': isMandatory,
    };
  }
}

@RealmModel()
class _DynamicVisualSection {
  @PrimaryKey()
  @MapTo('_id')
  late ObjectId id;
  late String? companyIdentifier;
  String? name;
  late List<String> images;
  late List<_Question> questions;
  bool furtherinvasivereviewrequired = true;
  late ObjectId parentid;
  String? createdby;
  String? createdat;
  String parenttype = '';
  late bool unitUnavailable;
  String? editedat;
  String? lasteditedby;
  String? additionalconsiderations;
  bool isSynced = false;

  Map<String, dynamic> toJson() {
    return {
      'id': id.toString(),
      'companyIdentifier': companyIdentifier,
      'name': name,
      'images': images,
      'isSynced': isSynced,
      'questions': questions.map((e) => e.toJson()).toList(),
      'furtherinvasivereviewrequired': furtherinvasivereviewrequired,
      'parentid': parentid.toString(),
      'createdby': createdby,
      'createdat': createdat,
      'parenttype': parenttype,
      'unitUnavailable': unitUnavailable,
      'editedat': editedat,
      'lasteditedby': lasteditedby,
      'additionalconsiderations': additionalconsiderations,
    };
  }
}

@RealmModel()
class _LocationForm {
  @PrimaryKey()
  @MapTo('_id')
  late ObjectId id;
  late String name;
  late String companyIdentifier;
  late List<_Question> questions;
  bool isSynced = false;
  Map<String, dynamic> toJson() {
    return {
      'id': id.toString(),
      'name': name,
      'isSynced': isSynced,
      'companyIdentifier': companyIdentifier,
      'questions': questions.map((e) => e.toJson()).toList(),
    };
  }
}
