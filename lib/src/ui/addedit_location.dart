import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/location_bloc.dart';
import '../bloc/location_event.dart';
import '../bloc/location_state.dart';
import '../models/couchbase/couchbase_models.dart';
import '../resources/couchbase/location_repository.dart';
import 'cachedimage_widget.dart';
import 'capture_image.dart';
import 'location.dart';

class AddEditLocationPage extends StatefulWidget {
  final Location currentLocation;
  final String fullUserName;
  final bool isNewLocation;
  final String prevPageName;
  // final Object currentBuilding;
  const AddEditLocationPage(
    this.currentLocation,
    this.isNewLocation,
    this.fullUserName,
    this.prevPageName, {
    super.key,
  });

  @override
  State<AddEditLocationPage> createState() => _AddEditLocationPageState();

  static MaterialPageRoute getRoute(
    Location location,
    bool isNew,
    String userName,
    String prevPage, {
    required LocationRepository locationRepository,
  }) {
    return MaterialPageRoute(
      settings: RouteSettings(name: isNew ? 'Add Location' : 'Edit Location'),
      builder: (context) {
        return RepositoryProvider<LocationRepository>.value(
          value: locationRepository,
          child: BlocProvider(
            create: (_) => LocationBloc(locationRepository: locationRepository),
            child: AddEditLocationPage(location, isNew, userName, prevPage),
          ),
        );
      },
    );
  }
}

class _AddEditLocationPageState extends State<AddEditLocationPage> {
  late String fullUserName;
  late TextEditingController _nameController;

  late TextEditingController _descriptionController;
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();

