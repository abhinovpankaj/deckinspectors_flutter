import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:intl/intl.dart';

import '../bloc/images_bloc.dart';
import '../bloc/addedit_project_bloc.dart';
import '../bloc/addedit_project_event.dart';
import '../bloc/addedit_project_state.dart';
import '../resources/couchbase/project_repository.dart';
import '../resources/couchbase/database_provider.dart';
import '../resources/couchbase/image_repository.dart';

import '../models/couchbase/couchbase_models.dart';
import '../models/success_response.dart';

import 'cachedimage_widget.dart';
import 'capture_image.dart';
import 'googlemaps_view.dart';
import 'app_theme.dart';

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
  double lattitude = 0.0;
  double longitude = 0.0;
  save(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      currentProject.name = _nameController.text;
      currentProject.description = _descriptionController.text;
      currentProject.address = _addressController.text;
      currentProject.latitude = lattitude;
      currentProject.longitude = longitude;
      currentProject.projecttype =
          isProjectSingleLevel ? 'singlelevel' : 'multilevel';
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
  List<LocationForm> _cachedForms = [];
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AddEditProjectBloc, AddEditProjectState>(
      listener: (context, state) {
        if (state is AddEditProjectLoaded) {
          if (state.forms.isNotEmpty) {
            setState(() => _cachedForms = state.forms);
          }
          if (state.project != null) {
            setState(() => currentProject = state.project!);
          }
        }
        if (state is AddEditProjectSaving) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Saving project...')));
        } else if (state is AddEditProjectSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Project saved successfully')),
          );
          try {
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
      builder: (context, state) => _buildForm(context, state),
    );
  }

  Widget _buildForm(BuildContext context, AddEditProjectState state) {
    List<DropdownMenuItem<LocationForm>> dropdownItems = [
      const DropdownMenuItem(
        value: null,
        child: Text("E3 Inspections Default"),
      ),
    ];
    for (final form in _cachedForms) {
      dropdownItems.add(
        DropdownMenuItem(value: form, child: Text(form.name ?? 'Form')),
      );
    }
    // Display value: user selection or project's saved form
    LocationForm? displayValue = selectedValue;
    if (displayValue == null &&
        currentProject.formId != null &&
        currentProject.formId!.isNotEmpty) {
      for (final f in _cachedForms) {
        if (f.id == currentProject.formId) {
          displayValue = f;
          break;
        }
      }
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 120,
        leading: ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primary),
          label: const Text(
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            'Back',
            style: TextStyle(color: AppColors.primary),
          ),
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: Colors.transparent,
          ),
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: () => save(context),
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
        title: Text(
          pageTitle,
          maxLines: 2,
          style: AppTextStyles.titleLarge,
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
                          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
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
                      color: AppColors.primary,
                    ),
                    label: Text(
                      isNewProject ? 'Add location' : 'Update location',
                      style: const TextStyle(color: AppColors.primary),
                    ),
                  ),

                  const SizedBox(height: 8),
                  if (isNewProject)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Location form type',
                          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<LocationForm>(
                              isExpanded: true,
                              value: displayValue,
                              hint: const Text('E3 form'),
                              items: dropdownItems,
                              onChanged: (value) {
                                setState(() {
                                  selectedValue = value;
                                  currentProject.formId = value?.id;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (!isNewProject)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Location form type',
                          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            displayValue?.name ?? 'E3 Inspections Default',
                            style: const TextStyle(fontWeight: FontWeight.w400),
                          ),
                        ),
                      ],
                    ),

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
                      color: AppColors.primary,
                    ),
                    label: const Text(
                      'Add Image',
                      style: TextStyle(color: AppColors.primary),
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
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: const BorderRadius.all(
                              Radius.circular(8.0),
                            ),
                            boxShadow: const [
                              BoxShadow(blurRadius: 1.0, color: AppColors.cardBorder),
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
                        color: AppColors.error,
                      ),
                      label: const Text(
                        'Delete Project',
                        style: TextStyle(color: AppColors.error),
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
