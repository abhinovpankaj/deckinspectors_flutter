import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/location_bloc.dart';
import '../bloc/location_event.dart';
import '../bloc/location_state.dart';
import '../bloc/settings_bloc.dart';
import '../models/couchbase/couchbase_models.dart';
import '../resources/couchbase/location_repository.dart';
//import 'breadcrumb_navigation.dart';
import 'addedit_location.dart';
import 'cachedimage_widget.dart';
import 'showprojecttype_widget.dart';

class LocationPage extends StatefulWidget {
  final String id;
  final String userFullName;
  final String parentType;
  final String locationType;
  const LocationPage(
    this.id,
    this.parentType,
    this.locationType,
    this.userFullName, {
    super.key,
  });
  @override
  State<LocationPage> createState() => _LocationPageState();
  static MaterialPageRoute getRoute(
    String id,
    String parentType,
    String locationType,
    String userName,
    String pageName,
  ) => MaterialPageRoute(
    settings: RouteSettings(name: pageName),
    builder: (context) => LocationPage(id, parentType, locationType, userName),
  );
}

class _LocationPageState extends State<LocationPage> {
  @override
  void initState() {
    locationId = widget.id;
    parenttype = widget.parentType;
    userFullName = widget.userFullName;
    locationType = widget.locationType;
    super.initState();
  }

