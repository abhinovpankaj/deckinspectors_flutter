import 'dart:io';

//import 'package:deckinspectors/src/bloc/settings_bloc.dart';
import 'package:E3InspectionsMultiTenant/src/ui/cachedimage_widget.dart';
import 'package:E3InspectionsMultiTenant/src/ui/subproject.dart';
import 'package:flutter/material.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:provider/provider.dart';
import '../bloc/images_bloc.dart';
import '../models/realm/realm_schemas.dart';
import '../models/success_response.dart';
import '../services/realm_local_services.dart';
import 'capture_image.dart';

class AddEditSubProjectPage extends StatefulWidget {
  final SubProject currentBuilding;
  final String fullUserName;
  final String prevPageName;
  final bool isNewBuilding;
  const AddEditSubProjectPage(
    this.currentBuilding,
    this.isNewBuilding,
    this.fullUserName,
    this.prevPageName, {
    super.key,
  });
  static MaterialPageRoute getRoute(
    SubProject subProject,
    bool isNew,
    String userName,
    String prevPageName,
  ) => MaterialPageRoute(
    settings: RouteSettings(name: isNew ? 'Add Building' : 'Edit Building'),
    builder:
        (context) =>
            AddEditSubProjectPage(subProject, isNew, userName, prevPageName),
  );
  @override
  State<AddEditSubProjectPage> createState() => _AddEditSubProjectPageState();
}

class _AddEditSubProjectPageState extends State<AddEditSubProjectPage> {
  late String fullUserName;
  late TextEditingController _nameController;
  bool showAssetPic = true;
  late TextEditingController _descriptionController;
  @override
  void initState() {
    currentBuilding = widget.currentBuilding;
    fullUserName = widget.fullUserName;
    pageTitle = 'Add Building';
    name = "Building";

    super.initState();
    isNewBuilding = widget.isNewBuilding;
    _nameController = TextEditingController(
      text: isNewBuilding ? "" : (currentBuilding.name ?? ""),
    );
    _descriptionController = TextEditingController(
      text: isNewBuilding ? "" : (currentBuilding.description ?? ""),
    );
    if (!widget.isNewBuilding) {
      pageTitle = 'Edit Building';
      showAssetPic = false;
      _nameController.text = currentBuilding.name as String;
      _descriptionController.text = currentBuilding.description as String;
      //currentBuilding.url ??= "/assets/images/icon.png";
    }
    if (currentBuilding.url != null) {
      imageURL = currentBuilding.url as String;
    }
    prevPagename = widget.prevPageName;
    //_initSpeech();
  }

  String pageTitle = 'Add';
  String prevPagename = 'Project';
  late bool isNewBuilding;
  late SubProject currentBuilding;
  String name = "";
  final _formKey = GlobalKey<FormState>();
  String imageURL = 'assets/images/icon.png';
  save(BuildContext context, RealmLocalServices realmServices) async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState!.validate()) {
      // If the form is valid, display a snackbar. In the real world,
      // you'd often call a server or save the information in a database.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saving Building...')));

      try {
        bool result = realmServices.addupdateSubProject(
          currentBuilding,
          _nameController.text,
          _descriptionController.text,
          isNewBuilding,
          fullUserName,
        );

        if (!mounted) {
          return;
        }
        if (result) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Building saved successfully.')),
          );

          if (isNewBuilding) {
            Navigator.pushReplacement(
              context,
              SubProjectDetailsPage.getRoute(
                currentBuilding.id,
                prevPagename,
                fullUserName,
                currentBuilding.name as String,
              ),
            );
          } else {
            Navigator.pop(context);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save the building.')),
          );
        }
        if (currentBuilding.url == null) {
          return;
        }

        if (imageURL != currentBuilding.url || !imageURL.startsWith('http')) {
          var result = await imagesBloc.uploadImage(
            imageURL,
            currentBuilding.name as String,
            fullUserName,
            currentBuilding.id.toString(),
            'project',
            'building',
          );

          if (result is ImageResponse) {
            await GallerySaver.saveImage(result.originalPath as String);

            realmServices.updateSubProjectUrl(
              currentBuilding,
              result.url as String,
            );
          }
          //appSettings.activeConnection = true;
        }
      } catch (e) {
        // if (e is SocketException) {
        //   //appSettings.activeConnection = false;
        //   var result = await imagesBloc.uploadImage(
        //       imageURL,
        //       currentBuilding.name as String,
        //       fullUserName,
        //       currentBuilding.id.toString(),
        //       'project',
        //       'building');

        //   if (result is ImageResponse) {
        //     realmServices.updateSubProjectUrl(
        //         currentBuilding, result.url as String);
        //   } else {}
        // }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save the ${currentBuilding.type} ${e.toString()}',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final realmServices = Provider.of<RealmLocalServices>(
      context,
      listen: false,
    );
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
        actions: [
          InkWell(
            onTap: () {
              save(context, realmServices);
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
          maxLines: 2,
          pageTitle,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
      // floatingActionButton: Padding(
      //   padding: const EdgeInsets.fromLTRB(20, 0, 0, 0),
      //   child: BreadCrumbNavigator(),
      // ),
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
                  Text(name),
                  const SizedBox(height: 8),
                  inputWidgetwithValidation(
                    '$name name',
                    'Please enter $name name',
                  ),
                  const SizedBox(height: 16),
                  const Text('Description'),
                  const SizedBox(height: 8),
                  inputWidgetNoValidation('$name Description', 3),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide.none,
                      // the height is 50, the width is full
                      minimumSize: const Size.fromHeight(40),
                      backgroundColor: Colors.white,
                      shadowColor: Colors.blue,
                      elevation: 0,
                    ),
                    onPressed: () async {
                      showAssetPic = false;
                      //add logic to open camera.
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
                      'Add Image',
                      style: TextStyle(color: Colors.blueAccent),
                    ),
                  ),
                  SizedBox(
                    height: 220,
                    child: Card(
                      borderOnForeground: false,
                      elevation: 8,
                      child: GestureDetector(
                        onTap: () async {
                          showAssetPic = false;
                          //add logic to open camera.
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
                                  ? currentBuilding.url == ""
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
                  const SizedBox(height: 20),
                  if (!isNewBuilding)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide.none,
                        // the height is 50, the width is full
                        minimumSize: const Size.fromHeight(40),
                        backgroundColor: Colors.white,
                        shadowColor: Colors.blue,
                        elevation: 0,
                      ),
                      onPressed: () {
                        deleteSubProject(context, realmServices);
                      },
                      icon: const Icon(
                        Icons.delete_outline_outlined,
                        color: Colors.redAccent,
                      ),
                      label: const Text(
                        'Delete Building',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 40),
                ],
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

  void deleteSubProject(
    BuildContext context,
    RealmLocalServices realmServices,
  ) async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Deleting Building...')));

    var result = realmServices.deleteSubProject(currentBuilding);
    if (result == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Building deleted successfully.')),
      );
      Navigator.of(context)
        ..pop()
        ..pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete the ${currentBuilding.type}')),
      );
    }
  }
}
