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
import 'app_theme.dart';
import 'breadcrumb_navigation.dart';
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
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new),
          tooltip: 'Back',
        ),
        title: BlocBuilder<ProjectDetailsBloc, ProjectDetailsState>(
          buildWhen: (_, state) => state is ProjectDetailsLoaded,
          builder: (context, state) {
            if (state is ProjectDetailsLoaded) {
              return Text(
                state.project.name ?? 'Project',
                style: AppTextStyles.titleLarge,
                overflow: TextOverflow.ellipsis,
              );
            }
            return Text('Project', style: AppTextStyles.titleLarge);
          },
        ),
        actions: [
          if (!isInvasiveMode)
            IconButton(
              onPressed: addEditProject,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Project',
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: BreadCrumbNavigator(),
        ),
      ),
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
  Future<void> _startNavigation(
    double lat,
    double lng, {
    Coords? origin,
  }) async {
    try {
      final String originParam =
          origin != null ? '${origin.latitude},${origin.longitude}' : '';

      if (Platform.isAndroid) {
        // Google Maps navigation intent always starts from current location.
        final Uri googleNav = Uri.parse('google.navigation:q=$lat,$lng');
        if (await canLaunchUrl(googleNav)) {
          await launchUrl(googleNav, mode: LaunchMode.externalApplication);
          return;
        }

        // Fallback to Google Maps web directions with explicit origin.
        final String originQuery =
            originParam.isNotEmpty ? '&origin=$originParam' : '';
        final Uri googleWeb = Uri.parse(
          'https://www.google.com/maps/dir/?api=1$originQuery&destination=$lat,$lng&travelmode=driving',
        );
        if (await canLaunchUrl(googleWeb)) {
          await launchUrl(googleWeb, mode: LaunchMode.externalApplication);
          return;
        }
      } else if (Platform.isIOS) {
        // Apple Maps: saddr=current location, daddr=destination.
        final String saddr =
            originParam.isNotEmpty
                ? 'saddr=$originParam&'
                : 'saddr=Current+Location&';
        final Uri appleMaps = Uri.parse(
          'maps://?${saddr}daddr=$lat,$lng&dirflg=d',
        );
        if (await canLaunchUrl(appleMaps)) {
          await launchUrl(appleMaps, mode: LaunchMode.externalApplication);
          return;
        }

        // Google Maps on iOS: empty saddr means current location.
        final String googleSaddr =
            originParam.isNotEmpty ? 'saddr=$originParam&' : 'saddr=&';
        final Uri googleIos = Uri.parse(
          'comgooglemaps://?${googleSaddr}daddr=$lat,$lng&directionsmode=driving',
        );
        if (await canLaunchUrl(googleIos)) {
          await launchUrl(googleIos, mode: LaunchMode.externalApplication);
          return;
        }

        // Fallback to Apple Maps web with explicit origin.
        final String appleOrigin =
            originParam.isNotEmpty ? 'saddr=$originParam&' : '';
        final Uri appleWeb = Uri.parse(
          'https://maps.apple.com/?${appleOrigin}daddr=$lat,$lng&dirflg=d',
        );
        if (await canLaunchUrl(appleWeb)) {
          await launchUrl(appleWeb, mode: LaunchMode.externalApplication);
          return;
        }
      }

      // Generic fallback: Google Maps web with explicit origin.
      final String originQuery =
          originParam.isNotEmpty ? '&origin=$originParam' : '';
      final Uri fallback = Uri.parse(
        'https://www.google.com/maps/dir/?api=1$originQuery&destination=$lat,$lng&travelmode=driving',
      );
      if (await canLaunchUrl(fallback)) {
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No available maps application to launch navigation.'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error launching navigation: ${e.toString()}')),
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
              color: isInvasiveMode ? AppColors.warning : AppColors.primary,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12.0),
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 4.0,
                  color: AppColors.primary.withAlpha(60),
                ),
              ],
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
                        origin: originCoords,
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
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headlineMedium,
                      textAlign: TextAlign.left,
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
                  Row(
                    children: [
                      const Icon(
                        Icons.edit_outlined,
                        size: 13,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Edited ${getCustomFormattedDateTime(editedat, 'MM/dd/yy hh:mm')}',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                  if (!isInvasiveMode)
                    TextButton.icon(
                      onPressed: assignProject,
                      icon: const Icon(Icons.people_outline, size: 16),
                      label: const Text('Assign'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        textStyle: AppTextStyles.labelMedium.copyWith(
                          fontWeight: FontWeight.w600,
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
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Description',
                    style: AppTextStyles.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
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
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.left,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1),
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
            Tab(
              height: 44,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.business_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text('Buildings (${buildings.length})'),
                ],
              ),
            ),
            Tab(
              height: 44,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.place_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text('Locations (${locations.length})'),
                ],
              ),
            ),
          ],
        ),
        SizedBox(
          height: 270,
          child: TabBarView(
            controller: _tabController,
            children: [
              locationsWidget('building'),
              locationsWidget('location'),
            ],
          ),
        ),
      ],
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
              child: TextButton.icon(
                onPressed: () => addNewChild(currentProject.name as String),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: Text('Add $type'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
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
      width: MediaQuery.of(context).size.width * 0.52,
      height: 210,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: GestureDetector(
          onTap: () {
            gotoDetails(
              locations[index]!.id as String,
              currentProject.name as String,
              locations[index]!.name as String,
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: [
                BoxShadow(
                  blurRadius: 4,
                  color: Colors.black.withAlpha(12),
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: SizedBox(
                    height: 140,
                    width: double.infinity,
                    child:
                        (locations[index]!.url != null &&
                                locations[index]!.url!.isNotEmpty)
                            ? cachedNetworkImage(locations[index]!.url)
                            : Container(
                              color: AppColors.primary.withAlpha(30),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.place_outlined,
                                size: 40,
                                color: AppColors.primary,
                              ),
                            ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
                  child: Text(
                    locations[index]!.name as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titleMedium,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                  child: Text(
                    locations[index]!.description as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget horizontalScrollChildrenBuildings(BuildContext context, int index) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.52,
      height: 210,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: GestureDetector(
          onTap: () {
            gotoDetails(
              buildings[index]!.id as String,
              currentProject.name as String,
              buildings[index]!.name as String,
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: [
                BoxShadow(
                  blurRadius: 4,
                  color: Colors.black.withAlpha(12),
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: SizedBox(
                    height: 140,
                    width: double.infinity,
                    child:
                        (buildings[index]!.url != null &&
                                buildings[index]!.url!.isNotEmpty)
                            ? cachedNetworkImage(buildings[index]!.url)
                            : Container(
                              color: AppColors.accent.withAlpha(30),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.business_outlined,
                                size: 40,
                                color: AppColors.accent,
                              ),
                            ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
                  child: Text(
                    buildings[index]!.name as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titleMedium,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                  child: Text(
                    buildings[index]!.description as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              ],
            ),
          ),
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
