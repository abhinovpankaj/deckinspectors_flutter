class Section {
  String? id;
  String? name;

  bool visualsignsofleak = false;
  bool furtherinvasivereviewrequired = false;
  String? conditionalassessment;
  String? visualreview;
  int count = 0;
  String? coverUrl;

  Section(
      {this.id,
      this.name,
      required this.visualsignsofleak,
      required this.furtherinvasivereviewrequired,
      this.visualreview,
      this.coverUrl,
      this.conditionalassessment,
      required this.count});

  Section.fromJson(Map<String, dynamic> json) {
    id = json['id'];

    count = json['count'] ?? 0;
    name = json['name'];
    coverUrl = json['url'];
    visualreview = json['visualreview'];
    visualsignsofleak = json['visualsignsofleak'];
    furtherinvasivereviewrequired = json['furtherinvasivereviewrequired'];
    conditionalassessment = json['conditionalassessment'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;

    data['visualreview'] = visualreview;
    data['name'] = name;
    data['url'] = coverUrl;
    data['visualsignsofleak'] = visualsignsofleak;
    data['furtherinvasivereviewrequired'] = furtherinvasivereviewrequired;
    data['count'] = count;
    data['conditionalassessment'] = conditionalassessment;
    return data;
  }
}

class Location {
  String? id;
  String? name;
  String? type;
  String? description;
  String? parentid;
  String? parenttype;
  String? createdby;
  String? createdat;
  String? url;
  DateTime? editedat;
  String? lasteditedby;
  List<Section>? sections;

  Location(
      {this.id,
      this.name,
      this.description,
      this.parentid,
      this.parenttype,
      this.createdby,
      this.createdat,
      this.url,
      this.editedat,
      this.lasteditedby,
      this.type,
      this.sections});

  Location.fromJson(Map<String, dynamic> json) {
    id = json['_id'];
    name = json['name'];
    description = json['description'];
    createdby = json['createdby'];
    createdat = json['createdat'];
    parentid = json['parentid'];
    parenttype = json['parenttype'];
    url = json['url'];
    editedat =
        json['editedat'] == null ? null : DateTime.tryParse(json['editedat']);
    lasteditedby = json['lasteditedby'];
    type = json['type'];
    if (json['sections'] != null) {
      sections = <Section>[];
      json['sections'].forEach((v) {
        sections!.add(Section.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['_id'] = id;
    data['name'] = name;
    data['description'] = description;
    data['parentid'] = parentid;
    data['parenttype'] = parenttype;
    data['createdby'] = createdby;
    data['url'] = url;
    data['type'] = type;
    data['editedat'] = editedat;
    data['lasteditedby'] = lasteditedby;
    data['sections'] =
        sections?.map((v) => v.toJson()).toList();
    return data;
  }
}

class LocationResponse {
  Location? item;
  String? message;
  int? code;

  LocationResponse({this.item, this.message, this.code});

  LocationResponse.fromJson(Map<String, dynamic> json) {
    item = json['item'] != null ? Location?.fromJson(json['item']) : null;
    message = json['message'];
    code = json['code'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['item'] = item!.toJson();
    data['message'] = message;
    data['code'] = code;
    return data;
  }
}