  String locationType = '';
  String parenttype = 'Project';
  String userFullName = "";
  late String locationId;
  late Location currentLocation;
  late List<Section> sections;
  String? formId;
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (context) => LocationBloc(
            locationRepository: RepositoryProvider.of<LocationRepository>(
              context,
            ),
          )..add(LoadLocationEvent(locationId)),
      child: BlocBuilder<LocationBloc, LocationState>(
        builder: (context, state) {
          if (state is LocationLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (state is LocationLoaded) {
            currentLocation = state.location;
            formId = currentLocation.parentid;
            return Scaffold(
              appBar: AppBar(
                automaticallyImplyLeading: false,
                leadingWidth: 120,
                leading: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.blue),
                  label: const Text(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    'Back',
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
                title: Text(
                  locationType,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    locationDetails(currentLocation),
                    locationsWidget(context),
                  ],
                ),
              ),
            );
          }

          if (state is LocationError) {
            return Scaffold(body: Center(child: Text(state.message)));
          }

          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }

  Widget locationDetails(Location currentLocation) {
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
              color: appSettings.isInvasiveMode ? Colors.orange : Colors.blue,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(8.0),
              ),
              boxShadow: const [BoxShadow(blurRadius: 1.0, color: Colors.blue)],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(8.0),
              ),
              child: cachedNetworkImage(currentLocation.url),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Text(
                currentLocation.name as String,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.left,
              ),
            ),
          ),
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Text(
                'Description',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                textAlign: TextAlign.left,
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
                      currentLocation.description as String,
                      style: const TextStyle(
                        overflow: TextOverflow.ellipsis,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                  Visibility(
                    visible: !appSettings.isInvasiveMode,
                    child: InkWell(
                      onTap: () {
                        addEditLocation(currentLocation);
                      },
                      child: const Chip(
                        avatar: Icon(Icons.edit_outlined, color: Colors.blue),
                        labelPadding: EdgeInsets.all(2),
                        label: Text(
                          'Edit',
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

  Widget locationsWidget(BuildContext context) {
    sections =
        appSettings.isInvasiveMode
            ? currentLocation.sections
                .where((element) => element.isInvasive)
                .toList()
            : currentLocation.sections.toList();
    return SizedBox(
      height: 550,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Padding(
                  padding: EdgeInsets.all(2),
                  child: Text(
                    'Locations',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Visibility(
                  visible: !appSettings.isInvasiveMode,
                  child: Align(
                    alignment: Alignment.topRight,
                    child: InkWell(
                      onTap: () {
                        addNewChild();
                      },
                      child: const Chip(
                        avatar: Icon(
                          Icons.add_circle_outline,
                          color: Colors.blue,
                        ),
                        labelPadding: EdgeInsets.all(2),
                        label: Text(
                          'Add Location',
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
                ),
              ],
            ),
            sections.isEmpty
                ? const Center(
                  child: Text(
                    'No locations to show.',
                    style: TextStyle(fontSize: 16),
                  ),
                )
                : Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    scrollDirection: Axis.horizontal,
                    itemCount: sections.length,
                    itemBuilder:
                        (BuildContext context, int index) =>
                            horizontalScrollChildren(context, index),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget horizontalScrollChildren(BuildContext context, int index) {
    String vreview = '';
    String visualReview = '';
    if (sections[index].visualreview == null) {
      visualReview = 'good';
    } else {
      visualReview = sections[index].visualreview as String;
    }

    switch (visualReview.toLowerCase()) {
      case 'good':
        vreview = 'Good';
        break;
      case 'fair':
        vreview = 'Fair';
        break;
      case 'bad':
        vreview = 'Bad';
        break;
      default:
    }
    String assessment = '';
    String? coverUrl = sections[index].coverUrl;

    String assessmentActual = '';
    if (sections[index].conditionalassessment == null) {
      assessmentActual = 'pass';
    } else {
      assessmentActual = (sections[index].conditionalassessment as String);
    }
    switch (assessmentActual.toLowerCase()) {
      case 'pass':
        assessment = 'Pass';
        break;
      case 'fail':
        assessment = 'Fail';
        break;
      case 'futureinspection':
        assessment = 'Future Inspection';
        break;
      default:
    }
    bool furtherInvasive = sections[index].furtherinvasivereviewrequired;
    //print("${sections[index].name}:${sections[index].isUploading}");
    bool visualLeaks = sections[index].visualsignsofleak;
    return SizedBox(
      width: MediaQuery.of(context).size.width - 70,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 8, 4),
        child: InkWell(
          onTap: () {
            if (appSettings.isInvasiveMode) {
              gotoInvasiveDetails(
                sections[index].id as String,
                sections[index].name as String,
              );
            } else {
              gotoDetails(
                sections[index].id as String,
                sections[index].name as String,
              );
            }
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color:
                      appSettings.isInvasiveMode ? Colors.orange : Colors.blue,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10),
                    bottom: Radius.circular(00),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: cachedNetworkImage(coverUrl),
                ),
              ),
              Card(
                shadowColor: Colors.blue,
                elevation: 8,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              overflow: TextOverflow.ellipsis,
                              sections[index].name as String,
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Visibility(
                            visible: sections[index].isuploading,
                            child: const SizedBox(
                              width: 80,
                              child: LinearProgressIndicator(
                                backgroundColor: Colors.orange,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(
                      color: Colors.grey,
                      height: 20,
                      thickness: 1,
                      indent: 15,
                      endIndent: 15,
                    ),
                    Visibility(
                      visible: formId == null,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              const Expanded(
                                flex: 1,
                                child: Text(
                                  maxLines: 1,
                                  'Visual Review',
                                  style: TextStyle(
                                    overflow: TextOverflow.ellipsis,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  vreview,
                                  style: const TextStyle(
                                    overflow: TextOverflow.ellipsis,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Visibility(
                      visible: formId == null,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              const Expanded(
                                flex: 1,
                                child: Text(
                                  maxLines: 1,
                                  'Visual signs of leak',
                                  style: TextStyle(
                                    overflow: TextOverflow.ellipsis,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  visualLeaks == true ? 'Yes' : 'No',
                                  style: const TextStyle(
                                    overflow: TextOverflow.ellipsis,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Visibility(
                      visible: formId == null,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              const Expanded(
                                flex: 1,
                                child: Text(
                                  maxLines: 1,
                                  'Further Inspection',
                                  style: TextStyle(
                                    overflow: TextOverflow.ellipsis,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  furtherInvasive == true ? 'Yes' : 'No',
                                  style: const TextStyle(
                                    overflow: TextOverflow.ellipsis,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Visibility(
                      visible: formId == null,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              const Expanded(
                                flex: 1,
                                child: Text(
                                  maxLines: 1,
                                  'Conditional assesment',
                                  style: TextStyle(
                                    overflow: TextOverflow.ellipsis,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  assessment,
                                  style: const TextStyle(
                                    overflow: TextOverflow.ellipsis,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            const Expanded(
                              flex: 1,
                              child: Text(
                                maxLines: 1,
                                'Images',
                                style: TextStyle(
                                  overflow: TextOverflow.ellipsis,
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                sections[index].count.toString(),
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void addNewChild() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add section not implemented in migration.'),
      ),
    );
  }

  void gotoDetails(String sectionId, String sectionName) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Open section not implemented in migration.'),
      ),
    );
  }

  void addEditLocation(Location currentLocation) {
    Navigator.push(
      context,
      AddEditLocationPage.getRoute(
        currentLocation,
        false,
        userFullName,
        currentLocation.name as String,
      ),
    );
  }

  void gotoInvasiveDetails(String id, String sectionName) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Open invasive section not implemented in migration.'),
      ),
    );
  }
}
