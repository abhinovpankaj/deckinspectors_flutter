import 'dart:io';

import 'package:deckinspectors/src/ui/cachedimage_widget.dart';
import 'package:deckinspectors/src/ui/home.dart';
import 'package:deckinspectors/src/ui/project_details.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../bloc/images_bloc.dart';

import '../models/realm/realm_schemas.dart';
import '../models/success_response.dart';
import '../resources/realm/realm_services.dart';
import 'capture_image.dart';

class AddEditProjectPage extends StatefulWidget {
  final LocalProject newProject;
  final String userFullName;

  final bool isNewProject;

  const AddEditProjectPage(
      this.newProject, this.isNewProject, this.userFullName,
      {Key? key})
      : super(key: key);
  static MaterialPageRoute getRoute(
          LocalProject project, bool isNew, String userName) =>
      MaterialPageRoute(
          settings: const RouteSettings(name: 'Edit Project'),
          builder: (context) => AddEditProjectPage(project, isNew, userName));
  @override
  State<AddEditProjectPage> createState() => _AddEditProjectPageState();
}

class _AddEditProjectPageState extends State<AddEditProjectPage> {
  @override
  void dispose() {
    super.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _nameController.dispose();
  }

  @override
  void initState() {
    currentProject = widget.newProject;

    if (!widget.isNewProject) {
      pageTitle = "Edit Project";
      prevPageName = currentProject.name as String; //'Project';
      isNewProject = false;
      showAssetPic = false;
    } else {
      prevPageName = 'Projects';
    }
    userFullName = widget.userFullName;
    _nameController.text = currentProject.name as String;
    _addressController.text = currentProject.address as String;
    _descriptionController.text = currentProject.description as String;

    if (currentProject.url != null) {
      imageURL = currentProject.url as String;
    }
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  /// Each time to start a speech recognition session
  void _startListening() async {
    await _speechToText.listen(onResult: _onSpeechResult);
    setState(() {});
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {});
  }

