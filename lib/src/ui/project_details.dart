import 'dart:async' as async;
import 'dart:convert';
import 'dart:io';

import 'package:E3InspectionsMultiTenant/src/bloc/projects_bloc.dart';
import 'package:E3InspectionsMultiTenant/src/bloc/settings_bloc.dart';
import 'package:E3InspectionsMultiTenant/src/bloc/users_bloc.dart';
import 'package:E3InspectionsMultiTenant/src/models/error_response.dart';
import 'package:E3InspectionsMultiTenant/src/models/success_response.dart';
import 'package:E3InspectionsMultiTenant/src/resources/realm/realm_services.dart';
import 'package:E3InspectionsMultiTenant/src/ui/cachedimage_widget.dart';
//import 'package:E3InspectionsMultiTenant/src/ui/pdfviewer.dart';
import 'package:E3InspectionsMultiTenant/src/ui/showprojecttype_widget.dart';
import 'package:flutter_material_pickers/helpers/show_checkbox_picker.dart';
import 'package:flutter_material_pickers/models/select_all_config.dart';
import 'package:map_launcher/map_launcher.dart';
//import 'package:maps_launcher/maps_launcher.dart';

import 'package:provider/provider.dart';
import 'package:realm/realm.dart';
import '../models/realm/realm_schemas.dart';

import 'addedit_subproject.dart';

//import 'breadcrumb_navigation.dart';
import 'htmlviewer.dart';
import 'location.dart';
import 'package:flutter/material.dart';
import 'addedit_project.dart';
import 'addedit_location.dart';
import 'subproject.dart';
import 'package:intl/intl.dart';

class ProjectDetailsPage extends StatefulWidget {
  final ObjectId id;
  final String userFullName;
  final bool isInvasiveMode;
  const ProjectDetailsPage(this.id, this.userFullName, this.isInvasiveMode,
      {Key? key})
      : super(key: key);

  @override
  State<ProjectDetailsPage> createState() => _ProjectDetailsPageState();

  static MaterialPageRoute getRoute(
          ObjectId id, String userName, bool isInvasive, String pageName) =>
      MaterialPageRoute(
          settings: RouteSettings(name: pageName),
          builder: (context) => ProjectDetailsPage(id, userName, isInvasive));
}

