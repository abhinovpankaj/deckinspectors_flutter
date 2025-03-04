import 'package:E3InspectionsMultiTenant/src/bloc/users_bloc.dart';
import 'package:E3InspectionsMultiTenant/src/models/realm/realm_schemas.dart';
import 'package:E3InspectionsMultiTenant/src/services/realm_local_services.dart';
import 'package:E3InspectionsMultiTenant/src/ui/cachedimage_widget.dart';
import 'package:E3InspectionsMultiTenant/src/ui/singlelevelproject_details.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:realm/realm.dart';

import 'addedit_project.dart';
import 'project_details.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({Key? key}) : super(key: key);
  @override
  State<ProjectsPage> createState() => _ProjectsPageState();

  static MaterialPageRoute getRoute() => MaterialPageRoute(
      settings: const RouteSettings(name: 'Home'),
      builder: (context) => const ProjectsPage());
}

//Add New Project
class _ProjectsPageState extends State<ProjectsPage> {
  //LoginResponse loggedInUser = LoginResponse();
  late String userFullName;

  @override
  void initState() {
    super.initState();
    var loggedInUser = usersBloc.userDetails;
    userFullName = loggedInUser.firstname as String;
    userFullName = "$userFullName ${loggedInUser.lastname as String}";
  }

  Project getProject() {
    return Project(ObjectId(),
        name: "",
        isInvasive: false,
        description: "",
        address: "",
        url: "",
        projecttype: 'multilevel',
        children: [],
        latitude: 28.7,
        longitude: 77.1,
        createdby: userFullName);
  }

  void addEditProject() {
    Navigator.push(context,
            AddEditProjectPage.getRoute(getProject(), true, userFullName))
        .then((value) => setState(() => {}));
  }

  void gotoProjectDetails(ObjectId projectId, String projName) {
    //setState(() {});
    Navigator.push(
            context,
            ProjectDetailsPage.getRoute(
                projectId, userFullName, false, projName))
        .then((value) => setState(() => {}));
  }

  void gotoInvasiveProjectDetails(ObjectId projectId, String projName) {
    Navigator.push(
            context,
            ProjectDetailsPage.getRoute(
                projectId, userFullName, true, projName))
        .then((value) => setState(() => {}));
  }

  getCustomFormattedDateTime(String givenDateTime, String dateFormat) {
    // dateFormat = 'MM/dd/yy';
    final DateTime docDateTime = DateTime.parse(givenDateTime);
    return DateFormat(dateFormat).format(docDateTime);
  }