  /// This is the callback that the SpeechToText plugin calls when
  /// the platform returns recognized words.
  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _lastWords = result.recognizedWords;
    });
  }

  bool showAssetPic = true;
  late RealmProjectServices realmProjServices;
  bool isNewProject = true;
  late String userFullName;
  late LocalProject currentProject;
  String pageTitle = "Add Project";
  final _formKey = GlobalKey<FormState>();

  save(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      // If the form is valid, display a snackbar. In the real world,
      // you'd often call a server or save the information in a database.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saving Project...')),
      );

      bool result;

      // if (currentProject.id == null) {
      //   result = await projectsBloc.addProject(currentProject);
      //   if (result is SuccessResponse) {
      //     currentProject.id = result.id;
      //   }
      // } else {
      //   result = await projectsBloc.updateProject(currentProject);
      // }

      result = realmProjServices.addupdateProject(
          currentProject,
          _nameController.text,
          _addressController.text,
          _descriptionController.text,
          userFullName,
          isNewProject);

      if (!mounted) {
        return;
      }
      if (result) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Project saved successfully.')));
        if (isNewProject) {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => ProjectDetailsPage(
                      currentProject.id, userFullName, false)));
        } else {
          Navigator.pop(context);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save the project.')),
        );
      }
      //upload image if changed
      if (currentProject.url == null) {
        return;
      }
      if (imageURL != currentProject.url) {
        Object result;

        result = await imagesBloc.uploadImage(
            imageURL,
            currentProject.name as String,
            userFullName,
            currentProject.id.toString(),
            '',
            'project');

        if (result is ImageResponse) {
          realmProjServices.updateProjectUrl(
              currentProject, result.url as String);
        }
      }
    }
  }

  String imageURL = 'assets/images/icon.png';
  final TextEditingController _nameController = TextEditingController(text: '');
  final TextEditingController _addressController =
      TextEditingController(text: '');
  final TextEditingController _descriptionController =
      TextEditingController(text: '');
  String prevPageName = '';
  late String projectName, projectAddress, projectDescription, projectUrl;
  late String projectType;
  bool isProjectSingleLevel = false;
  void toggleSwitch(bool value) {
    if (isProjectSingleLevel == false) {
      setState(() {
        isProjectSingleLevel = true;
        currentProject.projecttype = 'singlelevel';
      });
    } else {
      setState(() {
        isProjectSingleLevel = false;
        currentProject.projecttype = 'multilevel';
      });
    }
  }

  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _lastWords = '';

  @override
  Widget build(BuildContext context) {
    realmProjServices =
        Provider.of<RealmProjectServices>(context, listen: false);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
          automaticallyImplyLeading: false,
          leadingWidth: 150,
          leading: ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.blue,
            ),
            label: Text(
              prevPageName,
              style: const TextStyle(
                  color: Colors.blue, overflow: TextOverflow.clip),
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
                  child: const Chip(
                    avatar: Icon(
                      Icons.save_outlined,
                      color: Color(0xFF3F3F3F),
                    ),
                    labelPadding: EdgeInsets.all(2),
                    label: Text(
                      'Save Project',
                      style: TextStyle(color: Color(0xFF3F3F3F)),
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
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
        child: Form(
          key: _formKey,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (isNewProject)
                          const Text(
                            'Is Project Single Level',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        if (isNewProject)
                          Switch(
                            onChanged: (value) {
                              toggleSwitch(value);
                            },
                            value: isProjectSingleLevel,
                          ),
                        Align(
                            alignment: Alignment.centerRight,
                            child: FloatingActionButton(
                              onPressed:
                                  // If not yet listening for speech start, otherwise stop
                                  _speechToText.isNotListening
                                      ? _startListening
                                      : _stopListening,
                              tooltip: 'Listen',
                              child: Icon(_speechToText.isNotListening
                                  ? Icons.mic_off
                                  : Icons.mic),
                            )),
                      ],
                    ),
                    const Text('Project name'),
                    const SizedBox(
                      height: 8,
                    ),
                    inputWidgetwithValidation('Project name',
                        'Please enter project name', _nameController),
                    const SizedBox(
                      height: 16,
                    ),
                    const Text('Description'),
                    const SizedBox(
                      height: 8,
                    ),
                    inputWidgetNoValidation(
                        'Description', 3, _descriptionController),
                    const SizedBox(
                      height: 16,
                    ),
                    const Text('Address'),
                    const SizedBox(
                      height: 8,
                    ),
                    inputWidgetNoValidation('Address', 2, _addressController),
                    const SizedBox(
                      height: 16,
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
                                    child: showAssetPic
                                        ? currentProject.url == ""
                                            ? Image.asset(
                                                "assets/images/heroimage.png",
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                height: 250,
                                              )
                                            : Image.file(
                                                File(imageURL),
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                height: 250,
                                              )
                                        : cachedNetworkImage(imageURL),
                                  ),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: const [
                                      Icon(Icons.camera_outlined,
                                          size: 40, color: Colors.blue),
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
                    const SizedBox(
                      height: 30,
                    ),
                    if (!isNewProject)
                      OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                              side: BorderSide.none,
                              // the height is 50, the width is full
                              minimumSize: const Size.fromHeight(40),
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              elevation: 1),
                          onPressed: () {
                            deleteProject();
                          },
                          icon: const Icon(
                            Icons.delete_outline_outlined,
                            color: Colors.redAccent,
                          ),
                          label: const Text(
                            'Delete Project',
                            style: TextStyle(color: Colors.red),
                          )),
                    const SizedBox(
                      height: 30,
                    )
                  ],
                ),
              )),
        ),
      ),
    );
  }

  Widget inputWidgetwithValidation(
      String hint, String message, TextEditingController controller) {
    return TextFormField(
        controller: controller,
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

  Widget inputWidgetNoValidation(
      String hint, int? lines, TextEditingController controller) {
    return TextField(
        controller: controller,
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

  void deleteProject() async {
    // var result = await projectsBloc.deleteProjectPermanently(
    //     currentProject, id as String);
    // if (!mounted) {
    //   return;
    // }
    var result = realmProjServices.deleteProject(currentProject);
    if (result == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project deleted successfully.')));
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => const HomePage(
                    key: Key('Home'),
                  )));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to deleted project.')));
    }
  }
}
