import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:path_provider/path_provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as path;
import '../bloc/images_bloc.dart';
import '../bloc/settings_bloc.dart';
import '../models/couchbase/couchbase_models.dart';
import '../models/success_response.dart';
import '../resources/couchbase/dynamic_repository.dart';
import '../resources/couchbase/database_provider.dart';

import '../resources/couchbase/image_repository.dart';
import '../bloc/users_bloc.dart';
import '../bloc/dynamic_visual_section_bloc.dart';
import '../bloc/dynamic_visual_section_event.dart';
import '../bloc/dynamic_visual_section_state.dart';
import '../resources/couchbase/location_repository.dart';
import 'capture_multipic_esp_32.dart';
import 'capture_multipic_raspi.dart';
import 'capturemultipic.dart';
import 'image_widget.dart';
import 'package:http/http.dart' as http;

class DynamicVisualSectionPage extends StatelessWidget {
  final String sectionId;
  final String userFullName;
  final String parentType;
  final String parentId;
  final String parentName;
  final bool isNewSection;
  final String formId;

  const DynamicVisualSectionPage(
    this.sectionId,
    this.parentId,
    this.userFullName,
    this.parentType,
    this.parentName,
    this.isNewSection,
    this.formId, {
    Key? key,
  }) : super(key: key);

  static MaterialPageRoute getRoute(
    String parentId,
    String userFullName,
    String parentType,
    String parentName,
    dynamic formId,
    bool isNewSection,
    String sectionId,
  ) => MaterialPageRoute(
    builder:
        (context) => DynamicVisualSectionPage(
          sectionId,
          parentId,
          userFullName,
          parentType,
          parentName,
          isNewSection,
          formId.toString(),
        ),
  );

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<DatabaseProvider>(create: (_) => DatabaseProvider()),
        RepositoryProvider<ImageRepository>(
          create: (ctx) => ImageRepository(ctx.read<DatabaseProvider>()),
        ),
        RepositoryProvider<UsersBloc>(create: (_) => UsersBloc()),
        RepositoryProvider<DynamicRepository>(
          create:
              (ctx) => DynamicRepository(
                ctx.read<DatabaseProvider>(),
                ctx.read<ImageRepository>(),
                ctx.read<UsersBloc>(),
                RepositoryProvider.of<LocationRepository>(ctx),
              ),
        ),
      ],
      child: BlocProvider(
        create: (ctx) {
          final bloc = DynamicVisualSectionBloc(ctx.read<DynamicRepository>());
          if (!isNewSection) {
            bloc.add(LoadDynamicVisualSection(sectionId));
          }
          return bloc;
        },
        child: _DynamicVisualSectionPageBody(
          sectionId: sectionId,
          userFullName: userFullName,
          parentType: parentType,
          parentId: parentId,
          parentName: parentName,
          isNewSection: isNewSection,
          formId: formId,
        ),
      ),
    );
  }
}

class _DynamicVisualSectionPageBody extends StatefulWidget {
  final String sectionId;
  final String userFullName;
  final String parentType;
  final String parentId;
  final String parentName;
  final bool isNewSection;
  final String formId;
  const _DynamicVisualSectionPageBody({
    required this.sectionId,
    required this.userFullName,
    required this.parentType,
    required this.parentId,
    required this.parentName,
    required this.isNewSection,
    required this.formId,
    Key? key,
  }) : super(key: key);

  @override
  State<_DynamicVisualSectionPageBody> createState() =>
      _DynamicVisualSectionPageBodyState();
}