  @override
  Widget build(BuildContext context) {
    //projectsBloc.fetchAllProjects();
    final realmServices = Provider.of<RealmLocalServices?>(context);
    return Scaffold(
        appBar: AppBar(
            automaticallyImplyLeading: false,
            leadingWidth: 20,
            backgroundColor: Colors.white,
            foregroundColor: Colors.blue,
            elevation: 0,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Your Projects',
                  style: TextStyle(color: Colors.black),
                ),
                InkWell(
                    onTap: () {
                      addEditProject();
                    },
                    child: const Chip(
                      avatar: Icon(
                        Icons.add_circle_outline,
                        color: Colors.blue,
                      ),
                      labelPadding: EdgeInsets.all(2),
                      label: Text(
                        'Add new project',
                        style: TextStyle(color: Colors.blue),
                        selectionColor: Colors.white,
                      ),
                      shadowColor: Colors.white,
                      backgroundColor: Colors.white,
                      elevation: 0,
                      autofocus: true,
                    )),
              ],
            )),
        body: StreamBuilder<RealmResultsChanges<Project>>(
            //projectsBloc.projects
            stream: realmServices?.realm
                .query<Project>("TRUEPREDICATE SORT(_id DESC)")
                .changes,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final data = snapshot.data;

                if (data == null) {
                  return const Center(
                      child: Text(
                    'No Projects to display, please add projects',
                    style: TextStyle(fontSize: 16, color: Colors.blue),
                  ));
                } else {
                  final projects = data.results;

                  return ListView.builder(
                    itemCount: projects.realm.isClosed ? 0 : projects.length,
                    itemBuilder: (context, index) {
                      final projType = projects[index].projecttype == null
                          ? "Multi-Level"
                          : projects[index].projecttype == 'singlelevel'
                              ? "Single-Level"
                              : "Multi-Level";

                      return SizedBox(
                        height: 160,
                        width: MediaQuery.of(context).size.width - 5,
                        child: Card(
                          borderOnForeground: false,
//                color: Colors.blue,
                          elevation: 4,
                          child: Row(
                            children: <Widget>[
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(8, 8.0, 8, 8.0),
                                child: GestureDetector(
                                  onTap: () {
                                    if (projects[index].projecttype ==
                                        'singlelevel') {
                                      gotoSingleLevelProject(projects[index].id,
                                          projects[index].name as String);
                                    } else {
                                      gotoProjectDetails(projects[index].id,
                                          projects[index].name as String);
                                    }
                                  },
                                  child: Container(
                                    width: 100.0,
                                    height: 100.0,
                                    decoration: const BoxDecoration(
                                        color: Colors.orange,
                                        // image: DecorationImage(
                                        //     image: AssetImage(
                                        //         'assets/images/icon.png'),
                                        //     fit: BoxFit.cover),
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(8.0)),
                                        boxShadow: [
                                          BoxShadow(
                                              blurRadius: 1.0,
                                              color: Colors.blue)
                                        ]),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8.0),
                                      child: cachedNetworkImage(
                                          projects[index].url),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(2, 8, 2, 8),
                                  child: Column(
                                    children: <Widget>[
                                      // Expanded(
                                      //child:
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          projects[index].name as String,
                                          maxLines: 1,
                                          overflow: TextOverflow.fade,
                                          textAlign: TextAlign.left,
                                          style: const TextStyle(
                                              color: Colors.black,
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      // ),
                                      Expanded(
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  flex: 1,
                                                  child: Padding(
                                                    padding: const EdgeInsets
                                                        .fromLTRB(0, 8, 0, 0),
                                                    child: Text(
                                                      projType,
                                                      textAlign: TextAlign.left,
                                                      style: const TextStyle(
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 1,
                                                  child: Padding(
                                                    padding: const EdgeInsets
                                                        .fromLTRB(0, 8, 0, 0),
                                                    child: Text(
                                                      'Edited at:  ${getCustomFormattedDateTime(projects[index].editedat as String, 'MM/dd/yy hh:mm')}',
                                                      textAlign: TextAlign.left,
                                                      style: const TextStyle(
                                                          color: Colors.black87,
                                                          fontSize: 10,
                                                          fontStyle:
                                                              FontStyle.italic),
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                    flex: 2,
                                                    child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .fromLTRB(0, 8,
                                                                0, 0),
                                                        child: GestureDetector(
                                                            onTap: () {
                                                              if (projects[
                                                                          index]
                                                                      .projecttype ==
                                                                  'singlelevel') {
                                                                gotoSingleLevelProject(
                                                                    projects[index]
                                                                        .id,
                                                                    projects[index]
                                                                            .name
                                                                        as String);
                                                              } else {
                                                                gotoProjectDetails(
                                                                    projects[index]
                                                                        .id,
                                                                    projects[index]
                                                                            .name
                                                                        as String);
                                                              }
                                                            },
                                                            child: Container(
                                                                alignment: Alignment
                                                                    .bottomRight,
                                                                padding:
                                                                    const EdgeInsets
                                                                        .fromLTRB(
                                                                        0,
                                                                        8,
                                                                        8,
                                                                        8),
                                                                child:
                                                                    const Text(
                                                                  'Visual',
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .blue,
                                                                      fontSize:
                                                                          17),
                                                                )))))
                                              ],
                                            ),
                                            GestureDetector(
                                                onTap: () {
                                                  if (projects[index]
                                                          .projecttype ==
                                                      'singlelevel') {
                                                    gotoInvasiveSingleProject(
                                                        projects[index].id);
                                                  } else {
                                                    gotoInvasiveProjectDetails(
                                                        projects[index].id,
                                                        projects[index].name
                                                            as String);
                                                  }
                                                },
                                                child: Container(
                                                    alignment:
                                                        Alignment.bottomRight,
                                                    padding: const EdgeInsets
                                                        .fromLTRB(8, 8, 16, 8),
                                                    child: const Text(
                                                      'Invasive',
                                                      style: TextStyle(
                                                          color: Colors.blue,
                                                          fontSize: 17),
                                                    )))
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }
              }
              return const Align(
                  alignment: Alignment.center,
                  child: CircularProgressIndicator());
            }));
  }

  void gotoSingleLevelProject(ObjectId id, String projName) {
    Navigator.push(
            context,
            SingleProjectDetailsPage.getRoute(
                id, userFullName, false, projName))
        .then((value) => setState(() => {}));
  }

  void gotoInvasiveSingleProject(ObjectId id) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) =>
                SingleProjectDetailsPage(id, userFullName, true)));
  }
}
