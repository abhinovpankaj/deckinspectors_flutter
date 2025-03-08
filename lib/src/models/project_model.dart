class Child {
  String? id;
  String? name;
  String? type;
  String? description;
  String? url;
  int count = 0;

  Child(
      {this.id,
      this.name,
      this.type,
      this.description,
      this.url,
      required this.count});

  Child.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    //count =json['count'];
    name = json['name'];
    type = json['type'];
    description = json['description'];
    url = json['url'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['type'] = type;
    data['description'] = description;
    data['url'] = url;
    data['count'] = count;
    return data;
  }
}

class Project {
  String? id;
  String? name;
  String? projecttype;
  String? description;
  String? address;
  String? createdby;
  String? createdat;
  String? url;
  bool? isavailableoffline;
  bool? iscomplete;
  DateTime? editedat;
  String? lasteditedby;
  List<String?>? assignedto;
  List<Child>? children;

  Project(
      {this.id,
      this.name,
      this.projecttype,
      this.description,
      this.address,
      this.createdby,
      this.createdat,
      this.url,
      this.isavailableoffline,
      this.iscomplete,
      this.editedat,
      this.lasteditedby,
      this.assignedto,
      this.children});

  Project.fromJson(Map<String, dynamic> json) {
    id = json['_id'];
    name = json['name'];
    projecttype = json['projectType'];
    description = json['description'];
    address = json['address'];
    createdby = json['createdby'];
    createdat = json['createdat'];
    url = json['url'];
    isavailableoffline = json['isavailableoffline'];
    iscomplete = json['iscomplete'];
    if (json['children'] != null) {
      children = <Child>[];
      json['children'].forEach((v) {
        children!.add(Child.fromJson(v));
      });
      editedat =
          json['editedat'] == null ? null : DateTime.tryParse(json['editedat']);
      lasteditedby = json['lasteditedby'];
      assignedto = json['assignedto'] == null
          ? []
          : List.castFrom<dynamic, String>(json['assignedto']);
    }
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['_id'] = id;
    data['name'] = name;
    data['projecType'] = projecttype;
    data['description'] = description;
    data['address'] = address;
    data['createdby'] = createdby;
    data['url'] = url;
    data['isavailableoffline'] = isavailableoffline;
    data['iscomplete'] = iscomplete;
    data['editedat'] = editedat;
    data['lasteditedby'] = lasteditedby;
    data['assignedto'] = assignedto;
    data['children'] =
        children?.map((v) => v.toJson()).toList();
    return data;
  }
}

class Projects {
  List<Project?>? projects;
  String? message;
  int? code;

  Projects({this.projects, this.message, this.code});

  Projects.fromJson(Map<String, dynamic> json) {
    if (json['projects'] != null) {
      projects = <Project>[];
      json['projects'].forEach((v) {
        projects!.add(Project.fromJson(v));
      });
    }
    message = json['message'];
    code = json['code'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['projects'] =
        projects?.map((v) => v?.toJson()).toList();
    data['message'] = message;
    data['code'] = code;
    return data;
  }
}

class ProjectResponse {
  Project? item;
  String? message;
  int? code;

  ProjectResponse({this.item, this.message, this.code});

  ProjectResponse.fromJson(Map<String, dynamic> json) {
    item = json['item'] != null ? Project?.fromJson(json['item']) : null;
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