class _DynamicVisualSectionPageBodyState
    extends State<_DynamicVisualSectionPageBody> {
  late DynamicRepository dynamicRepository;
  late ImageRepository imageRepository;
  late LocationRepository locationRepository;

  List<String> capturedImages = [];
  List<Question> questions = [];

  // TODO: Refactor state and logic to use BLoC events and state

  String websocketUrl = ""; // = "ws://192.168.1.2:8090";

  // generate callerID of local user
  final String selfCallerID = 'e3camReceiver';

  bool isFormUpdated = false;
  bool isRunning = false;
  String userFullName = "";
  String parentType = "";
  late DynamicVisualSection currentVisualSection;
  Location? currentLocation;
  late Future sectionResponse;
  late bool isNewSection;
  late String prevPageName;
  final TextEditingController _nameController = TextEditingController(text: '');
  final TextEditingController _concernsController = TextEditingController(
    text: '',
  );
  bool invasiveReviewRequired = false;
  bool unitUnavailable = false;
  late String formId;

  @override
  void initState() {
    super.initState();
    dynamicRepository = RepositoryProvider.of<DynamicRepository>(context);
    imageRepository = RepositoryProvider.of<ImageRepository>(context);
    locationRepository = RepositoryProvider.of<LocationRepository>(context);
    isNewSection = widget.isNewSection;
    userFullName = widget.userFullName;
    parentType = widget.parentType;
    prevPageName = widget.parentName;
    formId = widget.formId;
    if (isNewSection) {
      currentVisualSection = getNewDynamicVisualSection();
      capturedImages = [];
      _loadFormQuestions();
    }
  }

  /// Fetches template questions from the LocationForm identified by [formId]
  /// and pre-populates the questions list for a new section.
  Future<void> _loadFormQuestions() async {
    if (formId.isEmpty) return;
    try {
      final form = await dynamicRepository.getFormById(formId);
      if (form != null && form.questions.isNotEmpty && mounted) {
        setState(() {
          questions =
              form.questions
                  .map(
                    (q) => Question(
                      name: q.name,
                      type: q.type,
                      allowedValues: List<String>.from(q.allowedValues),
                      answer: '',
                      multipleAnswers: [],
                      isMandatory: q.isMandatory,
                    ),
                  )
                  .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading form questions: $e');
    }
  }

  void setInitialValues() {
    //Set all values before returning the widget.
    _nameController.text = currentVisualSection.name ?? '';
    unitUnavailable = currentVisualSection.unitUnavailable;
    if (!currentVisualSection.unitUnavailable) {
      _concernsController.text =
          currentVisualSection.additionalconsiderations ?? '';
      invasiveReviewRequired =
          currentVisualSection.furtherinvasivereviewrequired;
    }
    questions =
        currentVisualSection.questions
            .map(
              (q) => Question(
                id: q.id,
                name: q.name,
                type: q.type,
                allowedValues: List<String>.from(q.allowedValues),
                answer: q.answer,
                multipleAnswers: List<String>.from(q.multipleAnswers),
                isMandatory: q.isMandatory,
              ),
            )
            .toList();
    capturedImages = [];
    if (currentVisualSection.images.isNotEmpty) {
      capturedImages.addAll(currentVisualSection.images);
    }
    isFormUpdated = false;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DynamicVisualSectionBloc, DynamicVisualSectionState>(
      listener: (context, state) async {
        if (state is DynamicVisualSectionLoading ||
            state is DynamicVisualSectionSaving) {
          if (!mounted) return;
          setState(() {
            isRunning = true;
          });
        } else if (state is DynamicVisualSectionLoaded) {
          if (!mounted) return;
          currentVisualSection = state.section;
          setInitialValues();
          setState(() {
            isRunning = false;
          });
        } else if (state is DynamicVisualSectionSaveSuccess) {
          if (!mounted) return;
          isSaved = true;
          currentVisualSection = state.section;
          setState(() {
            isRunning = false;
          });
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location saved successfully.')),
          );
          if (capturedImages.isNotEmpty) {
            final imagesToUpload = await imageRepository.getImagesNotUploaded(
              capturedImages,
              appSettings.activeConnection,
              isNewSection,
            );
            if (imagesToUpload.isNotEmpty) {
              final sectionId = currentVisualSection.id;
              if (parentType != 'project' &&
                  currentLocation != null &&
                  sectionId != null) {
                await locationRepository.updateImageUploadStatus(
                  currentLocation!,
                  sectionId,
                  true,
                );
              }
              List<String> transformedimagesPath = [];
              if (Platform.isIOS) {
                Directory imageDirectory =
                    await getApplicationSupportDirectory();
                transformedimagesPath =
                    imagesToUpload
                        .map(
                          (imgpath) =>
                              imgpath = path.join(imageDirectory.path, imgpath),
                        )
                        .toList();
              } else {
                transformedimagesPath = imagesToUpload;
              }
              imagesBloc
                  .uploadMultipleImages(
                    transformedimagesPath,
                    currentVisualSection.name ?? '',
                    userFullName,
                    currentVisualSection.id ?? '',
                    parentType,
                    'section',
                  )
                  .then((value) async {
                    List<String> urls = [];
                    for (var element in value) {
                      if (element is ImageResponse) {
                        if (element.originalPath != null) {
                          await GallerySaver.saveImage(
                            element.originalPath as String,
                          );
                        }
                        urls.add(element.url as String);
                      }
                    }
                    if (parentType != 'project' &&
                        currentLocation != null &&
                        currentVisualSection.id != null) {
                      await locationRepository.updateImageUploadStatus(
                        currentLocation!,
                        currentVisualSection.id!,
                        false,
                      );
                    }
                    await dynamicRepository.addDynamicImagesUrl(
                      currentVisualSection.name ?? '',
                      currentVisualSection.id ?? '',
                      currentVisualSection,
                      imagesToUpload,
                      urls,
                    );
                  });
            }
          }
        } else if (state is DynamicVisualSectionSaveFailure) {
          if (!mounted) return;
          setState(() {
            isRunning = false;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.error)));
        } else if (state is DynamicVisualSectionDeleteSuccess) {
          if (!mounted) return;
          setState(() {
            isRunning = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${currentVisualSection.name} deleted successfully.',
              ),
            ),
          );
          Navigator.of(context).pop();
        } else if (state is DynamicVisualSectionDeleteFailure) {
          if (!mounted) return;
          setState(() {
            isRunning = false;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.error)));
        } else if (state is DynamicVisualSectionError) {
          if (!mounted) return;
          setState(() {
            isRunning = false;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leadingWidth: 120,
          leading: ElevatedButton.icon(
            onPressed: () async {
              if (isFormUpdated) {
                bool? cangoback = await showDialog<bool>(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('Save Section'),
                        content: const Text(
                          'Do you want to discard the changes?',
                        ),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () {
                              Navigator.of(
                                context,
                                rootNavigator: true,
                              ).pop(false);
                            },
                            child: const Text('No'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(
                                context,
                                rootNavigator: true,
                              ).pop(true);
                            },
                            child: const Text('Yes'),
                          ),
                        ],
                      ),
                );
                if (cangoback == true) {
                  Navigator.of(context).pop();
                }
              } else {
                Navigator.of(context).pop();
              }
            },
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
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Details', //can be replaced with the form name
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.normal,
                ),
              ),
              InkWell(
                onTap: () {
                  save(context);
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
          ),
        ),
        body:
            isRunning
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                  child: Column(children: [sectionForm(context)]),
                ),
      ),
    );
  }

  DynamicVisualSection getNewDynamicVisualSection() {
    return DynamicVisualSection(
      parentid: widget.parentId,
      parenttype: parentType,
      createdby: userFullName,
      furtherinvasivereviewrequired: false,
    );
  }

  Widget inputWidgetwithValidation(
    String hint,
    String message,
    int lines,
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
      maxLines: lines,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.only(left: 5, top: 2.0, bottom: 2.0),
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 13.0,
          color: Color(0xFFABB3BB),
          height: 1.0,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget inputWidgetwithNoValidation(
    String hint,
    String message,
    int lines,
    TextEditingController controller,
  ) {
    return TextFormField(
      controller: controller,
      maxLines: lines,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.only(left: 5, top: 2.0, bottom: 2.0),
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 13.0,
          color: Color(0xFFABB3BB),
          height: 1.0,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void toggleUnitSwitch(bool value) {
    if (unitUnavailable == false) {
      setState(() {
        unitUnavailable = true;
      });
    } else {
      setState(() {
        unitUnavailable = false;
      });
    }
    isFormUpdated = true;
  }

  void toggleSwitchInvasive(bool value) {
    if (invasiveReviewRequired == false) {
      setState(() {
        invasiveReviewRequired = true;
      });
    } else {
      setState(() {
        invasiveReviewRequired = false;
      });
    }
    isFormUpdated = true;
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
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CameraScreen()),
      ).then((value) {
        setState(() {
          if (value != null) {
            capturedImages.addAll(value);
            if (value.isNotEmpty) {
              setState(() {
                // currentVisualSection.realm.write(() {
                //   currentVisualSection.images
                //       .addAll(value.map((e) => e.path).toList());
                // });
                //unitUnavailable = false;
                isFormUpdated = true;
              });
            }
            // for (var element in capturedImages) {
            //   //currentVisualSection.images ??= RealmList<String>[];
            //   currentVisualSection.images.add(element);
            // }
          }
        });
      });
    } else if (value == 3) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ESP32CameraScreen()),
      ).then((value) {
        setState(() {
          if (value != null) {
            capturedImages.addAll(value);
            if (value.isNotEmpty) {
              setState(() {
                unitUnavailable = false;
                isFormUpdated = true;
              });
            }
          }
        });
      });
    } else if (value == 4) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PiZeroCameraScreen()),
      ).then((value) {
        setState(() {
          if (value != null) {
            capturedImages.addAll(value);
            if (value.isNotEmpty) {
              setState(() {
                unitUnavailable = false;
                isFormUpdated = true;
              });
            }
          }
        });
      });
    } else {
      //Code toopen gallery
      final ImagePicker picker = ImagePicker();
      //todo
      var imageFiles = await picker.pickMultiImage(imageQuality: 100);
      if (imageFiles.isNotEmpty) {
        setState(() {
          capturedImages.addAll(imageFiles.map((e) => e.path).toList());

          unitUnavailable = false;
          isFormUpdated = true;
        });
      }
    }
  }

  gotoImageEditorPage(
    BuildContext context,
    String capturedImage,
    int index,
  ) async {
    Uint8List imageData;

    if (capturedImage.contains('http')) {
      http.Response response = await http.get(Uri.parse(capturedImage));
      imageData = response.bodyBytes;
    } else {
      if (File(capturedImage).existsSync()) {
        imageData = await File(capturedImage).readAsBytes();
      } else {
        return;
      }
    }

    var editedImage = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ImageEditor(image: imageData)),
    );
    //update capturedimages collection.
    final directory = await getApplicationDocumentsDirectory();
    var destDirectory = await Directory(
      path.join(directory.path, 'editedimages'),
    ).create(recursive: true);
    String imageid = CouchbaseDocument.generateId();
    final pathOfImage =
        await File('${destDirectory.path}/$imageid.jpg').create();
    if (editedImage != null) {
      var editedFile = await pathOfImage.writeAsBytes(editedImage);
      dynamicRepository.removeDynamicImageUrl(
        currentVisualSection,
        capturedImage,
      );
      setState(() {
        capturedImages.removeAt(index);
        capturedImages.insert(index, editedFile.path);
      });
    }
  }

  void removePhoto(
    BuildContext context,
    DynamicVisualSection currentVisualSection,
    int index,
  ) {
    dynamicRepository.removeDynamicImageUrl(
      currentVisualSection,
      capturedImages[index],
    );
    setState(() {
      capturedImages.removeAt(index);
    });
  }

  final _formKey = GlobalKey<FormState>();
  Widget sectionForm(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Form(
        onChanged: () {
          isFormUpdated = true;
        },
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Location name'),
              const SizedBox(height: 8),
              inputWidgetwithValidation(
                'Location Name',
                'Please enter location name',
                1,
                _nameController,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Is access to unit unavailable',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Switch(
                    onChanged: (value) {
                      toggleUnitSwitch(value);
                      isFormUpdated = true;
                    },
                    value: unitUnavailable,
                  ),
                ],
              ),
              const Divider(
                color: Color.fromARGB(255, 222, 213, 213),
                height: 0,
                thickness: 1,
                indent: 2,
                endIndent: 2,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Unit photos(${capturedImages.length})'),
                  PopupMenuButton(
                    child: const Chip(
                      avatar: Icon(
                        Icons.add_a_photo_outlined,
                        color: Colors.blue,
                      ),
                      labelPadding: EdgeInsets.all(2),
                      label: Text(
                        'Add Photos',
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
                            'Camera',
                            Icons.camera_alt_outlined,
                            1,
                          ),
                          _buildPopupMenuItem(
                            'Gallery',
                            Icons.browse_gallery_outlined,
                            2,
                          ),
                          _buildPopupMenuItem(
                            'External Mobile Cam',
                            Icons.camera_outdoor_outlined,
                            3,
                          ),
                          _buildPopupMenuItem(
                            'E3 Cam',
                            Icons.camera_outdoor_outlined,
                            4,
                          ),
                        ],
                  ),
                ],
              ),
              capturedImages.isEmpty
                  ? const SizedBox(
                    height: 180,
                    child: Center(
                      child: Text(
                        'Add location Images',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  )
                  : SizedBox(
                    height: MediaQuery.of(context).size.height / 3.2,
                    child: ListView.builder(
                      shrinkWrap: true,
                      scrollDirection: Axis.horizontal,
                      itemCount: capturedImages.length,
                      itemBuilder:
                          (BuildContext context, int index) => SizedBox(
                            width: 320,
                            height: 200,
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap:
                                          () => gotoImageEditorPage(
                                            context,
                                            capturedImages[index],
                                            index,
                                          ),
                                      child: Container(
                                        margin: const EdgeInsets.fromLTRB(
                                          2,
                                          8,
                                          8,
                                          0,
                                        ),
                                        height: 180,
                                        width: 300,
                                        decoration: const BoxDecoration(
                                          color: Colors.blue,
                                          // image: DecorationImage(
                                          //     image:
                                          //         AssetImage('assets/images/icon.png'),
                                          //     fit: BoxFit.cover),
                                          borderRadius: BorderRadius.all(
                                            Radius.circular(8.0),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              blurRadius: 1.0,
                                              color: Colors.blue,
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8.0,
                                          ),
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              networkImage(
                                                capturedImages[index],
                                              ),
                                              Align(
                                                alignment:
                                                    Alignment.bottomRight,
                                                child:
                                                    capturedImages[index]
                                                            .startsWith('http')
                                                        ? const Icon(
                                                          weight: 3,
                                                          size: 50,
                                                          Icons.done,
                                                          color:
                                                              Colors.blueAccent,
                                                        )
                                                        : const Icon(
                                                          weight: 3,
                                                          size: 50,
                                                          Icons.sync,
                                                          color: Colors.orange,
                                                        ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  //Text(capturedImages[index]), to show the image path.
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide.none,
                                      // the height is 50, the width is full
                                      minimumSize: const Size.fromHeight(30),
                                      shadowColor: Colors.blue,
                                      elevation: 0,
                                    ),
                                    onPressed: () {
                                      removePhoto(
                                        context,
                                        currentVisualSection,
                                        index,
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    label: const Text(
                                      'Remove Photo',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ),
                  ),
              const SizedBox(height: 4),
              const Divider(
                color: Color.fromARGB(255, 222, 213, 213),
                height: 20,
                thickness: 1,
                indent: 2,
                endIndent: 2,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Further invasive review required',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Switch(
                    onChanged: (value) {
                      toggleSwitchInvasive(value);
                      isFormUpdated = true;
                    },
                    value: invasiveReviewRequired,
                  ),
                ],
              ),
              const Divider(
                color: Color.fromARGB(255, 222, 213, 213),
                height: 15,
                thickness: 1,
                indent: 2,
                endIndent: 2,
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text('Additional considerations or concerns')],
              ),
              const SizedBox(height: 8),
              inputWidgetwithNoValidation(
                'Additonal Considerations',
                'Please enter details',
                5,
                _concernsController,
              ),
              const SizedBox(height: 4),
              const Divider(
                color: Color.fromARGB(255, 222, 213, 213),
                height: 15,
                thickness: 1,
                indent: 2,
                endIndent: 2,
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: questions.length,
                itemBuilder: (BuildContext context, int index) {
                  var question = questions[index];
                  if (question.type.toLowerCase() == 'text') {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        Text(
                          question.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 5),
                        TextFormField(
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.only(
                              left: 5,
                              top: 2.0,
                              bottom: 2.0,
                            ),
                            hintText: question.name,
                            hintStyle: const TextStyle(
                              fontSize: 13.0,
                              color: Color(0xFFABB3BB),
                              height: 1.0,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          initialValue: question.answer,
                          onChanged: (value) {
                            question.answer = value;
                          },
                        ),
                      ],
                    );
                  } else if (question.type.toLowerCase() == 'textarea') {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        Text(
                          question.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 5),
                        TextFormField(
                          initialValue: question.answer,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.only(
                              left: 5,
                              top: 2.0,
                              bottom: 2.0,
                            ),
                            hintText: question.name,
                            hintStyle: const TextStyle(
                              fontSize: 13.0,
                              color: Color(0xFFABB3BB),
                              height: 1.0,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          minLines: 5,
                          maxLines: 20,
                          onChanged: (value) {
                            question.answer = value;
                          },
                        ),
                        // const Divider(
                        //   color: Color.fromARGB(255, 222, 213, 213),
                        //   height: 15,
                        //   thickness: 1,
                        //   indent: 2,
                        //   endIndent: 2,
                        // ),
                      ],
                    );
                  } else if (question.type.toLowerCase() == 'radiobutton') {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        Text(
                          question.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 5),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: question.allowedValues.length,
                          itemBuilder: (context, indexVal) {
                            var valuesData = question.allowedValues[indexVal];
                            return Row(
                              children: <Widget>[
                                SizedBox(
                                  height: 30,
                                  child: Radio<String>(
                                    value: valuesData,
                                    groupValue: question.answer,
                                    onChanged: (val) {
                                      question.answer = val as String;

                                      setState(() {});
                                    },
                                  ),
                                ),
                                Text(valuesData),
                              ],
                            );
                          },
                        ),
                        const Divider(
                          color: Color.fromARGB(255, 222, 213, 213),
                          height: 15,
                          thickness: 1,
                          indent: 2,
                          endIndent: 2,
                        ),
                      ],
                    );
                  } else if (question.type.toLowerCase() == 'togglebutton') {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          question.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Switch(
                          onChanged: (value) {
                            setState(() {
                              question.answer = value.toString();
                            });

                            isFormUpdated = true;
                          },
                          value: question.answer.toUpperCase() == 'TRUE',
                        ),
                        const Divider(
                          color: Color.fromARGB(255, 222, 213, 213),
                          height: 15,
                          thickness: 1,
                          indent: 2,
                          endIndent: 2,
                        ),
                      ],
                    );
                  } else if (question.type.toLowerCase() == 'checkbox') {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        Text(
                          question.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 5),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          itemCount: question.allowedValues.length,
                          itemBuilder: (context, indexVal) {
                            var valuesData = question.allowedValues[indexVal];
                            var selectedValue = question.multipleAnswers
                                .firstWhereOrNull(
                                  (element) => element == valuesData,
                                );

                            return Row(
                              children: [
                                SizedBox(
                                  height: 30,
                                  child: Checkbox(
                                    value: selectedValue == null ? false : true,
                                    onChanged: (val) {
                                      setState(() {
                                        var selectedValue = question
                                            .multipleAnswers
                                            .firstWhereOrNull(
                                              (element) =>
                                                  element == valuesData,
                                            );

                                        if (selectedValue == null) {
                                          question.multipleAnswers.add(
                                            valuesData,
                                          );
                                        } else {
                                          question.multipleAnswers.remove(
                                            selectedValue,
                                          );
                                        }
                                      });
                                    },
                                  ),
                                ),
                                Text(valuesData),
                              ],
                            );
                          },
                        ),
                        const Divider(
                          color: Color.fromARGB(255, 222, 213, 213),
                          height: 15,
                          thickness: 1,
                          indent: 2,
                          endIndent: 2,
                        ),
                      ],
                    );
                  } else if (question.type.toLowerCase() == 'dropdown') {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        Text(
                          question.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 5),
                        DropdownButtonFormField(
                          // decoration:
                          //     InputDecoration(hintText: question.name),
                          value:
                              question.answer.isEmpty ? null : question.answer,
                          items:
                              question.allowedValues
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(
                                        value,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            question.answer = value as String;
                          },
                        ),
                      ],
                    );
                  } else if (question.type.toLowerCase() == 'date') {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        Text(
                          question.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 5),
                        TextFormField(
                          decoration: InputDecoration(hintText: question.name),
                          readOnly: true,
                          //initialValue: question.defaultValue ?? '',
                          controller: TextEditingController(
                            text: question.answer,
                          ),
                          onTap: () async {
                            try {
                              DateFormat inputFormat = DateFormat('MM-dd-yyyy');
                              var date = DateTime.now();
                              DateTime? pickedDate = await showDatePicker(
                                context: context,
                                initialDate:
                                    question.answer.isEmpty
                                        ? date
                                        : inputFormat.parse(question.answer),
                                firstDate: DateTime.parse(
                                  "01-01-2000",
                                ), //DateTime.now() - not to allow to choose before today.
                                lastDate: DateTime.parse("12-31-2030"),
                              );
                              if (pickedDate != null) {
                                String formattedDate = inputFormat.format(
                                  pickedDate,
                                );

                                setState(() {
                                  question.answer = formattedDate;
                                });
                              } else {
                                //update the form state.
                              }
                            } catch (ex) {
                              debugPrint(ex.toString());
                            }
                          },
                        ),
                      ],
                    );
                  } else {
                    return Container();
                  }
                },
              ),
              isNewSection
                  ? Container()
                  : Padding(
                    padding: const EdgeInsets.all(0),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide.none,
                        // the height is 50, the width is full
                        minimumSize: const Size.fromHeight(30),
                        backgroundColor: Colors.white,
                        shadowColor: Colors.blue,
                        elevation: 0,
                      ),
                      onPressed: () {
                        deleteSection(context, currentVisualSection);
                      },
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text(
                        'Delete Location',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  void deleteSection(
    BuildContext context,
    DynamicVisualSection currentVisualSection,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleting ${currentVisualSection.name}')),
    );
    context.read<DynamicVisualSectionBloc>().add(
      DeleteDynamicVisualSection(currentVisualSection),
    );
  }

  bool isSaved = false;
  void save(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      if (!unitUnavailable) {
        for (Question question in questions) {
          if (question.isMandatory) {
            if (question.answer.isEmpty && question.multipleAnswers.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${question.name} is empty, please fill all values to save the location...',
                  ),
                ),
              );
              return;
            }
          }
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saving Location...')));
      }

      currentVisualSection.images = List<String>.from(capturedImages);
      context.read<DynamicVisualSectionBloc>().add(
        SaveDynamicVisualSection(
          section: currentVisualSection,
          name: _nameController.text,
          concerns: _concernsController.text,
          questions: questions,
          invasiveReviewRequired: invasiveReviewRequired,
          unitUnavailable: unitUnavailable,
          isNewSection: isNewSection,
          userFullName: userFullName,
        ),
      );
    }
  }
}