//Add New Project
class _ProjectDetailsPageState extends State<ProjectDetailsPage>
    with SingleTickerProviderStateMixin {
  late Project currentProject;
  late int selectedTabIndex = 0;
//Tab Controls
  late TabController _tabController;
  late String userFullName;
  late String createdAt;
  late List<Child?> locations;
  late List<Child?> buildings;
  late bool isInvasiveMode;
  late ObjectId projectId;
  late RealmProjectServices realmProjServices;
  List<String> assignedUsers = [];
  Location getNewLocation() {
    var newLocation = Location(ObjectId(), projectId, false,
        name: "",
        description: "",
        url: "",
        createdby: userFullName,
        type: 'projectlocation',
        parenttype: 'project');
    return newLocation;
  }

  SubProject getNewBuilding() {
    var newBuilding = SubProject(ObjectId(), projectId, false,
        name: "",
        description: "",
        url: "",
        createdby: userFullName,
        type: 'subproject',
        parenttype: 'project');
    return newBuilding;
  }

  @override
  void initState() {
    super.initState();

    projectId = widget.id;
    isInvasiveMode = widget.isInvasiveMode;
    appSettings.isInvasiveMode = isInvasiveMode;
    userFullName = widget.userFullName;

    _tabController = TabController(vsync: this, length: 2);

    _tabController.addListener(_handleTabSelection);
    locations = List.empty(growable: true);
    buildings = List.empty(growable: true);
  }

  async.FutureOr refreshProjectDetails(dynamic value) async {
    // var response = await projectsBloc.getProject(currentProject.id as String);
    // if (response is Project) {
    //   currentProject = response;
    // } else {
    //   //
    // }
    setState(() {
      if (currentProject.isValid) {
        if (isInvasiveMode) {
          locations = currentProject.children
              .where((element) =>
                  element.type == 'projectlocation' && element.isInvasive)
              .toList();
          buildings = currentProject.children
              .where((element) =>
                  element.type == 'subproject' && element.isInvasive)
              .toList();
        } else {
          locations = currentProject.children
              .where((element) => element.type == 'projectlocation')
              .toList();
          locations.sort((l1, l2) {
            if (l1!.sequenceNo != null && l2!.sequenceNo != null) {
              if (int.parse(l1.sequenceNo!) < int.parse(l2.sequenceNo!)) {
                return -1;
              } else {
                return 1;
              }
            } else {
              return l1.id.toString().compareTo(l2!.id.toString());
            }
          });
          buildings = currentProject.children
              .where((element) => element.type == 'subproject')
              .toList();
          buildings.sort((l1, l2) {
            if (l1!.sequenceNo != null && l2!.sequenceNo != null) {
              if (int.parse(l1.sequenceNo!) < int.parse(l2.sequenceNo!)) {
                return -1;
              } else {
                return 1;
              }
            } else {
              return l1.id.toString().compareTo(l2!.id.toString());
            }
          });
        }
      }
    });
  }

  void _handleTabSelection() {
    switch (_tabController.index) {
      case 0:
        selectedTabIndex = 0;
        break;
      case 1:
        selectedTabIndex = 1;
        break;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void addEditProject() {
    Navigator.push(context,
        AddEditProjectPage.getRoute(currentProject, false, userFullName));
  }

  void addNewChild(String name) {
    //setState(() {});
    if (selectedTabIndex == 1) {
      Navigator.push(
          context,
          AddEditLocationPage.getRoute(getNewLocation(), true, userFullName,
              name)); //.then(refreshProjectDetails);
    } else {
      Navigator.push(
          context,
          AddEditSubProjectPage.getRoute(getNewBuilding(), true, userFullName,
              name)); //.then(refreshProjectDetails);
    }
  }

  void gotoDetails(ObjectId id, String name, String pageName) {
    if (selectedTabIndex == 1) {
      Navigator.push(
        context,
        LocationPage.getRoute(
            id, name, 'Project Locations', userFullName, pageName),
      ).then((value) {
        locations.remove(value);
        setState(() => {});
      });
    } else {
      Navigator.push(
        context,
        SubProjectDetailsPage.getRoute(id, name, userFullName, pageName),
      ).then((value) => setState(() => {}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final realmServices =
        Provider.of<RealmProjectServices>(context, listen: false);
    return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leadingWidth: 140,
          leading: ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.blue,
            ),
            label: const Text(
              'Home',
              style: TextStyle(color: Colors.blue),
            ),
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: Colors.transparent,
            ),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.blue,
          elevation: 0,
          title: const Text(
            'Project',
            style:
                TextStyle(color: Colors.black, fontWeight: FontWeight.normal),
          ),
        ),
        // floatingActionButton: Padding(
        //   padding: const EdgeInsets.fromLTRB(20, 0, 0, 0),
        //   child: BreadCrumbNavigator(),
        // ),
        body: StreamBuilder<RealmObjectChanges<Project>>(
          //projectsBloc.projects
          stream: realmServices.getProject(projectId)?.changes,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final data = snapshot.data;

              if (data == null) {
                return Center(
                  child: Text(
                    '${snapshot.error} occurred',
                    style: const TextStyle(fontSize: 18),
                  ),
                );

                // if we got our data
              } else {
                currentProject = data.object;
                if (currentProject.isValid) {
                  if (isInvasiveMode) {
                    locations = currentProject.children
                        .where((element) =>
                            element.type == 'projectlocation' &&
                            element.isInvasive)
                        .toList();

                    buildings = currentProject.children
                        .where((element) =>
                            element.type == 'subproject' && element.isInvasive)
                        .toList();
                  } else {
                    locations = currentProject.children
                        .where((element) => element.type == 'projectlocation')
                        .toList();

                    buildings = currentProject.children
                        .where((element) => element.type == 'subproject')
                        .toList();
                  }
                  buildings.sort((l1, l2) {
                    if (l1!.sequenceNo != null && l2!.sequenceNo != null) {
                      if (int.parse(l1.sequenceNo!) <
                          int.parse(l2.sequenceNo!)) {
                        return -1;
                      } else {
                        return 1;
                      }
                    } else {
                      return l1.id.toString().compareTo(l2!.id.toString());
                    }
                  });
                  locations.sort((l1, l2) {
                    if (l1!.sequenceNo != null && l2!.sequenceNo != null) {
                      if (int.parse(l1.sequenceNo!) <
                          int.parse(l2.sequenceNo!)) {
                        return -1;
                      } else {
                        return 1;
                      }
                    } else {
                      return l1.id.toString().compareTo(l2!.id.toString());
                    }
                  });
                  var shortDate =
                      DateTime.tryParse(currentProject.createdat as String);
                  if (shortDate != null) {
                    createdAt = DateFormat.yMMMEd().format(shortDate);
                  } else {
                    createdAt = "";
                  }
                }

                return SingleChildScrollView(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // StatefulBuilder(builder: (context, StateSetter setState) {
                    projectDetails(
                        currentProject.name as String,
                        currentProject.url as String,
                        currentProject.id,
                        currentProject.description as String,
                        currentProject.editedat as String,
                        currentProject.address as String),
                    //}),
                    projectChildrenTab(context),
                    // const Divider(
                    //   color: Color.fromARGB(255, 222, 213, 213),
                    //   height: 2,
                    //   thickness: 2,
                    //   indent: 0,
                    //   endIndent: 0,
                    // ),
                    // Padding(
                    //   padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
                    //   child: BreadCrumbNavigator(),
                    // )
                  ],
                ));

                // if (data is ErrorResponse) {
                //   return Center(
                //     child: Text(
                //       '${data.message}',
                //       style: const TextStyle(fontSize: 18),
                //     ),
                //   );
                // }
              }
            }

            // Displaying LoadingSpinner to indicate waiting state
            return const Center(
              child: CircularProgressIndicator(),
            );
          },
        ));
  }

  getCustomFormattedDateTime(String givenDateTime, String dateFormat) {
    // dateFormat = 'MM/dd/yy';
    final DateTime docDateTime = DateTime.parse(givenDateTime);
    return DateFormat(dateFormat).format(docDateTime);
  }

  Widget projectDetails(String name, String url, ObjectId id,
      String description, String editedat, String address) {
    realmProjServices =
        Provider.of<RealmProjectServices>(context, listen: false);
    return Padding(
      padding: const EdgeInsets.all(0.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(
            height: 4,
          ),
          const ProjectType(),
          Container(
              height: 220,
              decoration: BoxDecoration(
                  color: isInvasiveMode ? Colors.orange : Colors.blue,
                  // image: networkImage(currentProject.url as String),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(8.0)),
                  boxShadow: const [
                    BoxShadow(blurRadius: 1.0, color: Colors.blue)
                  ]),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(8.0)),
                    child: cachedNetworkImage(url),
                  ),
                  OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          side: BorderSide.none,
                          foregroundColor: Colors.white,
                          // the height is 50, the width is full
                          minimumSize: const Size.fromHeight(30),
                          backgroundColor: Colors.lightBlue,
                          shadowColor: Colors.transparent,
                          elevation: 1),
                      onPressed: () async {
                        // var initlattitude = currentProject.latitude ?? 28.7;
                        // var initlongitude = currentProject.longitude ?? 70.7;
                        // Navigator.push(
                        //     context,
                        //     MaterialPageRoute(
                        //         builder: (context) => GoogleMapsView(
                        //             initlattitude, initlongitude, false)));
                        if (currentProject.address == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Address is empty, please add address to navigate.')),
                          );
                        } else {
                          // MapsLauncher.launchQuery(
                          //     currentProject.address as String);
                          //check platform is iOS or Android
                          var coords = Coords(
                            currentProject.latitude ?? 0.0,
                            currentProject.longitude ?? 0.0,
                          );
                          var title = currentProject.name ?? '';
                          if (Platform.isIOS) {
                            final isAvailable =
                                await MapLauncher.isMapAvailable(MapType.apple);
                            if (isAvailable != null && isAvailable) {
                              await MapLauncher.showMarker(
                                mapType: MapType.apple,
                                coords: coords,
                                title: title,
                                description: description,
                              );
                            }
                          }
                        }
                      },
                      icon: const Icon(
                        Icons.location_pin,
                        color: Colors.blueAccent,
                      ),
                      label: const Text(
                        'Navigate',
                        style: TextStyle(color: Colors.white),
                      )),
                ],
              )),
          //networkImage(currentProject.url as String),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 2,
                        style: const TextStyle(
                          fontSize: 18,
                          overflow: TextOverflow.ellipsis,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ),
                    Visibility(
                      visible: !isInvasiveMode,
                      child: InkWell(
                          onTap: () {
                            addEditProject();
                          },
                          child: const Chip(
                            avatar:
                                Icon(Icons.edit_outlined, color: Colors.blue),
                            labelPadding: EdgeInsets.all(2),
                            label: Text(
                              'Edit Project ',
                              style: TextStyle(color: Colors.blue),
                              selectionColor: Colors.transparent,
                            ),
                            shadowColor: Colors.white,
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            autofocus: true,
                          )),
                    ),
                  ],
                )),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Edited on ${getCustomFormattedDateTime(editedat, 'MM/dd/yy hh:mm')}',
                      style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 11,
                          fontStyle: FontStyle.italic),
                    ),
                    Visibility(
                      visible: !isInvasiveMode,
                      child: InkWell(
                          onTap: () {
                            assignProject();
                          },
                          child: const Chip(
                            avatar: Icon(Icons.account_circle_outlined,
                                color: Colors.blue),
                            labelPadding: EdgeInsets.all(0),
                            label: Text(
                              'Assign Project ',
                              style: TextStyle(color: Colors.blue),
                              selectionColor: Colors.transparent,
                            ),
                            shadowColor: Colors.white,
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            autofocus: true,
                          )),
                    ),
                  ],
                )),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.left,
                    ),
                    //remove project download option
                    isInvasiveMode
                        ? PopupMenuButton(
                            child: Chip(
                              avatar: isDownloading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.file_download_done_outlined,
                                      color: Colors.blue),
                              labelPadding: const EdgeInsets.all(2),
                              label: const Text(
                                'Download Report',
                                style:
                                    TextStyle(color: Colors.blue, fontSize: 15),
                              ),
                              shadowColor: Colors.transparent,
                              backgroundColor: Colors.transparent,
                              elevation: 10,
                              autofocus: true,
                            ),
                            onSelected: (value) {
                              _onMenuItemSelected(value as int);
                            },
                            itemBuilder: (ctx) => [
                              _buildPopupMenuItem(
                                  'Invasive', Icons.edit_document, 1),
                              _buildPopupMenuItem('Invasive Only',
                                  Icons.browse_gallery_outlined, 2),
                            ],
                          )
                        : InkWell(
                            onTap: () {
                              isDownloading
                                  ? null
                                  : downloadProjectReport(id, 'Visual');
                            },
                            child: Chip(
                              avatar: isDownloading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.file_download_done_outlined,
                                      color: Colors.blue),
                              labelPadding: const EdgeInsets.all(2),
                              label: const Text(
                                'Download Report ',
                                style: TextStyle(color: Colors.blue),
                                selectionColor: Colors.transparent,
                              ),
                              shadowColor: Colors.white,
                              backgroundColor: Colors.transparent,
                              elevation: 0,
                              autofocus: true,
                            )),
                  ],
                )),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: Text(
                        maxLines: 2,
                        description,
                        style: const TextStyle(
                          overflow: TextOverflow.ellipsis,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ),
                  ],
                )),
          ),

          const Divider(
            color: Color.fromARGB(255, 222, 213, 213),
            height: 5,
            thickness: 2,
            indent: 0,
            endIndent: 0,
          ),
        ],
      ),
    );
  }

  PopupMenuItem _buildPopupMenuItem(
      String title, IconData iconData, int position) {
    return PopupMenuItem(
      value: position,
      child: Row(
        children: [
          Icon(
            iconData,
            color: Colors.blue,
          ),
          const SizedBox(
            width: 15,
          ),
          Text(title),
        ],
      ),
    );
  }

  _onMenuItemSelected(int value) async {
    if (value == 1) {
      downloadProjectReport(currentProject.id, 'Invasive');
    } else {
      downloadProjectReport(currentProject.id, 'InvasiveOnly');
    }
  }

  Widget projectChildrenTab(BuildContext context) {
    // return DefaultTabController(
    //   length: 2,
    //   child:
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: "Buildings (${buildings.length})",
              height: 32,
            ),
            Tab(
              text: "Project Locations (${locations.length})",
              height: 32,
            ),
          ],
          labelColor: Colors.black,
        ),
        SizedBox(
            height: 250,
            child: TabBarView(controller: _tabController, children: [
              locationsWidget('building'),
              locationsWidget('location'),
            ])),
      ],
      // ),
    );
  }

  Widget locationsWidget(String type) {
    bool isEmpty = true;
    if (type == 'location') {
      isEmpty = locations.isEmpty;
    } else {
      isEmpty = buildings.isEmpty;
    }
    return Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Visibility(
              visible: !isInvasiveMode,
              child: Align(
                alignment: Alignment.topRight,
                child: InkWell(
                    onTap: () {
                      addNewChild(currentProject.name as String);
                    },
                    child: Chip(
                      avatar: const Icon(
                        Icons.add_circle_outline,
                        color: Colors.blue,
                      ),
                      labelPadding: const EdgeInsets.all(2),
                      label: Text(
                        'Add $type',
                        style:
                            const TextStyle(color: Colors.blue, fontSize: 15),
                        selectionColor: Colors.transparent,
                      ),
                      shadowColor: Colors.white,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      autofocus: true,
                    )),
              ),
            ),
            isEmpty
                ? Center(
                    child: Text(
                    'No $type, Add project $type.',
                    style: const TextStyle(fontSize: 16),
                  ))
                : type == 'location'
                    ? Expanded(
                        child: ListView.builder(
                            shrinkWrap: true,
                            scrollDirection: Axis.horizontal,
                            itemCount: locations.length,
                            itemBuilder: (BuildContext context, int index) {
                              return horizontalScrollChildren(context, index);
                            }))
                    : Expanded(
                        child: ListView.builder(
                            shrinkWrap: true,
                            scrollDirection: Axis.horizontal,
                            itemCount: buildings.length,
                            itemBuilder: (BuildContext context, int index) {
                              return horizontalScrollChildrenBuildings(
                                  context, index);
                            }))
          ],
        ));
  }

  //Todo create widget for locations
  Widget horizontalScrollChildren(BuildContext context, int index) {
    return SizedBox(
        width: MediaQuery.of(context).size.width / 2,
        height: 180,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  gotoDetails(
                      locations[index]!.id,
                      currentProject.name as String,
                      locations[index]!.name as String);
                },
                child: Container(
                  height: 140,
                  width: 192,
                  decoration: BoxDecoration(
                      color: isInvasiveMode ? Colors.orange : Colors.blue,
                      // image: networkImage(currentProject.url as String),
                      borderRadius:
                          const BorderRadius.all(Radius.circular(8.0)),
                      boxShadow: const [
                        BoxShadow(blurRadius: 1.0, color: Colors.blue)
                      ]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: cachedNetworkImage(locations[index]!.url),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                  child: Text(
                    overflow: TextOverflow.ellipsis,
                    locations[index]!.name as String,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: Text(
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            locations[index]!.description as String,
                            style: const TextStyle(
                              overflow: TextOverflow.ellipsis,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.left,
                          ),
                        ),
                      ],
                    )),
              ),
            ],
          ),
        ));
  }

  Widget horizontalScrollChildrenBuildings(BuildContext context, int index) {
    return SizedBox(
        width: MediaQuery.of(context).size.width / 2,
        height: 180,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  gotoDetails(
                      buildings[index]!.id,
                      currentProject.name as String,
                      buildings[index]!.name as String);
                },
                child: Container(
                  height: 140,
                  width: 192,
                  decoration: BoxDecoration(
                      color: isInvasiveMode ? Colors.orange : Colors.blue,
                      // image: networkImage(currentProject.url as String),
                      borderRadius:
                          const BorderRadius.all(Radius.circular(8.0)),
                      boxShadow: const [
                        BoxShadow(blurRadius: 1.0, color: Colors.blue)
                      ]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: cachedNetworkImage(buildings[index]!.url),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                  child: Text(
                    buildings[index]!.name as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: Text(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            buildings[index]!.description as String,
                            style: const TextStyle(
                              overflow: TextOverflow.ellipsis,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.left,
                          ),
                        ),
                      ],
                    )),
              ),
            ],
          ),
        ));
  }

  bool isDownloading = false;
  void downloadProjectReport(ObjectId id, String reportType) async {
    setState(() {
      isDownloading = true;
    });

    var result = await projectsBloc.downloadProjectReport(
        currentProject.name as String,
        id.toString(),
        'pdf',
        appSettings.reportImageQuality,
        appSettings.imageinRowCount,
        reportType,
        appSettings.companyName);
    if (!mounted) {
      return;
    }
    if (result is ErrorResponse) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Failed to download the report, please try again.${result.message}')));
    } else if (result is SuccessResponse) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text(
          'Report downloaded successfully.',
        ),
        action: SnackBarAction(
            label: 'View Report',
            onPressed: () => gotoReportView(result.message)),
      ));
      //gotoReportView(result.message);
    }
    setState(() {
      isDownloading = false;
    });
  }

  String htmlText = '';
  Future readHTML(String filePath) async {
    try {
      final file = File(filePath);
      htmlText = await file.readAsString(encoding: utf8);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void gotoReportView(String? filePath) async {
    //navigate to pdf view.
    await readHTML(filePath as String);
    if (!mounted) {
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (context) {
      return HTMLViewerPage(htmlText, '', filePath);
    }));
  }

  void assignProject() async {
    var usersResponse = await usersBloc.getAllUsers();

    var users = usersResponse.users.map((e) => e.username).toList();

    assignedUsers = currentProject.assignedto.toList();
    List<String> allUsers = List<String>.from(users);
    allUsers.remove(usersBloc.userDetails.username);
    showMaterialCheckboxPicker<String>(
      context: context,
      selectAllConfig: SelectAllConfig(
        const Text('Select All'),
        const Text('Deselect All'),
      ),
      title: 'Assigned Users',
      items: allUsers,
      selectedItems: assignedUsers,
      onChanged: (value) => setState(() {
        assignedUsers = value;
        //update the project assignment.
        bool result =
            realmProjServices.updateAssignment(projectId, assignedUsers);
        if (result) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Project assignment updated successfully')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
            'Failed to update the project assignment.',
          )));
        }
      }),
    );
  }
}
