// Base document class with common fields
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

abstract class CouchbaseDocument {
  String? id;
  String get docType;

  Map<String, dynamic> toDocument();

  static String generateId() {
    var uuid = Uuid();
    return uuid.v4();
    //return '${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecond % 1000)}';
  }
}

// Project Document
class Project extends CouchbaseDocument {
  String? name;
  String? projecttype;
  String? description;
  String? address;
  String? createdby;
  String? createdat;
  String? url;
  String? editedat;
  String? companyIdentifier;
  String? lasteditedby;
  bool iscomplete = false;
  bool isInvasive = false;
  List<String> assignedto = [];
  List<Child> children = [];
  List<Section> sections = [];
  double latitude = 0.0;
  double longitude = 0.0;
  String? formId;

  Project({
    this.name,
    this.projecttype,
    this.description,
    this.address,
    this.createdby,
    this.createdat,
    this.url,
    this.editedat,
    this.companyIdentifier,
    this.lasteditedby,
    this.iscomplete = false,
    List<String>? assignedto,
    List<Child>? children,
    List<Section>? sections,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.formId,
    required bool isInvasive,
  }) : assignedto = assignedto ?? [],
       children = children ?? [],
       sections = sections ?? [];

  @override
  String get docType => 'Project';
  @override
  Map<String, dynamic> toDocument() => {
    'documentType': 'project',
    'type': 'Project',
    'name': name,
    'projecttype': projecttype,
    'description': description,
    'address': address,
    'createdby': createdby,
    'createdat': createdat,
    'url': url,
    'isInvasive': isInvasive,
    'editedat': editedat,
    'companyIdentifier': companyIdentifier,
    'lasteditedby': lasteditedby,
    'iscomplete': iscomplete,
    'assignedto': assignedto,
    'children': children.map((c) => c.toMap()).toList(),
    'sections': sections.map((s) => s.toMap()).toList(),
    'latitude': latitude,
    'longitude': longitude,
    'formId': formId,
  };

  factory Project.fromDocument(Map<String, dynamic> doc, {String? id}) {
    final project = Project(
      name: doc['name'],
      projecttype: doc['projecttype'],
      description: doc['description'],
      address: doc['address'],
      createdby: doc['createdby'],
      createdat: doc['createdat'],
      url: doc['url'],
      editedat: doc['editedat'],
      companyIdentifier: doc['companyIdentifier'],
      lasteditedby: doc['lasteditedby'],
      iscomplete: doc['iscomplete'] ?? false,
      assignedto: List<String>.from(doc['assignedto'] ?? []),
      children:
          (doc['children'] as List<dynamic>?)
              ?.map((c) => Child.fromMap(c as Map<String, dynamic>))
              .toList() ??
          [],
      sections:
          (doc['sections'] as List<dynamic>?)
              ?.map((s) => Section.fromMap(s as Map<String, dynamic>))
              .toList() ??
          [],
      latitude: (doc['latitude'] ?? 0.0).toDouble(),
      longitude: (doc['longitude'] ?? 0.0).toDouble(),
      formId: doc['formId'],
      isInvasive: doc['isInvasive'] ?? false,
    );
    if (id != null) project.id = id;
    return project;
  }

  // no id on model level; repositories supply document ids
}

// Sub Project Document
class SubProject extends CouchbaseDocument {
  String? name;
  String? description;
  String parentid;
  String? createdby;
  String? createdat;
  String? editedat;
  String? lasteditedby;
  String? url;
  String type;
  bool isInvasive;
  List<String> assignedto = [];
  List<Child> children = [];

  SubProject({
    this.name,
    this.description,
    required this.parentid,
    this.createdby,
    this.createdat,
    this.editedat,
    this.lasteditedby,
    this.url,
    this.type = '',
    List<String>? assignedto,
    List<Child>? children,
    required this.isInvasive,
  }) : assignedto = assignedto ?? [],
       children = children ?? [];

  @override
  String get docType => 'SubProject';
  @override
  Map<String, dynamic> toDocument() => {
    'docType': 'SubProject',
    'name': name,
    'url': url,
    'description': description,
    'parentid': parentid,
    'createdby': createdby,
    'createdat': createdat,
    'editedat': editedat,
    'lasteditedby': lasteditedby,
    'assignedto': assignedto,
    'type': type,
    'isInvasive': isInvasive,
    'children': children.map((c) => c.toMap()).toList(),
  };

