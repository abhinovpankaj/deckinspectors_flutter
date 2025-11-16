import 'dart:io';
import 'dart:typed_data';
import 'package:E3InspectionsMultiTenant/src/models/realm/realm_schemas.dart';
import 'package:E3InspectionsMultiTenant/src/ui/image_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:realm/realm.dart';
import 'package:path/path.dart' as path;
import '../bloc/images_bloc.dart';
import '../bloc/settings_bloc.dart';
import '../models/success_response.dart';
import '../resources/realm/realm_services.dart';
import '../services/signalling.service.dart';
import 'capture_multipic_esp_32.dart';
import 'capture_multipic_raspi.dart';
import 'capturemultipic.dart';
import 'package:http/http.dart' as http;

class DynamicVisualSectionPage extends StatefulWidget {
  final ObjectId sectionId;
  final String userFullName;
  final String parentType;
  final ObjectId parentId;
  final String parentName;
  final bool isNewSection;
  final ObjectId formId;
  const DynamicVisualSectionPage(
      this.sectionId,
      this.parentId,
      this.userFullName,
      this.parentType,
      this.parentName,
      this.isNewSection,
      this.formId,
      {super.key});

  static MaterialPageRoute getRoute(
          ObjectId id,
          ObjectId parentId,
          String userName,
          String parentType,
          String parentName,
          ObjectId formId,
          bool isNewSection,
          String pageName) =>
      MaterialPageRoute(
          settings: RouteSettings(name: pageName),
          builder: (context) => DynamicVisualSectionPage(id, parentId, userName,
              parentType, parentName, isNewSection, formId));
  @override
  State<DynamicVisualSectionPage> createState() =>
      _DynamicVisualSectionPageState();
}

class _DynamicVisualSectionPageState extends State<DynamicVisualSectionPage> {
  //late DynamicVisualSection _dynamicVisualSection;

  late RealmProjectServices realmServices;
  List<String> capturedImages = [];
  List<Question> questions = [];
  @override
  void initState() {
    realmServices = Provider.of<RealmProjectServices>(context, listen: false);
    isNewSection = widget.isNewSection;

    if (isNewSection) {
      var locationForm = realmServices.getCurrentForm();
      if (locationForm != null) {
        for (Question question in locationForm.questions) {
          questions.add(Question(
              question.id, question.type, question.name, question.answer,
              allowedValues: question.allowedValues,
              isMandatory: question.isMandatory,
              multipleAnswers: question.multipleAnswers));
        }
      }
      currentVisualSection = getNewDynamicVisualSection();
      capturedImages = [];
    } else {
      capturedImages.clear();
      fetchData();
    }
    userFullName = widget.userFullName;

    prevPageName = widget.parentName;

    if (parentType != 'project') {
      currentLocation = realmServices.getLocation(widget.parentId) as Location;
    }
    websocketUrl = "http://192.168.125.1:8090";
    SignallingService.instance.init(
      websocketUrl: websocketUrl,
      selfCallerID: selfCallerID,
    );
    super.initState();
  }

  String websocketUrl = ""; // = "ws://192.168.1.2:8090";

  // generate callerID of local user
  final String selfCallerID = 'e3camReceiver';

  bool isFormUpdated = false;
  bool isRunning = false;
  String userFullName = "";
  String parentType = "";
  late DynamicVisualSection currentVisualSection;
  late Location currentLocation;
  late Future sectionResponse;
  late bool isNewSection;
  late String prevPageName;
  final TextEditingController _nameController = TextEditingController(text: '');
  final TextEditingController _concernsController =
      TextEditingController(text: '');
  bool invasiveReviewRequired = false;
  bool unitUnavailable = false;
  late ObjectId formId;
  void fetchData() {
    isRunning = true;

    currentVisualSection = realmServices
        .getDynamicVisualSection(widget.sectionId) as DynamicVisualSection;

    setInitialValues();
    isRunning = false;
  }

