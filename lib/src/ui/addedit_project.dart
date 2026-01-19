import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
//import 'package:get/get.dart';

import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
import '../bloc/images_bloc.dart';
import '../bloc/addedit_project_bloc.dart';
import '../bloc/addedit_project_event.dart';
import '../bloc/addedit_project_state.dart';
import '../resources/couchbase/project_repository.dart';
import '../resources/couchbase/database_provider.dart';
import '../resources/couchbase/image_repository.dart';

import '../models/couchbase/couchbase_models.dart';
import '../models/success_response.dart';
// import '../resources/couchbase/couchbase_project_services.dart';
import 'cachedimage_widget.dart';
import 'capture_image.dart';
import 'googlemaps_view.dart';
import 'project_details.dart';

class AddEditProjectPage extends StatefulWidget {
  final Project newProject;
  final String userFullName;

  final bool isNewProject;

  const AddEditProjectPage(
    this.newProject,
    this.isNewProject,
    this.userFullName, {
    super.key,
  });
  static MaterialPageRoute getRoute(
    Project project,
    bool isNew,
    String userName,
  ) => MaterialPageRoute(
    settings: const RouteSettings(name: 'Edit Project'),
    builder: (context) {
      final dbProvider = DatabaseProvider();
      final imageRepo = ImageRepository(dbProvider);
      final projectRepository = ProjectRepository(dbProvider, imageRepo);
      return BlocProvider(
        create:
            (_) =>
                AddEditProjectBloc(projectRepository: projectRepository)
                  ..add(LoadProject(projectId: project.id)),
        child: AddEditProjectPage(project, isNew, userName),
      );
    },
  );
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

  getCustomFormattedDateTime(String givenDateTime, String dateFormat) {
    // dateFormat = 'MM/dd/yy';
    final DateTime docDateTime = DateTime.parse(givenDateTime);
    return DateFormat(dateFormat).format(docDateTime);
  }

  @override
  void initState() {
    currentProject = widget.newProject;

    if (!widget.isNewProject) {
      pageTitle = "Edit Project";
      prevPageName = currentProject.name as String; //'Project';
      isNewProject = false;
      showAssetPic = false;
      dateInput.text = getCustomFormattedDateTime(
        currentProject.editedat as String,
        'MM-dd-yyyy',
      );
    } else {
      prevPageName = 'Projects';
      dateInput.text = "";
    }
    userFullName = widget.userFullName;
    _nameController.text = currentProject.name as String;
    _addressController.text = currentProject.address as String;
    _descriptionController.text = currentProject.description as String;

    if (currentProject.url != null) {
      imageURL = currentProject.url as String;
    }

    super.initState();
    //_initSpeech();
  }