  factory SubProject.fromDocument(Map<String, dynamic> doc, {String? id}) {
    var subProject = SubProject(
      name: doc['name'],
      description: doc['description'],
      parentid: doc['parentid'],
      createdby: doc['createdby'],
      createdat: doc['createdat'],
      url: doc['url'],
      type: doc['type'],
      editedat: doc['editedat'],
      lasteditedby: doc['lasteditedby'],
      assignedto: List<String>.from(doc['assignedto'] ?? []),
      children:
          (doc['children'] as List<dynamic>?)
              ?.map((c) => Child.fromMap(c as Map<String, dynamic>))
              .toList() ??
          [],
      isInvasive: doc['isInvasive'] ?? false,
    );
    if (id != null) subProject.id = id;
    return subProject;
  }
}

// Location Document
class Location extends CouchbaseDocument {
  String parenttype;
  String? name;
  String? type;
  String? description;
  String? createdby;
  String? createdat;
  String? url;
  String? editedat;
  String? lasteditedby;
  String parentid;
  bool isInvasive = false;
  List<Section> sections = [];

  Location({
    this.parenttype = '',
    this.name,
    this.type,
    this.description,
    this.createdby,
    this.createdat,
    this.url,
    this.editedat,
    this.lasteditedby,
    required this.parentid,
    this.isInvasive = false,
    List<Section>? sections,
  }) : sections = sections ?? [];

  @override
  String get docType => 'Location';
  @override
  Map<String, dynamic> toDocument() => {
    'docType': 'Location',
    'parenttype': parenttype,
    'name': name,
    'type': type,
    'description': description,
    'createdby': createdby,
    'createdat': createdat,
    'url': url,
    'editedat': editedat,
    'lasteditedby': lasteditedby,
    'parentid': parentid,
    'isInvasive': isInvasive,
    'sections': sections.map((s) => s.toMap()).toList(),
  };