  void setInitialValues() {
    //Set all values before returning the widget.
    formId = widget.formId;
    _nameController.text = currentVisualSection.name as String;
    unitUnavailable = currentVisualSection.unitUnavailable;
    if (!currentVisualSection.unitUnavailable) {
      _concernsController.text =
          currentVisualSection.additionalconsiderations as String;
      invasiveReviewRequired =
          currentVisualSection.furtherinvasivereviewrequired;
    }
    for (Question question in currentVisualSection.questions) {
      questions.add(Question(
          question.id, question.type, question.name, question.answer,
          allowedValues: question.allowedValues,
          isMandatory: question.isMandatory,
          multipleAnswers: question.multipleAnswers));
    }
    if (currentVisualSection.images.isNotEmpty) {
      if (appSettings.activeConnection) {
        capturedImages.addAll(currentVisualSection.images);
        //call upload local images

        //realmServices.uploadLocalImages();
      } else {
        for (var imgpath in currentVisualSection.images) {
          capturedImages.add(realmServices.getlocalPath(imgpath));
        }
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
            onPressed: () async {
              if (isFormUpdated) {
                bool? cangoback = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Save Section'),
                    content: const Text('Do you want to discard the changes?'),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () {
                          Navigator.of(context, rootNavigator: true).pop(false);
                        },
                        child: const Text('No'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context, rootNavigator: true).pop(true);
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
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.blue,
            ),
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
                    color: Colors.black, fontWeight: FontWeight.normal),
              ),
              InkWell(
                  onTap: () {
                    save(context, realmServices, false);
                  },
                  child: const Chip(
                    avatar: Icon(
                      Icons.save_outlined,
                      color: Colors.black,
                    ),
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
                  )),
            ],
          )),
      body: isRunning
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  sectionForm(context),
                ],
              ),
            ),
    );
  }

  DynamicVisualSection getNewDynamicVisualSection() {
    return DynamicVisualSection(
      ObjectId(), widget.parentId, false,
      parenttype: parentType,
      createdby: userFullName,
      furtherinvasivereviewrequired: false,
      // questions: questions //make it parameterized.
    );
  }

  List<Question> getQuestions() {
    return [
      Question(ObjectId(), 'Textbox', 'Location name', 'Test1'),
      Question(ObjectId(), 'TextArea', 'Location description', 'testing'),
      Question(ObjectId(), 'Date', 'Location inspected on', '06-19-2024'),
      Question(ObjectId(), 'CheckBox', 'Location type', 'mall',
          multipleAnswers: ['mall', 'Apartment'],
          allowedValues: ['Building', 'mall', 'Apartment']),
      Question(ObjectId(), 'Dropdown', 'Location EEE', '9+',
          allowedValues: ['1-4', '1-2', '3-5', '7-8', '9+']),
      Question(ObjectId(), 'Dropdown', 'Location AWE', '',
          allowedValues: ['1-4', '1-2', '3-5', '7-8', '9+']),
      Question(ObjectId(), 'RadioButton', 'Location name', 'Bad',
          allowedValues: ['Fair', 'Good', 'Bad'])
    ];
  }

  Widget inputWidgetwithValidation(String hint, String message, int lines,
      TextEditingController controller) {
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
            contentPadding:
                const EdgeInsets.only(left: 5, top: 2.0, bottom: 2.0),
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 13.0,
              color: Color(0xFFABB3BB),
              height: 1.0,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            )));
  }

  Widget inputWidgetwithNoValidation(String hint, String message, int lines,
      TextEditingController controller) {
    return TextFormField(
        controller: controller,
        maxLines: lines,
        decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.only(left: 5, top: 2.0, bottom: 2.0),
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 13.0,
              color: Color(0xFFABB3BB),
              height: 1.0,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            )));
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
      String title, IconData iconData, int position) {
    return PopupMenuItem(
      value: position,
      child: Row(
        children: [
          Icon(
            iconData,
            color: Colors.blue,
          ),
          const SizedBox(
            width: 15,
          ),
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
      BuildContext context, String capturedImage, int index) async {
    Uint8List imageData;

    if (capturedImage.contains('http')) {
      http.Response response = await http.get(
        Uri.parse(capturedImage),
      );
      imageData = response.bodyBytes;
    } else {
      if (File(capturedImage).existsSync()) {
        imageData = await File(capturedImage).readAsBytes();
      } else {
        return;
      }
    }

    var editedImage = await Navigator.push(context,
        MaterialPageRoute(builder: (context) => ImageEditor(image: imageData)));
    //update capturedimages collection.
    final directory = await getApplicationDocumentsDirectory();
    var destDirectory =
        await Directory(path.join(directory.path, 'editedimages'))
            .create(recursive: true);
    String imageid = ObjectId().toString();
    final pathOfImage =
        await File('${destDirectory.path}/$imageid.jpg').create();
    if (editedImage != null) {
      var editedFile = await pathOfImage.writeAsBytes(editedImage);
      setState(() {
        capturedImages.removeAt(index);

        realmServices.removeImageUrlFromDynamic(
            currentVisualSection, capturedImage);
        capturedImages.insert(index, editedFile.path);
      });
    }
  }

  void removePhoto(BuildContext context,
      DynamicVisualSection currentVisualSection, int index) {
    realmServices.removeImageUrlFromDynamic(
        currentVisualSection, capturedImages[index]);
    setState(() {
      capturedImages.removeAt(index);
    });
  }

  final _formKey = GlobalKey<FormState>();
  Widget sectionForm(BuildContext context) {
    return GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
            onChanged: () => setState(() {
                  isFormUpdated = true;
                }),
            key: _formKey,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Location name'),
                  const SizedBox(
                    height: 8,
                  ),
                  inputWidgetwithValidation('Location Name',
                      'Please enter location name', 1, _nameController),
                  const SizedBox(
                    height: 4,
                  ),
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
                        itemBuilder: (ctx) => [
                          _buildPopupMenuItem(
                              'Camera', Icons.camera_alt_outlined, 1),
                          _buildPopupMenuItem(
                              'Gallery', Icons.browse_gallery_outlined, 2),
                          _buildPopupMenuItem('External Mobile Cam',
                              Icons.camera_outdoor_outlined, 3),
                          _buildPopupMenuItem(
                              'E3 Cam', Icons.camera_outdoor_outlined, 4),
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
                          )))
                      : SizedBox(
                          height: MediaQuery.of(context).size.height / 3.2,
                          child: ListView.builder(
                            shrinkWrap: true,
                            scrollDirection: Axis.horizontal,
                            itemCount: capturedImages.length,
                            itemBuilder: (BuildContext context, int index) =>
                                SizedBox(
                                    width: 320,
                                    height: 200,
                                    child: Padding(
                                        padding: const EdgeInsets.all(2),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: GestureDetector(
                                                onTap: () =>
                                                    gotoImageEditorPage(
                                                        context,
                                                        capturedImages[index],
                                                        index),
                                                child: Container(
                                                    margin: const EdgeInsets
                                                        .fromLTRB(2, 8, 8, 0),
                                                    height: 180,
                                                    width: 300,
                                                    decoration:
                                                        const BoxDecoration(
                                                            color: Colors.blue,
                                                            // image: DecorationImage(
                                                            //     image:
                                                            //         AssetImage('assets/images/icon.png'),
                                                            //     fit: BoxFit.cover),
                                                            borderRadius: BorderRadius.all(Radius.circular(8.0)),
                                                            boxShadow: [
                                                          BoxShadow(
                                                              blurRadius: 1.0,
                                                              color:
                                                                  Colors.blue)
                                                        ]),
                                                    child: ClipRRect(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8.0),
                                                        child: Stack(
                                                          fit: StackFit.expand,
                                                          children: [
                                                            networkImage(
                                                                capturedImages[
                                                                    index]),
                                                            Align(
                                                                alignment: Alignment
                                                                    .bottomRight,
                                                                child: capturedImages[
                                                                            index]
                                                                        .startsWith(
                                                                            'http')
                                                                    ? const Icon(
                                                                        weight:
                                                                            3,
                                                                        size:
                                                                            50,
                                                                        Icons
                                                                            .done,
                                                                        color: Colors
                                                                            .blueAccent)
                                                                    : const Icon(
                                                                        weight:
                                                                            3,
                                                                        size:
                                                                            50,
                                                                        Icons
                                                                            .sync,
                                                                        color: Colors
                                                                            .orange))
                                                          ],
                                                        ))),
                                              ),
                                            ),
                                            //Text(capturedImages[index]), to show the image path.
                                            OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                    side: BorderSide.none,
                                                    // the height is 50, the width is full
                                                    minimumSize:
                                                        const Size.fromHeight(
                                                            30),
                                                    shadowColor: Colors.blue,
                                                    elevation: 0),
                                                onPressed: () {
                                                  removePhoto(
                                                      context,
                                                      currentVisualSection,
                                                      index);
                                                },
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.red,
                                                ),
                                                label: const Text(
                                                    'Remove Photo',
                                                    style: TextStyle(
                                                        color: Colors.red))),
                                          ],
                                        ))),
                          )),
                  const SizedBox(
                    height: 4,
                  ),
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
                    children: [
                      Text('Additional considerations or concerns'),
                    ],
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  inputWidgetwithNoValidation('Additonal Considerations',
                      'Please enter details', 5, _concernsController),
                  const SizedBox(
                    height: 4,
                  ),
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
                              const SizedBox(
                                height: 10,
                              ),
                              Text(
                                question.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(
                                height: 5,
                              ),
                              TextFormField(
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.only(
                                        left: 5, top: 2.0, bottom: 2.0),
                                    hintText: question.name,
                                    hintStyle: const TextStyle(
                                      fontSize: 13.0,
                                      color: Color(0xFFABB3BB),
                                      height: 1.0,
                                    ),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  initialValue: question.answer,
                                  onChanged: (value) {
                                    question.answer = value;
                                  }),
                            ],
                          );
                        } else if (question.type.toLowerCase() == 'textarea') {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(
                                height: 10,
                              ),
                              Text(
                                question.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(
                                height: 5,
                              ),
                              TextFormField(
                                initialValue: question.answer,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.only(
                                      left: 5, top: 2.0, bottom: 2.0),
                                  hintText: question.name,
                                  hintStyle: const TextStyle(
                                    fontSize: 13.0,
                                    color: Color(0xFFABB3BB),
                                    height: 1.0,
                                  ),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
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
                        } else if (question.type.toLowerCase() ==
                            'radiobutton') {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(
                                height: 10,
                              ),
                              Text(
                                question.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(
                                height: 5,
                              ),
                              ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: question.allowedValues.length,
                                  itemBuilder: (context, indexVal) {
                                    var valuesData =
                                        question.allowedValues[indexVal];
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
                                  }),
                              const Divider(
                                color: Color.fromARGB(255, 222, 213, 213),
                                height: 15,
                                thickness: 1,
                                indent: 2,
                                endIndent: 2,
                              ),
                            ],
                          );
                        } else if (question.type.toLowerCase() ==
                            'togglebutton') {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                question.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
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
                              const SizedBox(
                                height: 10,
                              ),
                              Text(
                                question.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(
                                height: 5,
                              ),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: EdgeInsets.zero,
                                itemCount: question.allowedValues.length,
                                itemBuilder: (context, indexVal) {
                                  var valuesData =
                                      question.allowedValues[indexVal];
                                  var selectedValue = question.multipleAnswers
                                      .firstWhereOrNull(
                                          (element) => element == valuesData);

                                  return Row(
                                    children: [
                                      SizedBox(
                                        height: 30,
                                        child: Checkbox(
                                            value: selectedValue == null
                                                ? false
                                                : true,
                                            onChanged: (val) {
                                              setState(() {
                                                var selectedValue = question
                                                    .multipleAnswers
                                                    .firstWhereOrNull(
                                                        (element) =>
                                                            element ==
                                                            valuesData);

                                                if (selectedValue == null) {
                                                  question.multipleAnswers
                                                      .add(valuesData);
                                                } else {
                                                  question.multipleAnswers
                                                      .remove(selectedValue);
                                                }
                                              });
                                            }),
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
                              const SizedBox(
                                height: 10,
                              ),
                              Text(
                                question.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(
                                height: 5,
                              ),
                              DropdownButtonFormField(
                                // decoration:
                                //     InputDecoration(hintText: question.name),
                                value: question.answer.isEmpty
                                    ? null
                                    : question.answer,
                                items: question.allowedValues
                                    .map((value) => DropdownMenuItem(
                                          value: value,
                                          child: Text(
                                            value,
                                            style:
                                                const TextStyle(fontSize: 16),
                                          ),
                                        ))
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
                              const SizedBox(
                                height: 10,
                              ),
                              Text(
                                question.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(
                                height: 5,
                              ),
                              TextFormField(
                                decoration:
                                    InputDecoration(hintText: question.name),
                                readOnly: true,
                                //initialValue: question.defaultValue ?? '',
                                controller: TextEditingController(
                                    text: question.answer),
                                onTap: () async {
                                  try {
                                    DateFormat inputFormat =
                                        DateFormat('MM-dd-yyyy');
                                    var date = DateTime.now();
                                    DateTime? pickedDate = await showDatePicker(
                                      context: context,
                                      initialDate: question.answer.isEmpty
                                          ? date
                                          : inputFormat.parse(question.answer),
                                      firstDate: DateTime.parse(
                                          "01-01-2000"), //DateTime.now() - not to allow to choose before today.
                                      lastDate: DateTime.parse("12-31-2030"),
                                    );
                                    if (pickedDate != null) {
                                      String formattedDate =
                                          inputFormat.format(pickedDate);

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
                              )
                            ],
                          );
                        } else {
                          return Container();
                        }
                      }),
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
                                  elevation: 0),
                              onPressed: () {
                                deleteSection(context, currentVisualSection);
                              },
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              label: const Text('Delete Location',
                                  style: TextStyle(color: Colors.red))),
                        ),
                  const SizedBox(
                    height: 100,
                  ),
                ],
              ),
            )));
  }

  void deleteSection(
      BuildContext context, DynamicVisualSection currentVisualSection) {
    var locationame = currentVisualSection.name;
    Navigator.of(context).pop();

    //var result = 'success';
    var result = realmServices.deleteVisualSectionDynamic(currentVisualSection);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleting $locationame')),
    );

    if (result == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${currentVisualSection.name} deleted successfully.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete the $locationame')),
      );
    }
  }

  bool isSaved = false;
  Future<bool> save(BuildContext context, RealmProjectServices realmServices,
      bool createNew) async {
    if (_formKey.currentState!.validate()) {
      //check if everything is filled.
      if (unitUnavailable) {
      } else {
        for (Question question in questions) {
          if (question.isMandatory) {
            if (question.answer.isEmpty && question.multipleAnswers.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        '${question.name} is empty, please fill all values to save the location...')),
              );
              return false;
            }
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saving Location...')),
        );
      }
      var saveResult = realmServices.addupdateDynamicVisualSection(
          currentVisualSection,
          _nameController.text,
          _concernsController.text,
          invasiveReviewRequired,
          isNewSection,
          userFullName,
          questions,
          unitUnavailable);

      if (saveResult) {
        isSaved = true;
        Navigator.of(context).pop(createNew);

        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location saved successfully.')));
        if (capturedImages.isNotEmpty) {
          var imagesToUpload = await realmServices.getImagesNotUploaded(
              capturedImages, appSettings.activeConnection, isNewSection);

          if (imagesToUpload.isNotEmpty) {
            if (parentType != 'project') {
              realmServices.updateImageUploadStatus(
                  currentLocation, currentVisualSection.id, true);
            }
            List<String> transformedimagesPath = [];
            // update the path of the images
            if (Platform.isIOS) {
              Directory imageDirectory = await getApplicationSupportDirectory();
              transformedimagesPath = imagesToUpload
                  .map((imgpath) =>
                      imgpath = path.join(imageDirectory.path, imgpath))
                  .toList();
            } else {
              transformedimagesPath = imagesToUpload;
            }

            imagesBloc
                .uploadMultipleImages(
                    transformedimagesPath,
                    currentVisualSection.name as String,
                    userFullName,
                    currentVisualSection.id.toString(),
                    parentType,
                    'section')
                .then((value) async {
              List<String> urls = [];
              for (var element in value) {
                if (element is ImageResponse) {
                  if (element.originalPath != null) {
                    await ImageGallerySaver.saveFile(
                        element.originalPath as String);
                  }

                  urls.add(element.url as String);
                }
              }
              if (parentType != 'project') {
                realmServices.updateImageUploadStatus(
                    currentLocation, currentVisualSection.id, false);
              }

              realmServices.addImagesUrlToDynamicform(
                  currentVisualSection, imagesToUpload, urls);
            });
          }
        }
        return true;
        // Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save the location.')),
        );
        return false;
      }
    }
    return false;
  }
}
