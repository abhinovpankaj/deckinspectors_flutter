import 'project_model.dart';

class SubProject {
  String? id;
  String? name;
  String? type;
  String? description;
  String? parentid;
  String? parenttype;
  String? createdby;
  String? createdat;
  String? url;
  List<String?>? assignedto;
  DateTime? editedat;
  String? lasteditedby;

  List<Child>? children;

  SubProject(
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
      this.children});

  SubProject.fromJson(Map<String, dynamic> json) {
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
    assignedto = json['assignedto'] == null
        ? []
        : List.castFrom<dynamic, String>(json['assignedto']);
    type = json['type'];
    if (json['children'] != null) {
      children = <Child>[];
      json['children'].forEach((v) {
        children!.add(Child.fromJson(v));
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
    data['assignedto'] = assignedto;
    data['children'] =
        children?.map((v) => v.toJson()).toList();
    return data;
  }
}

class SubProjectResponse {
  SubProject? item;
  String? message;
  int? code;

  SubProjectResponse({this.item, this.message, this.code});

  SubProjectResponse.fromJson(Map<String, dynamic> json) {
    item = json['item'] != null ? SubProject?.fromJson(json['item']) : null;
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