  factory Location.fromDocument(Map<String, dynamic> doc, {String? id}) {
    var location = Location(
      name: doc['name'],
      type: doc['type'],
      description: doc['description'],
      createdby: doc['createdby'],
      createdat: doc['createdat'],
      parenttype: doc['parenttype'] ?? '',
      url: doc['url'],
      editedat: doc['editedat'],
      lasteditedby: doc['lasteditedby'] ?? '',
      parentid: doc['parentid'],
      isInvasive: doc['isInvasive'] ?? false,
      sections:
          (doc['sections'] as List<dynamic>?)
              ?.map((s) => Section.fromMap(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
    if (id != null) location.id = id;
    return location;
  }
}

// Visual Section Document
class VisualSection extends CouchbaseDocument {
  String? name;
  List<String> images = [];
  List<String> exteriorelements = [];
  List<String> waterproofingelements = [];
  String? additionalconsiderations;
  String? visualreview;
  bool visualsignsofleak = false;
  bool furtherinvasivereviewrequired = true;
  String? conditionalassessment;
  String parentid;
  String? createdby;
  String? createdat;
  late String eee;
  late String lbc;
  late String awe;
  String? editedat;
  String? lasteditedby;
  String parenttype = '';
  bool unitUnavailable = false;

  VisualSection({
    this.name,
    images,
    exteriorelements,
    waterproofingelements,
    this.additionalconsiderations,
    this.visualreview,
    this.visualsignsofleak = false,
    this.furtherinvasivereviewrequired = true,
    this.conditionalassessment,
    required this.parentid,
    this.createdby,
    this.createdat,
    this.editedat,
    this.lasteditedby,
    this.eee = '',
    this.lbc = '',
    this.awe = '',
    this.parenttype = '',
    this.unitUnavailable = false,
  }) : images = [],
       exteriorelements = [],
       waterproofingelements = [];

  @override
  String get docType => 'VisualSection';

  @override
  Map<String, dynamic> toDocument() => {
    'type': 'VisualSection',
    'name': name,
    'images': images,
    'exteriorelements': exteriorelements,
    'waterproofingelements': waterproofingelements,
    'additionalconsiderations': additionalconsiderations,
    'visualreview': visualreview,
    'visualsignsofleak': visualsignsofleak,
    'furtherinvasivereviewrequired': furtherinvasivereviewrequired,
    'conditionalassessment': conditionalassessment,
    'parentid': parentid,
    'createdby': createdby,
    'createdat': createdat,
    'editedat': editedat,
    'lasteditedby': lasteditedby,
    'eee': eee,
    'lbc': lbc,
    'awe': awe,
    'parenttype': parenttype,
    'unitUnavailable': unitUnavailable,
  };

  factory VisualSection.fromDocument(Map<String, dynamic> doc) {
    return VisualSection(
      name: doc['name'],
      images: List<String>.from(doc['images'] ?? []),
      exteriorelements: List<String>.from(doc['exteriorelements'] ?? []),
      waterproofingelements: List<String>.from(
        doc['waterproofingelements'] ?? [],
      ),
      additionalconsiderations: doc['additionalconsiderations'],
      visualreview: doc['visualreview'],
      visualsignsofleak: doc['visualsignsofleak'] ?? false,
      furtherinvasivereviewrequired:
          doc['furtherinvasivereviewrequired'] ?? true,
      conditionalassessment: doc['conditionalassessment'],
      parentid: doc['parentid'],
      createdby: doc['createdby'],
      createdat: doc['createdat'],
      editedat: doc['editedat'],
      lasteditedby: doc['lasteditedby'],
      parenttype: doc['parenttype'] ?? '',
      eee: doc['eee'] ?? '',
      lbc: doc['lbc'] ?? '',
      awe: doc['awe'] ?? '',
      unitUnavailable: doc['unitUnavailable'] ?? false,
    );
  }
}

// Deck Image Document
class DeckImage extends CouchbaseDocument {
  String? localUrl;
  String? remoteUrl;
  bool isuploaded;
  String? parentid;
  String? parenttype;
  String? sectiontype;
  String? sectionname;
  String? uploadedBy;

  DeckImage({
    this.localUrl,
    this.remoteUrl,
    this.isuploaded = false,
    this.parentid,
    this.parenttype,
    this.sectiontype,
    this.sectionname,
    this.uploadedBy,
  });

  @override
  String get docType => 'DeckImage';
  @override
  Map<String, dynamic> toDocument() => {
    'type': 'DeckImage',
    'localUrl': localUrl,
    'remoteUrl': remoteUrl,
    'isuploaded': isuploaded,
    'parentid': parentid,
    'parenttype': parenttype,
    'sectiontype': sectiontype,
    'sectionname': sectionname,
    'uploadedBy': uploadedBy,
  };

  factory DeckImage.fromDocument(Map<String, dynamic> doc) {
    return DeckImage(
      localUrl: doc['localUrl'],
      remoteUrl: doc['remoteUrl'],
      isuploaded: doc['isuploaded'] ?? false,
      parentid: doc['parentid'],
      parenttype: doc['parenttype'],
      sectiontype: doc['sectiontype'],
      sectionname: doc['sectionname'],
      uploadedBy: doc['uploadedBy'],
    );
  }
}

// Location Form Document
class LocationForm extends CouchbaseDocument {
  String? name;
  String? companyIdentifier;
  List<Question> questions = [];

  LocationForm({this.name, this.companyIdentifier, this.questions = const []});

  @override
  @override
  String get docType => 'LocationForm';

  @override
  Map<String, dynamic> toDocument() => {
    'docType': 'LocationForm',
    'name': name,
    'companyIdentifier': companyIdentifier,
    'questions': questions.map((q) => q.toMap()).toList(),
  };

  factory LocationForm.fromDocument(Map<String, dynamic> doc) {
    return LocationForm(
      name: doc['name'],
      companyIdentifier: doc['companyIdentifier'],
      questions:
          (doc['questions'] as List<dynamic>?)
              ?.map((q) => Question.fromMap(q as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

// Question Document (nested in LocationForm)
class Question {
  String? id;
  String? question;
  String? answerType;
  List<String>? options;
  String? answer;

  Question({
    this.id,
    this.question,
    this.answerType,
    this.options,
    this.answer,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'question': question,
    'answerType': answerType,
    'options': options,
    'answer': answer,
  };

  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      id: map['id'],
      question: map['question'],
      answerType: map['answerType'],
      options: List<String>.from(map['options'] ?? []),
      answer: map['answer'],
    );
  }
}

// Invasive Section Document
class InvasiveSection extends CouchbaseDocument {
  String? invasiveDescription;
  String? parentid;
  bool postinvasiverepairsrequired = false;
  List<String> invasiveimages = [];

  InvasiveSection({
    this.invasiveDescription,
    this.parentid,
    this.postinvasiverepairsrequired = false,
    this.invasiveimages = const [],
  });

  @override
  String get docType => 'InvasiveSection';
  @override
  @override
  Map<String, dynamic> toDocument() => {
    'type': 'InvasiveSection',
    'invasiveDescription': invasiveDescription,
    'parentid': parentid,
    'postinvasiverepairsrequired': postinvasiverepairsrequired,
    'invasiveimages': invasiveimages,
  };

  factory InvasiveSection.fromDocument(Map<String, dynamic> doc) {
    return InvasiveSection(
      invasiveDescription: doc['invasiveDescription'],
      parentid: doc['parentid'],
      postinvasiverepairsrequired: doc['postinvasiverepairsrequired'] ?? false,
      invasiveimages: List<String>.from(doc['invasiveimages'] ?? []),
    );
  }
}

// Conclusive Section Document
class ConclusiveSection extends CouchbaseDocument {
  String? conclusiveconsiderations;
  String? eeeconclusive;
  String? lbcconclusive;
  String? aweconclusive;
  String? parentid;
  bool propowneragreed = false;
  bool invasiverepairsinspectedandcompleted = false;
  List<String> conclusiveimages = [];

  ConclusiveSection({
    this.conclusiveconsiderations,
    this.eeeconclusive,
    this.lbcconclusive,
    this.aweconclusive,
    this.parentid,
    this.propowneragreed = false,
    this.invasiverepairsinspectedandcompleted = false,
    this.conclusiveimages = const [],
  });

  @override
  String get docType => 'ConclusiveSection';
  @override
  @override
  Map<String, dynamic> toDocument() => {
    'docType': 'ConclusiveSection',
    'conclusiveconsiderations': conclusiveconsiderations,
    'eeeconclusive': eeeconclusive,
    'lbcconclusive': lbcconclusive,
    'aweconclusive': aweconclusive,
    'parentid': parentid,
    'propowneragreed': propowneragreed,
    'invasiverepairsinspectedandcompleted':
        invasiverepairsinspectedandcompleted,
    'conclusiveimages': conclusiveimages,
  };

  factory ConclusiveSection.fromDocument(Map<String, dynamic> doc) {
    return ConclusiveSection(
      conclusiveconsiderations: doc['conclusiveconsiderations'],
      eeeconclusive: doc['eeeconclusive'],
      lbcconclusive: doc['lbcconclusive'],
      aweconclusive: doc['aweconclusive'],
      parentid: doc['parentid'],
      propowneragreed: doc['propowneragreed'] ?? false,
      invasiverepairsinspectedandcompleted:
          doc['invasiverepairsinspectedandcompleted'] ?? false,
      conclusiveimages: List<String>.from(doc['conclusiveimages'] ?? []),
    );
  }
}

// Dynamic Visual Section Document
class DynamicVisualSection extends CouchbaseDocument {
  String? companyIdentifier;
  String? name;
  String? parentid;
  bool unitUnavailable = false;
  bool furtherinvasivereviewrequired = true;
  String? createdby;
  String? createdat;
  String parenttype = '';
  String? editedat;
  String? lasteditedby;
  String? additionalconsiderations;
  List<String> images = [];
  List<Section> sections = [];
  List<Question> questions = [];

  DynamicVisualSection({
    this.companyIdentifier,
    this.name,
    this.parentid,
    this.unitUnavailable = false,
    this.furtherinvasivereviewrequired = true,
    this.createdby,
    this.createdat,
    this.parenttype = '',
    this.editedat,
    this.lasteditedby,
    this.additionalconsiderations,
    this.images = const [],
    this.questions = const [],
    this.sections = const [],
  });

  @override
  String get docType => 'DynamicVisualSection';
  @override
  @override
  Map<String, dynamic> toDocument() => {
    'docType': 'DynamicVisualSection',
    'companyIdentifier': companyIdentifier,
    'name': name,
    'parentid': parentid,
    'unitUnavailable': unitUnavailable,
    'furtherinvasivereviewrequired': furtherinvasivereviewrequired,
    'createdby': createdby,
    'createdat': createdat,
    'parenttype': parenttype,
    'editedat': editedat,
    'lasteditedby': lasteditedby,
    'additionalconsiderations': additionalconsiderations,
    'images': images,
    'sections': sections.map((s) => s.toMap()).toList(),
    'questions': questions.map((q) => q.toMap()).toList(),
  };

  factory DynamicVisualSection.fromDocument(Map<String, dynamic> doc) {
    return DynamicVisualSection(
      companyIdentifier: doc['companyIdentifier'],
      name: doc['name'],
      parentid: doc['parentid'],
      unitUnavailable: doc['unitUnavailable'] ?? false,
      furtherinvasivereviewrequired:
          doc['furtherinvasivereviewrequired'] ?? true,
      createdby: doc['createdby'],
      createdat: doc['createdat'],
      parenttype: doc['parenttype'] ?? '',
      editedat: doc['editedat'],
      lasteditedby: doc['lasteditedby'],
      additionalconsiderations: doc['additionalconsiderations'],
      images: List<String>.from(doc['images'] ?? []),
      sections:
          doc['sections'] != null
              ? (doc['sections'] as List<dynamic>)
                  .map((s) => Section.fromMap(s as Map<String, dynamic>))
                  .toList()
              : [],
      questions:
          (doc['questions'] as List<dynamic>?)
              ?.map((q) => Question.fromMap(q as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

// Child (embedded) Document used by Project/SubProject
class Child {
  String? id;
  String? name;
  String? type;
  String? description;
  String? url;
  bool isInvasive = false;
  String? sequenceNo;

  Child({
    this.id,
    this.name,
    this.type,
    this.description,
    this.url,
    this.isInvasive = false,
    this.sequenceNo,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'type': type,
    'description': description,
    'url': url,
    'isInvasive': isInvasive,
    'sequenceNo': sequenceNo,
  };

  factory Child.fromMap(Map<String, dynamic> map) {
    try {
      var child = Child(
        id: map['id'],
        name: map['name'],
        type: map['type'],
        description: map['description'],
        url: map['url'],
        isInvasive: map['isInvasive'] ?? false,
        sequenceNo: map['sequenceNo'] ?? '0',
      );
      return child;
    } catch (e) {
      debugPrint('Error parsing Child from map: $e');
      return Child();
    }
  }
}

class Section {
  String? name;
  String id;
  bool isInvasive;
  bool visualsignsofleak;
  bool furtherinvasivereviewrequired;
  String? conditionalassessment;
  String? visualreview;
  String? coverUrl;
  int count;
  bool isuploading;
  String? sequenceNo;

  Section({
    required this.id,
    this.name,
    this.isInvasive = false,
    this.visualsignsofleak = false,
    this.furtherinvasivereviewrequired = false,
    this.conditionalassessment,
    this.visualreview,
    this.coverUrl,
    this.count = 0,
    this.isuploading = false,
    this.sequenceNo,
  });

  // @override
  // String get docType => 'Section';

  Map<String, dynamic> toMap() => {
    'docType': 'Section',
    'id': id,
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

  factory Section.fromMap(Map<String, dynamic> doc, {String? id}) {
    var section = Section(
      id: doc['id'] ?? doc['sectionId'],
      name: doc['name'],
      isInvasive: doc['isInvasive'] ?? false,
      visualsignsofleak: doc['visualsignsofleak'] ?? false,
      furtherinvasivereviewrequired:
          doc['furtherinvasivereviewrequired'] ?? false,
      conditionalassessment: doc['conditionalassessment'],
      visualreview: doc['visualreview'],
      coverUrl: doc['coverUrl'] ?? '',
      count: doc['count'] ?? 0,
      isuploading: doc['isuploading'] ?? false,
      sequenceNo: doc['sequenceNo'] ?? '0',
    );
    if (id != null) section.id = id;
    return section;
  }
}