    super.dispose();
  }

  bool showAssetPic = true;
  @override
  void initState() {
    currentLocation = widget.currentLocation;
    fullUserName = widget.fullUserName;

    super.initState();
    pageType = currentLocation.type == 'apartment' ? 'Apartment' : 'Location';

    _nameController = TextEditingController(
      text: widget.isNewLocation ? "" : (currentLocation.name ?? ""),
    );
    _descriptionController = TextEditingController(
      text: widget.isNewLocation ? "" : (currentLocation.description ?? ""),
    );
    if (!widget.isNewLocation) {
      pageTitle = 'Edit $pageType';
      isNewLocation = false;
      showAssetPic = false;
      _nameController.text = currentLocation.name as String;
      _descriptionController.text = currentLocation.description as String;
      //currentLocation.url ??= "/assets/images/icon.png";
    } else {
      pageTitle = 'Add $pageType';
    }
    if (currentLocation.url != null) {
      imageURL = currentLocation.url as String;
    }
    prevPagename = widget.prevPageName;
    //initSpeech();
  }

  late Location currentLocation;

  String pageType = '';
  String pageTitle = 'Add';
  String prevPagename = 'Project';
  bool isNewLocation = true;
  final _formKey = GlobalKey<FormState>();
  String imageURL = 'assets/images/icon.png';

  void saveWithBloc(BuildContext context) {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text;
      final description = _descriptionController.text;
      // Update currentLocation with new values
      currentLocation.name = name;
      currentLocation.description = description;

      context.read<LocationBloc>().add(
        SaveLocationEvent(
          location: currentLocation,
          name: name,
          isNew: isNewLocation,
          fullUserName: fullUserName,
          description: description,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LocationBloc, LocationState>(
      listener: (context, state) {
        if (state is LocationSaveSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$pageType saved successfully.')),
          );
          if (isNewLocation) {
            final locationRepo = RepositoryProvider.of<LocationRepository>(
              context,
            );
            Navigator.pushReplacement(
              context,
              LocationPage.getRoute(
                currentLocation.id as String,
                currentLocation.parenttype,
                pageType,
                fullUserName,
                currentLocation.name as String,
                locationRepository: locationRepo,
              ),
            );
          } else {
            Navigator.pop(context, true);
          }
        } else if (state is LocationSaveFailure) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.error)));
        } else if (state is LocationDeleteSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$pageType deleted successfully.')),
          );
          Navigator.of(context)
            ..pop()
            ..pop(currentLocation);
        } else if (state is LocationDeleteFailure) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.error)));
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leadingWidth: 120,
          leading: ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.blue),
            label: const Text(
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
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
          actions: [
            InkWell(
              onTap: () {
                saveWithBloc(context);
              },
              child: const Chip(
                avatar: Icon(Icons.save_outlined, color: Colors.black),
                labelPadding: EdgeInsets.all(2),
                label: Text(
                  'Save',
                  style: TextStyle(color: Colors.black),
                  selectionColor: Colors.white,
                ),
                shadowColor: Colors.blue,
                backgroundColor: Colors.blue,
                elevation: 10,
                autofocus: true,
              ),
            ),
          ],
          title: Text(
            pageTitle,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
        body: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * .9,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pageType),
                    const SizedBox(height: 8),
                    inputWidgetwithValidation(
                      '$pageType name',
                      'Please enter {currentLocation.type} name',
                    ),
                    const SizedBox(height: 16),
                    const Text('Description'),
                    const SizedBox(height: 8),
                    inputWidgetNoValidation('Description', 3),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide.none,
                        minimumSize: const Size.fromHeight(40),
                        backgroundColor: Colors.white,
                        shadowColor: Colors.blue,
                        elevation: 0,
                      ),
                      onPressed: () async {
                        showAssetPic = false;
                        var xfile = await captureImage(context);
                        if (xfile != null) {
                          setState(() {
                            imageURL = xfile.path;
                          });
                        }
                      },
                      icon: const Icon(
                        Icons.camera_outlined,
                        color: Colors.blueAccent,
                      ),
                      label: const Text(
                        'Add image',
                        style: TextStyle(color: Colors.blueAccent),
                      ),
                    ),
                    SizedBox(
                      height: 220,
                      child: Card(
                        borderOnForeground: false,
                        elevation: 4,
                        child: GestureDetector(
                          onTap: () async {
                            showAssetPic = false;
                            var xfile = await captureImage(context);
                            if (xfile != null) {
                              setState(() {
                                imageURL = xfile.path;
                              });
                            }
                          },
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.all(
                                Radius.circular(8.0),
                              ),
                              boxShadow: [
                                BoxShadow(blurRadius: 1.0, color: Colors.blue),
                              ],
                            ),
                            child:
                                showAssetPic
                                    ? currentLocation.url == ""
                                        ? Image.asset(
                                          "assets/images/icon.png",
                                          fit: BoxFit.fill,
                                          width: double.infinity,
                                          height: 250,
                                        )
                                        : Image.file(
                                          File(imageURL),
                                          fit: BoxFit.fill,
                                          width: double.infinity,
                                          height: 250,
                                        )
                                    : cachedNetworkImage(imageURL),
                          ),
                        ),
                      ),
                    ),
                    if (!isNewLocation)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide.none,
                          minimumSize: const Size.fromHeight(40),
                          backgroundColor: Colors.white,
                          shadowColor: Colors.blue,
                          elevation: 0,
                        ),
                        onPressed: () {
                          context.read<LocationBloc>().add(
                            DeleteLocationEvent(currentLocation),
                          );
                        },
                        icon: const Icon(
                          Icons.delete_outline_outlined,
                          color: Colors.redAccent,
                        ),
                        label: Text(
                          'Delete $pageType',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget inputWidgetwithValidation(String hint, String message) {
    return TextFormField(
      controller: _nameController,
      // The validator receives the text that the user has entered.
      validator: (value) {
        if (value == null || value.isEmpty) {
          return message;
        }
        return null;
      },
      maxLines: 1,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 14.0,
          color: Color(0xFFABB3BB),
          height: 1.0,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget inputWidgetNoValidation(String hint, int? lines) {
    return TextField(
      controller: _descriptionController,

      // The validator receives the text that the user has entered.
      maxLines: lines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 14.0,
          color: Color(0xFFABB3BB),
          height: 1.0,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // deleteLocation logic is now handled by LocationBloc and BlocListener
}
