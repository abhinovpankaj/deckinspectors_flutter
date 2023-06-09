import 'dart:io';
import 'package:deckinspectors/src/ui/cachedimage_widget.dart';
import 'package:flutter/material.dart';
import '../bloc/images_bloc.dart';
import '../bloc/locations_bloc.dart';
import '../models/location_model.dart';
import '../models/success_response.dart';
import 'capture_image.dart';
import 'image_widget.dart';

class AddEditLocationPage extends StatefulWidget {
  final Location currentLocation;
  final String fullUserName;
  // final Object currentBuilding;
  const AddEditLocationPage(this.currentLocation, this.fullUserName, {Key? key})
      : super(key: key);

  @override
  State<AddEditLocationPage> createState() => _AddEditLocationPageState();
}

class _AddEditLocationPageState extends State<AddEditLocationPage> {
  late String fullUserName;
  final TextEditingController _nameController = TextEditingController(text: '');

  final TextEditingController _descriptionController =
      TextEditingController(text: '');

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    currentLocation = widget.currentLocation;
    fullUserName = widget.fullUserName;

    super.initState();
    pageType = currentLocation.type == 'apartment' ? 'Apartment' : 'Location';
    if (currentLocation.id != null) {
      pageTitle = 'Edit $pageType';
      isNewLocation = false;
      _nameController.text = currentLocation.name as String;
      _descriptionController.text = currentLocation.description as String;
      //currentLocation.url ??= "/assets/images/icon.png";
      if (currentLocation.url != null) {
        imageURL = currentLocation.url as String;
      }
      prevPagename =
          currentLocation.parenttype == 'subproject' ? 'Building' : 'Location';
    } else {
      pageTitle = 'Add $pageType';
      prevPagename =
          currentLocation.parenttype == 'subproject' ? 'Building' : 'Project';
    }
  }

  late Location currentLocation;

  String pageType = '';
  String pageTitle = 'Add';
  String prevPagename = 'Project';
  bool isNewLocation = true;
  final _formKey = GlobalKey<FormState>();
  String imageURL = 'assets/images/icon.png';
  save(BuildContext context) async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState!.validate()) {
      // If the form is valid, display a snackbar. In the real world,
      // you'd often call a server or save the information in a database.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saving $pageType...')),
      );
      currentLocation.name = _nameController.text;

      currentLocation.description = _descriptionController.text;
      if (isNewLocation) {
        currentLocation.createdby = fullUserName;
      } else {
        currentLocation.lasteditedby = fullUserName;
      }

      try {
        Object result;
        if (currentLocation.id == null) {
          result = await locationsBloc.addLocation(currentLocation);
          if (result is SuccessResponse) {
            currentLocation.id = result.id;
          }
        } else {
          result = await locationsBloc.updateLocation(currentLocation);
        }

        dynamic uploadResult;
        if (imageURL != currentLocation.url) {
          uploadResult = await imagesBloc.uploadImage(
              currentLocation.url as String,
              currentLocation.name as String,
              fullUserName,
              currentLocation.id as String,
              currentLocation.parenttype as String,
              currentLocation.type as String);
          // if (uploadResult is ImageResponse) {
          //   setState(() {
          //     currentLocation.url = uploadResult.url;
          //   });
          // }
        }

        if (!mounted) {
          return;
        }
        if (result is SuccessResponse) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$pageType saved successfully.')));
          if (uploadResult is ImageResponse) {
            setState(() {
              currentLocation.url = uploadResult.url;
            });
          }
          Navigator.pop(context, currentLocation.url);
          // Navigator.pushReplacement(
          //     context,
          //     MaterialPageRoute(
          //         builder: (context) =>
          //             ProjectDetailsPage(currentLocation.parentid as String, fullUserName)));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Failed to save the ${currentLocation.type}')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to save the ${currentLocation.type} ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            automaticallyImplyLeading: false,
            leadingWidth: 120,
            leading: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(
                Icons.arrow_back_ios,
                color: Colors.blue,
              ),
              label: Text(
                prevPagename,
                style: const TextStyle(color: Colors.blue),
              ),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: Colors.transparent,
              ),
            ),
            backgroundColor: Colors.white,
            foregroundColor: Colors.blue,
            elevation: 0,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  pageTitle,
                  style: const TextStyle(
                      color: Colors.black, fontWeight: FontWeight.normal),
                ),
                InkWell(
                    onTap: () {
                      save(context);
                    },
                    child: Chip(
                      avatar: const Icon(
                        Icons.save_outlined,
                        color: Colors.black,
                      ),
                      labelPadding: const EdgeInsets.all(2),
                      label: Text(
                        'Save $pageType',
                        style: const TextStyle(color: Colors.black),
                        selectionColor: Colors.white,
                      ),
                      shadowColor: Colors.blue,
                      backgroundColor: Colors.blue,
                      elevation: 10,
                      autofocus: true,
                    )),
              ],
            )),
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
                      const SizedBox(
                        height: 8,
                      ),
                      inputWidgetwithValidation('$pageType name',
                          'Please enter ${currentLocation.type} name'),
                      const SizedBox(
                        height: 16,
                      ),
                      const Text('Description'),
                      const SizedBox(
                        height: 8,
                      ),

                      inputWidgetNoValidation('Description', 3),

                      const SizedBox(
                        height: 16,
                      ),

                      SizedBox(
                          height: 220,
                          child: Card(
                            borderOnForeground: false,
                            elevation: 4,
                            child: GestureDetector(
                                onTap: () async {
                                  //add logic to open camera.
                                  var xfile = await captureImage(context);
                                  if (xfile != null) {
                                    setState(() {
                                      currentLocation.url = xfile.path;
                                    });
                                  }
                                },
                                child: Stack(
                                  alignment: Alignment.bottomCenter,
                                  children: [
                                    Container(
                                      decoration: const BoxDecoration(
                                          color: Colors.orange,
                                          borderRadius: BorderRadius.all(
                                              Radius.circular(8.0)),
                                          boxShadow: [
                                            BoxShadow(
                                                blurRadius: 1.0,
                                                color: Colors.blue)
                                          ]),
                                      child: isNewLocation
                                          ? currentLocation.url == null
                                              ? networkImage(
                                                  currentLocation.url)
                                              : Image.file(
                                                  File(currentLocation.url
                                                      as String),
                                                  fit: BoxFit.fill,
                                                  width: double.infinity,
                                                  height: 250,
                                                )
                                          : cachedNetworkImage(
                                              currentLocation.url),
                                    ),
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: const [
                                        Icon(Icons.camera_outlined,
                                            size: 40, color: Colors.black),
                                        Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text(
                                            'Add Image',
                                            style: TextStyle(
                                                color: Colors.blue,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15),
                                          ),
                                        )
                                      ],
                                    )
                                  ],
                                )),
                          )),
                      if (!isNewLocation)
                        OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                                side: BorderSide.none,
                                // the height is 50, the width is full
                                minimumSize: const Size.fromHeight(40),
                                backgroundColor: Colors.white,
                                shadowColor: Colors.blue,
                                elevation: 0),
                            onPressed: () {
                              deleteLocation(context);
                            },
                            icon: const Icon(
                              Icons.delete_outline_outlined,
                              color: Colors.redAccent,
                            ),
                            label: Text(
                              'Delete $pageType',
                              style: const TextStyle(color: Colors.red),
                            )),
                      const SizedBox(
                        height: 40,
                      )
                      // Padding(

                      //   padding: const EdgeInsets.symmetric(vertical: 16.0),
                      //   child: ElevatedButton(
                      //     onPressed: () {
                      //       // Validate returns true if the form is valid, or false otherwise.
                      //       if (_formKey.currentState!.validate()) {
                      //         // If the form is valid, display a snackbar. In the real world,
                      //         // you'd often call a server or save the information in a database.
                      //         ScaffoldMessenger.of(context).showSnackBar(
                      //           const SnackBar(content: Text('Processing Data')),
                      //         );
                      //       }
                      //     },
                      //     child: const Text('Submit'),
                      //   ),
                      // ),
                    ],
                  ),
                ),
              )),
        ));
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
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            )));
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
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            )));
  }

  void deleteLocation(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleting $pageType...')),
    );
    //id,type, name, parentId, parentType, isVisible
    var result = await locationsBloc.deleteLocation(
        currentLocation.id as String,
        currentLocation.type,
        currentLocation.name as String,
        currentLocation.parentid as String,
        currentLocation.parenttype as String,
        false);

    if (!mounted) {
      return;
    }
    if (result is SuccessResponse) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$pageType deleted successfully.')));
      Navigator.of(context)
        ..pop()
        ..pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete the ${currentLocation.type}')),
      );
    }
  }
}
