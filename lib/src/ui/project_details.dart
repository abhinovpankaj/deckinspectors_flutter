import 'dart:async' as async;
import 'dart:convert';
import 'dart:io';

import 'package:flutter_material_pickers/helpers/show_checkbox_picker.dart';
import 'package:flutter_material_pickers/models/select_all_config.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/projectdetails_bloc.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/users_bloc.dart';
import '../models/couchbase/couchbase_models.dart';
import '../models/error_response.dart';
import '../models/success_response.dart';
import '../resources/couchbase/project_repository.dart';
import '../resources/couchbase/subproject_repository.dart';
import '../resources/couchbase/location_repository.dart';
import '../resources/repository.dart';
import 'addedit_subproject.dart';
import 'cachedimage_widget.dart';
import 'htmlviewer.dart';
import 'location.dart';
import 'package:flutter/material.dart';
import 'addedit_project.dart';
import 'addedit_location.dart';
import 'showprojecttype_widget.dart';
import 'subproject.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class ProjectDetailsPage extends StatefulWidget {
  final String id;
  final String userFullName;
  final bool isInvasiveMode;
  const ProjectDetailsPage({
    required this.id,
    required this.userFullName,
    required this.isInvasiveMode,
    super.key,
  });

  @override
  State<ProjectDetailsPage> createState() => _ProjectDetailsPageState();

  static MaterialPageRoute getRoute(
    String id,
    String userName,
    bool isInvasive,
    String pageName,
  ) => MaterialPageRoute(
    settings: RouteSettings(name: pageName),
    builder:
        (context) => BlocProvider(
          create:
              (_) => ProjectDetailsBloc(
                projectRepository: context.read<ProjectRepository>(),
                subprojectRepository: context.read<SubprojectRepository>(),
                locationRepository: context.read<LocationRepository>(),
                globalRepository: context.read<Repository>(),
              )..add(LoadProjectDetails(id)),
          child: ProjectDetailsPage(
            id: id,
            userFullName: userName,
            isInvasiveMode: isInvasive,
          ),
        ),
  );
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
  late String projectId;
  List<String> assignedUsers = [];
  Location getNewLocation() {
    return Location(
      parentid: projectId,
      isInvasive: false,
      name: "",
      description: "",
      url: "",
      createdby: userFullName,
      type: 'projectlocation',
      parenttype: 'project',
    );
  }

  SubProject getNewBuilding() {
    return SubProject(
      parentid: projectId,
      isInvasive: false,
      name: "",
      description: "",
      url: "",
      createdby: userFullName,
      type: 'subproject',
    );
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
      if (isInvasiveMode) {
        locations =
            currentProject.children
                .where(
                  (element) =>
                      element.type == 'projectlocation' && element.isInvasive,
                )
                .toList();
        buildings =
            currentProject.children
                .where(
                  (element) =>
                      element.type == 'subproject' && element.isInvasive,
                )
                .toList();
      } else {
        locations =
            currentProject.children
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
        buildings =
            currentProject.children
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
    Navigator.push(
      context,
      AddEditProjectPage.getRoute(currentProject, false, userFullName),
    ).then((value) {
      // If the project was deleted in the Add/Edit page, it will return `true`.
      if (value == true) {
        // Pop this ProjectDetails page and signal parent to refresh list.
        Navigator.pop(context, true);
        return;
      }

      final bloc = context.read<ProjectDetailsBloc>();
      bloc.add(LoadProjectDetails(currentProject.id as String));
    });
  }

  void addNewChild(String name) {
    //setState(() {});
    if (selectedTabIndex == 1) {
      final locationRepo = RepositoryProvider.of<LocationRepository>(context);
      Navigator.push(
        context,
        AddEditLocationPage.getRoute(
          getNewLocation(),
          true,
          userFullName,
          name,
          locationRepository: locationRepo,
        ),
      ).then((value) {
        try {
          context.read<ProjectDetailsBloc>().add(LoadProjectDetails(projectId));
        } catch (_) {}
      });
    } else {
      final subprojectRepo = RepositoryProvider.of<SubprojectRepository>(
        context,
      );
      Navigator.push(
        context,
        AddEditSubProjectPage.getRoute(
          getNewBuilding(),
          true,
          userFullName,
          name,
          subprojectRepository: subprojectRepo,
        ),
      ).then((value) {
        try {
          context.read<ProjectDetailsBloc>().add(LoadProjectDetails(projectId));
        } catch (_) {}
      });
    }
  }

  void gotoDetails(String id, String name, String pageName) {
    if (selectedTabIndex == 1) {
      Navigator.push(
        context,
        LocationPage.getRoute(
          id,
          name,
          'Project Locations',
          userFullName,
          pageName,
        ),
      ).then((value) {
        setState(() => {});
      });
    } else {
      Navigator.push(
        context,
        SubProjectDetailsPage.getRoute(id, name, userFullName, pageName),
      ).then((value) {
        setState(() => {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 140,
        leading: ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.blue),
          label: const Text('Home', style: TextStyle(color: Colors.blue)),
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
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.normal),
        ),
      ),
      // floatingActionButton: Padding(
      //   padding: const EdgeInsets.fromLTRB(20, 0, 0, 0),
      //   child: BreadCrumbNavigator(),
      // ),
      body: BlocListener<ProjectDetailsBloc, ProjectDetailsState>(
        listener: (context, state) {
          if (state is ProjectDetailsSaved) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Project assignment updated successfully'),
              ),
            );
          } else if (state is ProjectDetailsError) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        child: BlocBuilder<ProjectDetailsBloc, ProjectDetailsState>(
          builder: (context, state) {
            if (state is ProjectDetailsLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is ProjectDetailsLoaded) {
              currentProject = state.project;
              usersBloc.currentFormId = currentProject.formId;

              if (isInvasiveMode) {
                locations =
                    currentProject.children
                        .where(
                          (element) =>
                              element.type == 'projectlocation' &&
                              element.isInvasive,
                        )
                        .toList();

                buildings =
                    currentProject.children
                        .where(
                          (element) =>
                              element.type == 'subproject' &&
                              element.isInvasive,
                        )
                        .toList();
              } else {
                locations =
                    currentProject.children
                        .where((element) => element.type == 'projectlocation')
                        .toList();

                buildings =
                    currentProject.children
                        .where((element) => element.type == 'subproject')
                        .toList();
              }

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

              var shortDate = DateTime.tryParse(currentProject.createdat ?? '');
              if (shortDate != null) {
                createdAt = DateFormat.yMMMEd().format(shortDate);
              } else {
                createdAt = "";
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    projectDetails(
                      currentProject.name ?? '',
                      currentProject.url ?? '',
                      currentProject.id as String,
                      currentProject.description ?? '',
                      currentProject.editedat ?? '',
                      currentProject.address ?? '',
                    ),
                    projectChildrenTab(context),
                  ],
                ),
              );
            }

            if (state is ProjectDetailsError) {
              return Center(child: Text(state.message));
            }

            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }

  getCustomFormattedDateTime(String givenDateTime, String dateFormat) {
    // dateFormat = 'MM/dd/yy';
    final DateTime docDateTime = DateTime.parse(givenDateTime);
    return DateFormat(dateFormat).format(docDateTime);
  }

  Future<Coords?> _getCurrentCoords() async {
    try {
      // Check if location services are enabled.
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
        return null;
      }

      // Check and request permission if needed.
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied.')),
          );
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permissions are permanently denied. Enable from settings.',
            ),
          ),
        );
        return null;
      }

      if (Platform.isIOS) {
        final LocationAccuracyStatus accuracyStatus =
            await Geolocator.getLocationAccuracy();
        if (accuracyStatus == LocationAccuracyStatus.reduced) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Precise Location is off. Enable it in iOS Settings for better navigation.',
              ),
            ),
          );
          return null;
        }
      }

      // Get current position
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      return Coords(position.latitude, position.longitude);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to get current location: ${e.toString()}'),
        ),
      );
      return null;
    }
  }

  // Start navigation in external maps app. Tries platform-specific URL schemes
  // that start turn-by-turn navigation. Falls back to web URLs.
  Future<void> _startNavigation(double lat, double lng) async {
    try {
      if (await MapLauncher.isMapAvailable(MapType.apple) ?? false) {
        await MapLauncher.showDirections(
          mapType: MapType.apple,
          destination: Coords(lat, lng),
        );
      } else if (await MapLauncher.isMapAvailable(MapType.google) ?? false) {
        await MapLauncher.showDirections(
          mapType: MapType.google,
          destination: Coords(lat, lng),
        );
      } else {
        // Fallback to URL-based navigation
        final Uri googleMapsUrl = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
        );
        if (await canLaunchUrl(googleMapsUrl)) {
          await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
          return;
        }

        final Uri appleMapsUrl = Uri.parse('maps://?daddr=$lat,$lng&dirflg=d');
        if (await canLaunchUrl(appleMapsUrl)) {
          await launchUrl(appleMapsUrl, mode: LaunchMode.externalApplication);
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No supported map applications are available.'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to launch navigation: ${e.toString()}')),
      );
    }
  }

  Widget projectDetails(
    String name,
    String url,
    String id,
    String description,
    String editedat,
    String address,
  ) {
    // Realm services removed; repository used for data operations.
    return Padding(
      padding: const EdgeInsets.all(0.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          const ProjectType(),
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: isInvasiveMode ? Colors.orange : Colors.blue,
              // image: networkImage(currentProject.url as String),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(8.0),
              ),
              boxShadow: const [BoxShadow(blurRadius: 1.0, color: Colors.blue)],
            ),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(8.0),
                  ),
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
                    elevation: 1,
                  ),
                  onPressed: () async {
                    final address = currentProject.address;
                    if (address == null || address.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Address is empty, please add address to navigate.',
                          ),
                        ),
                      );
                      return;
                    }

                    try {
                      double lat;
                      double lng;

                      try {
                        final List<geocoding.Location> geoLocations =
                            await geocoding.locationFromAddress(address);
                        if (geoLocations.isNotEmpty) {
                          lat = geoLocations.first.latitude;
                          lng = geoLocations.first.longitude;
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Unable to find coordinates for this address.',
                              ),
                            ),
                          );
                          return;
                        }
                      } on geocoding.NoResultFoundException {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('No location found for: $address'),
                          ),
                        );
                        return;
                      } catch (_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Geocoding failed. Please check the address.',
                            ),
                          ),
                        );
                        return;
                      }

                      final coords = Coords(lat, lng);

                      // Get current device location to use as navigation origin.
                      final Coords? originCoords = await _getCurrentCoords();

                      await _startNavigation(
                        coords.latitude,
                        coords.longitude,
                        //origin: originCoords,
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Navigation error: ${e.toString()}'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(
                    Icons.location_pin,
                    color: Colors.blueAccent,
                  ),
                  label: const Text(
                    'Navigate',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
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
                        avatar: Icon(Icons.edit_outlined, color: Colors.blue),
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
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  Visibility(
                    visible: !isInvasiveMode,
                    child: InkWell(
                      onTap: () {
                        assignProject();
                      },
                      child: const Chip(
                        avatar: Icon(
                          Icons.account_circle_outlined,
                          color: Colors.blue,
                        ),
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
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
                    style: TextStyle(fontSize: 14),
                    textAlign: TextAlign.left,
                  ),
                  //remove project download option
                  isInvasiveMode
                      ? PopupMenuButton(
                        child: Chip(
                          avatar:
                              isDownloading
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                    ),
                                  )
                                  : const Icon(
                                    Icons.file_download_done_outlined,
                                    color: Colors.blue,
                                  ),
                          labelPadding: const EdgeInsets.all(2),
                          label: const Text(
                            'Download Report',
                            style: TextStyle(color: Colors.blue, fontSize: 15),
                          ),
                          shadowColor: Colors.transparent,
                          backgroundColor: Colors.transparent,
                          elevation: 10,
                          autofocus: true,
                        ),
                        onSelected: (value) {
                          _onMenuItemSelected(value as int);
                        },
                        itemBuilder:
                            (ctx) => [
                              _buildPopupMenuItem(
                                'Invasive',
                                Icons.edit_document,
                                1,
                              ),
                              _buildPopupMenuItem(
                                'Invasive Only',
                                Icons.browse_gallery_outlined,
                                2,
                              ),
                            ],
                      )
                      : InkWell(
                        onTap: () {
                          isDownloading
                              ? null
                              : downloadProjectReport(id, 'Visual');
                        },
                        child: Chip(
                          avatar:
                              isDownloading
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                    ),
                                  )
                                  : const Icon(
                                    Icons.file_download_done_outlined,
                                    color: Colors.blue,
                                  ),
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
                        ),
                      ),
                ],
              ),
            ),
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
              ),
            ),
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
    String title,
    IconData iconData,
    int position,
  ) {
    return PopupMenuItem(
      value: position,
      child: Row(
        children: [
          Icon(iconData, color: Colors.blue),
          const SizedBox(width: 15),
          Text(title),
        ],
      ),
    );
  }

  _onMenuItemSelected(int value) async {
    if (value == 1) {
      downloadProjectReport(currentProject.id as String, 'Invasive');
    } else {
      downloadProjectReport(currentProject.id as String, 'InvasiveOnly');
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
            Tab(text: "Buildings (${buildings.length})", height: 32),
            Tab(text: "Project Locations (${locations.length})", height: 32),
          ],
          labelColor: Colors.black,
        ),
        SizedBox(
          height: 250,
          child: TabBarView(
            controller: _tabController,
            children: [
              locationsWidget('building'),
              locationsWidget('location'),
            ],
          ),
        ),
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
                    style: const TextStyle(color: Colors.blue, fontSize: 15),
                    selectionColor: Colors.transparent,
                  ),
                  shadowColor: Colors.white,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  autofocus: true,
                ),
              ),
            ),
          ),
          isEmpty
              ? Center(
                child: Text(
                  'No $type, Add project $type.',
                  style: const TextStyle(fontSize: 16),
                ),
              )
              : type == 'location'
              ? Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  scrollDirection: Axis.horizontal,
                  itemCount: locations.length,
                  itemBuilder: (BuildContext context, int index) {
                    return horizontalScrollChildren(context, index);
                  },
                ),
              )
              : Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  scrollDirection: Axis.horizontal,
                  itemCount: buildings.length,
                  itemBuilder: (BuildContext context, int index) {
                    return horizontalScrollChildrenBuildings(context, index);
                  },
                ),
              ),
        ],
      ),
    );
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
                  locations[index]!.id as String,
                  currentProject.name as String,
                  locations[index]!.name as String,
                );
              },
              child: Container(
                height: 140,
                width: 192,
                decoration: BoxDecoration(
                  color: isInvasiveMode ? Colors.orange : Colors.blue,
                  // image: networkImage(currentProject.url as String),
                  borderRadius: const BorderRadius.all(Radius.circular(8.0)),
                  boxShadow: const [
                    BoxShadow(blurRadius: 1.0, color: Colors.blue),
                  ],
                ),
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
                  buildings[index]!.id as String,
                  currentProject.name as String,
                  buildings[index]!.name as String,
                );
              },
              child: Container(
                height: 140,
                width: 192,
                decoration: BoxDecoration(
                  color: isInvasiveMode ? Colors.orange : Colors.blue,
                  // image: networkImage(currentProject.url as String),
                  borderRadius: const BorderRadius.all(Radius.circular(8.0)),
                  boxShadow: const [
                    BoxShadow(blurRadius: 1.0, color: Colors.blue),
                  ],
                ),
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool isDownloading = false;
  void downloadProjectReport(String id, String reportType) async {
    setState(() {
      isDownloading = true;
    });
    final repo = RepositoryProvider.of<Repository>(context);
    var result = await repo.downloadProjectReport(
      currentProject.name as String,
      id,
      'pdf',
      appSettings.reportImageQuality,
      appSettings.imageinRowCount,
      reportType,
      appSettings.companyName,
    );
    if (!mounted) {
      return;
    }
    if (result is ErrorResponse) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to download the report, please try again.${result.message}',
          ),
        ),
      );
    } else if (result is SuccessResponse) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Report downloaded successfully.'),
          action: SnackBarAction(
            label: 'View Report',
            onPressed: () => gotoReportView(result.message),
          ),
        ),
      );
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return HTMLViewerPage(htmlText, '', filePath);
        },
      ),
    );
  }

  void assignProject() async {
    var usersResponse = await usersBloc.getAllUsers();

    var users = usersResponse.users.map((e) => e.username).toList();

    assignedUsers = currentProject.assignedto.toList();
    List<String> allUsers = List<String>.from(users);
    allUsers.remove(usersBloc.userDetails.username);
    var projectDetailsbloc = context.read<ProjectDetailsBloc>();
    showMaterialCheckboxPicker<String>(
      context: context,
      selectAllConfig: SelectAllConfig(
        const Text('Select All'),
        const Text('Deselect All'),
      ),
      title: 'Assigned Users',
      items: allUsers,
      selectedItems: assignedUsers,
      onChanged:
          (value) => setState(() {
            assignedUsers = value;
            projectDetailsbloc.add(
              UpdateProjectAssignment(
                projectId: projectId,
                assignees: assignedUsers,
              ),
            );
          }),
    );
  }
}