  bool showAssetPic = true;
  // late RealmProjectServices realmProjServices;
  bool isNewProject = true;
  late String userFullName;
  late Project currentProject;
  String pageTitle = "Add Project";
  final _formKey = GlobalKey<FormState>();
  double lattitude = 28.7;
  double longitude = 34.8;
  save(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      currentProject.name = _nameController.text;
      currentProject.description = _descriptionController.text;
      currentProject.address = _addressController.text;
      currentProject.latitude = lattitude;
      currentProject.longitude = longitude;
      currentProject.projecttype =
          isProjectSingleLevel ? 'singlelevel' : 'multilevel';
      currentProject.formId = formId;
      currentProject.lasteditedby = userFullName;
      currentProject.editedat = DateTime.now().toIso8601String();

      // Ensure id and created metadata for new projects
      if (currentProject.id == '') {
        //currentProject.id = CouchbaseDocument.generateId();
        currentProject.createdby = userFullName;
        currentProject.createdat = DateTime.now().toIso8601String();
      }

      // If image changed, upload and update project url
      if (imageURL != currentProject.url && imageURL.isNotEmpty) {
        final Object result = await imagesBloc.uploadImage(
          imageURL,
          currentProject.name as String,
          userFullName,
          currentProject.id.toString(),
          '',
          'project',
        );

        if (result is ImageResponse) {
          // Save local copy if available
          if (result.originalPath != null && result.originalPath!.isNotEmpty) {
            try {
              await GallerySaver.saveImage(result.originalPath as String);
            } catch (_) {}
          }
          // Prefer remote url if provided, otherwise local path
          currentProject.url = result.url ?? result.originalPath ?? imageURL;
        }
      }

      // Persist project via AddEditProjectBloc by dispatching SaveProject
      try {
        final addEditBloc = context.read<AddEditProjectBloc>();
        addEditBloc.add(
          SaveProject(
            project: currentProject,
            name: currentProject.name as String,
            address: currentProject.address as String,
            description: currentProject.description as String,
            userName: userFullName,
            longitude: currentProject.longitude,
            latitude: currentProject.latitude,
            formId: currentProject.formId,
            isNewProject: isNewProject,
          ),
        );
        // UI will respond to BlocListener for success/failure
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save project: $e')));
      }
    }
  }

  String imageURL = 'assets/images/icon.png';
  String? formId;
  TextEditingController dateInput = TextEditingController();
  final TextEditingController _nameController = TextEditingController(text: '');
  //late TextEditingController _activeController;

  final TextEditingController _addressController = TextEditingController(
    text: '',
  );
  final TextEditingController _descriptionController = TextEditingController(
    text: '',
  );
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

  LocationForm? selectedValue;
  @override
  Widget build(BuildContext context) {
    return BlocListener<AddEditProjectBloc, AddEditProjectState>(
      listener: (context, state) {
        if (state is AddEditProjectSaving) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Saving project...')));
        } else if (state is AddEditProjectSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Project saved successfully')),
          );
          // After successful save, navigate to ProjectDetailsPage for the
          // saved project. The repository sets the `id` on the passed project
          // object, so `currentProject.id` should contain the document id.
          final projId = currentProject.id ?? '';
          try {
            // if (projId.isNotEmpty) {
            //   Navigator.pushReplacement(
            //     context,
            //     ProjectDetailsPage.getRoute(
            //       projId,
            //       userFullName,
            //       false,
            //       currentProject.name ?? '',
            //     ),
            //   );
            // } else {
            //   Navigator.pop(context, true);
            // }
            Navigator.pop(context, true);
          } catch (_) {
            Navigator.pop(context, true);
          }
        } else if (state is AddEditProjectFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save project: ${state.error}')),
          );
        }
      },
      child: _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    // realmProjServices =
    // Provider.of<RealmProjectServices>(context, listen: false);
    // TODO: Replace with ProjectRepository/BLoC
    // var forms = realmProjServices.getAllForms();

    List<DropdownMenuItem<LocationForm>> dropdownItems = [];
    // TODO: Integrate ProjectRepository/BLoC for forms
    dropdownItems.add(
      const DropdownMenuItem(value: null, child: Text("E3 Form")),
    );

    return Scaffold(
      resizeToAvoidBottomInset: false,
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
            style: TextStyle(color: Colors.blue, overflow: TextOverflow.clip),
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
              save(context);
            },
            child: const Chip(
              avatar: Icon(Icons.save_outlined, color: Color(0xFF3F3F3F)),
              labelPadding: EdgeInsets.all(2),
              label: Text(
                'Save',
                style: TextStyle(color: Color(0xFF3F3F3F)),
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
          maxLines: 2,
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
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 1.3,
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
                    ],
                  ),
                  const Text('Project name'),
                  const SizedBox(height: 8),
                  inputWidgetwithValidation(
                    'Project name',
                    'Please enter project name',
                    _nameController,
                  ),
                  const SizedBox(height: 16),
                  const Text('Description'),
                  const SizedBox(height: 8),
                  inputWidgetNoValidation(
                    'Description',
                    3,
                    _descriptionController,
                  ),
                  const SizedBox(height: 16),
                  const Text('Address'),

                  inputWidgetNoValidation('Address', 2, _addressController),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide.none,
                      // the height is 50, the width is full
                      minimumSize: const Size.fromHeight(40),
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      elevation: 1,
                    ),
                    onPressed: () {
                      var initlattitude = currentProject.latitude;
                      var initlongitude = currentProject.longitude;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => GoogleMapsView(
                                initlattitude,
                                initlongitude,
                                isNewProject,
                              ),
                        ),
                      ).then((value) {
                        if (value != null) {
                          setState(() {
                            _addressController.text = value["address"];
                            lattitude = value["latitude"];
                            longitude = value["longitude"];
                          });
                        }
                      });
                    },
                    icon: const Icon(
                      Icons.location_pin,
                      color: Colors.blueAccent,
                    ),
                    label: Text(
                      isNewProject ? 'Add location' : 'Update location',
                      style: const TextStyle(color: Colors.blueAccent),
                    ),
                  ),

                  const SizedBox(height: 8),
                  if (isNewProject)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        const Text(
                          'Location form type',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        DropdownButton(
                          value: selectedValue,
                          hint: const Text('E3 form'),
                          items: dropdownItems,
                          onChanged: (value) {
                            formId = value?.id;
                            setState(() {
                              selectedValue = value;
                            });
                          },
                        ),
                      ],
                    ),

                  // Center(
                  //     child: TextField(
                  //   controller: dateInput,
                  //   //editing controller of this TextField
                  //   decoration: const InputDecoration(
                  //       icon: Icon(Icons.calendar_today), //icon of text field
                  //       labelText:
                  //           "Project inspection/edit date" //label text of field
                  //       ),
                  //   readOnly: true,
                  //   //set it true, so that user will not able to edit text
                  //   onTap: () async {
                  //     DateTime? pickedDate = await showDatePicker(
                  //         context: context,
                  //         initialDate: dateInput.text == ''
                  //             ? DateTime.now()
                  //             : DateTime.parse(
                  //                 currentProject.editedat as String),
                  //         firstDate: DateTime(2000),
                  //         //DateTime.now() - not to allow to choose before today.
                  //         lastDate: DateTime(2100));

                  //     if (pickedDate != null) {
                  //       String formattedDate =
                  //           DateFormat('MM-dd-yyyy').format(pickedDate);

                  //       setState(() {
                  //         dateInput.text =
                  //             formattedDate;

                  //         //set output date to TextField value.
                  //       });
                  //     } else {}
                  //   },
                  // )),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide.none,
                      // the height is 50, the width is full
                      minimumSize: const Size.fromHeight(40),
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      elevation: 1,
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
                                  ? currentProject.url == ""
                                      ? Image.asset(
                                        "assets/images/icon.png",
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
                      ),
                    ),
                  ),
                  if (!isNewProject)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide.none,
                        // the height is 50, the width is full
                        minimumSize: const Size.fromHeight(40),
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        elevation: 1,
                      ),
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
                      ),
                    ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget inputWidgetwithValidation(
    String hint,
    String message,
    TextEditingController controller,
  ) {
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget inputWidgetNoValidation(
    String hint,
    int? lines,
    TextEditingController controller,
  ) {
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void deleteProject() async {
    try {
      final addEditBloc = context.read<AddEditProjectBloc>();
      if (currentProject.id != '') {
        addEditBloc.add(DeleteProject(projectId: currentProject.id!));

        // Wait for bloc to emit success or failure to ensure deletion completed
        final state = await addEditBloc.stream.firstWhere(
          (s) => s is DeleteProjectSuccess || s is AddEditProjectFailure,
        );

        if (state is DeleteProjectSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Project deleted successfully.')),
          );
          Navigator.pop(context, true);
        } else if (state is AddEditProjectFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete project: ${state.error}')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete project: $e')));
    }
  }
}
