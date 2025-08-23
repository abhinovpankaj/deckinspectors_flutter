import 'dart:io';

import 'package:E3InspectionsMultiTenant/src/bloc/images_bloc.dart';
import 'package:E3InspectionsMultiTenant/src/services/realm_local_services.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';

import 'package:provider/provider.dart';
import 'package:realm/realm.dart';
import '../bloc/settings_bloc.dart';
import '../models/exteriorelements.dart';
import '../models/realm/realm_schemas.dart';
import 'package:http/http.dart' as http;
import '../models/success_response.dart';
import 'package:path/path.dart' as path;
import 'capturemultipic.dart';
import 'image_widget.dart';
import 'package:image_picker/image_picker.dart';

import 'section.dart';

class InvasiveSectionPage extends StatefulWidget {
  final ObjectId sectionId;
  final String userFullName;
  final String parentType;
  final ObjectId parentId;
  final String parentName;
  final bool isNewSection;
  const InvasiveSectionPage(
    this.sectionId,
    this.parentId,
    this.userFullName,
    this.parentType,
    this.parentName,
    this.isNewSection, {
    super.key,
  });
  //VisualSection currentSection;
  static MaterialPageRoute getRoute(
    ObjectId id,
    ObjectId parentId,
    String userName,
    String parentType,
    String parentName,
    bool isNewSection,
    String pageName,
  ) => MaterialPageRoute(
    settings: RouteSettings(name: pageName),
    builder:
        (context) => InvasiveSectionPage(
          id,
          parentId,
          userName,
          parentType,
          parentName,
          isNewSection,
        ),
  );
  @override
  State<InvasiveSectionPage> createState() => _InvasiveSectionPageState();
}

class _InvasiveSectionPageState extends State<InvasiveSectionPage>
    with SingleTickerProviderStateMixin {
  late RealmLocalServices realmServices;
  //late TabController _tabController;
  late int selectedTabIndex = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 120,
        leading: ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.blue),
          label: Text(
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            prevPageName,
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
            const Text(
              'Details',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.normal,
              ),
            ),
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
        ),
      ),
      body:
          isRunning
              ? const Center(child: CircularProgressIndicator())
              : projectChildrenTab(context),
    );
  }

  bool isRunning = false;
  String userFullName = "";
  String parentType = "";
  late VisualSection currentVisualSection;
  late InvasiveSection currentInvasiveSection;
  late ConclusiveSection currentConclusiveSection;
  late Future sectionResponse;
  late bool isNewSection;
  late String prevPageName;
  late int _tabBarCount;

  void fetchData() {
    isRunning = true;
    currentVisualSection =
        realmServices.getVisualSection(widget.sectionId) as VisualSection;
    currentInvasiveSection = realmServices.getInvasiveSection(widget.sectionId);

    currentConclusiveSection = realmServices.getConclusiveSection(
      widget.sectionId,
    );
    if (currentInvasiveSection.postinvasiverepairsrequired) {
      _tabBarCount = 3;
    } else {
      _tabBarCount = 2;
    }
    setInitialValues();
    isRunning = false;
  }

  List<Widget> getTabs() {
    switch (_tabBarCount) {
      case 2:
        return [visualSectionWidget(), invasiveSectionWidget()];

      case 3:
        return [
          visualSectionWidget(),
          invasiveSectionWidget(),
          conclusiveSectionWidget(),
        ];

      default:
        return [];
    }
  }

  Widget projectChildrenTab(BuildContext context) {
    return DefaultTabController(
      length: _tabBarCount,
      child: Column(
        children: <Widget>[
          TabBar(
            tabs:
                _tabBarCount == 3
                    ? const [
                      Tab(text: "Visual Details", height: 32),
                      Tab(text: "Invasive Details", height: 32),
                      Tab(text: "Conclusive Details", height: 32),
                    ]
                    : const [
                      Tab(text: "Visual Details", height: 32),
                      Tab(text: "Invasive Details", height: 32),
                    ],
            labelColor: Colors.black,
          ),
          Expanded(
            child: SingleChildScrollView(
              child: SizedBox(
                height:
                    MediaQuery.of(context).textScaleFactor > 1
                        ? MediaQuery.of(context).size.height * 1.8
                        : MediaQuery.of(context).size.height * 1.5,
                child: TabBarView(children: getTabs()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    // _tabController = TabController(vsync: this, length: _tabBarCount);

    // _tabController.addListener(_handleTabSelection);

    realmServices = Provider.of<RealmLocalServices>(context, listen: false);
    isNewSection = widget.isNewSection;

    capturedImages.clear();
    fetchData();

    userFullName = widget.userFullName;
    parentType = widget.parentType;
    prevPageName = widget.parentName;

    super.initState();
  }

  @override
  void dispose() {
    //_tabController.dispose();
    super.dispose();
  }

  void setInitialValues() {
    //Set all values before returning the widget.
    _nameController.text = currentVisualSection.name as String;
    _concernsController.text =
        currentVisualSection.additionalconsiderations as String;
    selectedExteriorelements =
        exteriorElements
            .where(
              (item) =>
                  currentVisualSection.exteriorelements.contains(item.name),
            )
            .toList();

    selectedWaterproofingElements =
        waterproofingElements
            .where(
              (item) => currentVisualSection.waterproofingelements.contains(
                item.name,
              ),
            )
            .toList();

    _review = VisualReview.values.firstWhere(
      (e) => e.name == currentVisualSection.visualreview?.toLowerCase(),
    );
    _assessment = ConditionalAssessment.values.firstWhere(
      (e) =>
          e.name == currentVisualSection.conditionalassessment?.toLowerCase(),
    );

    _eee = ExpectancyYears.values.firstWhere(
      (e) => e.name == currentVisualSection.eee,
    );
    _lbc = ExpectancyYears.values.firstWhere(
      (e) => e.name == currentVisualSection.lbc,
    );
    _awe = ExpectancyYears.values.firstWhere(
      (e) => e.name == currentVisualSection.awe,
    );

    invasiveReviewRequired = currentVisualSection.furtherinvasivereviewrequired;
    hasSignsOfLeak = currentVisualSection.visualsignsofleak;
    if (currentVisualSection.images.isNotEmpty) {
      capturedImages.addAll(currentVisualSection.images);
    }
    //add invasive details
    postInvasiveRepairsRequired =
        currentInvasiveSection.postinvasiverepairsrequired;
    _invasiveDescriptionController.text =
        currentInvasiveSection.invasiveDescription;
    if (currentInvasiveSection.invasiveimages.isNotEmpty) {
      capturedInvasiveImages.addAll(currentInvasiveSection.invasiveimages);
    }
    //add conclusive details
    propOwnerAgreed = currentConclusiveSection.propowneragreed;
    invasiveRepairsCompleted =
        currentConclusiveSection.invasiverepairsinspectedandcompleted;

    if (currentConclusiveSection.eeeconclusive != "") {
      _eeeConclusive = ExpectancyYears.values.firstWhere(
        (e) => e.name == currentConclusiveSection.eeeconclusive,
      );
    }
    if (currentConclusiveSection.lbcconclusive != "") {
      _lbcConclusive = ExpectancyYears.values.firstWhere(
        (e) => e.name == currentConclusiveSection.lbcconclusive,
      );
    }

    if (currentConclusiveSection.aweconclusive != "") {
      _aweConclusive = ExpectancyYears.values.firstWhere(
        (e) => e.name == currentConclusiveSection.aweconclusive,
      );
    }

    if (currentConclusiveSection.conclusiveimages.isNotEmpty) {
      capturedConclusiveImages.addAll(
        currentConclusiveSection.conclusiveimages,
      );
    }
    _conclusiveDescriptionController.text =
        currentConclusiveSection.conclusiveconsiderations;
  }

  final TextEditingController _nameController = TextEditingController(text: '');
  final TextEditingController _concernsController = TextEditingController(
    text: '',
  );
  final TextEditingController _invasiveDescriptionController =
      TextEditingController(text: '');
  final TextEditingController _conclusiveDescriptionController =
      TextEditingController(text: '');

  save(BuildContext context, RealmLocalServices realmServices) async {
    if (_invasiveDescriptionController.text.isEmpty ||
        capturedInvasiveImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please add Invasive description and images to save the location.',
          ),
        ),
      );
      return;
    }
    if (postInvasiveRepairsRequired) {
      if (invasiveRepairsCompleted) {
        if (_conclusiveDescriptionController.text.isEmpty ||
            capturedConclusiveImages.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please add Invasive description and images to save the location.',
              ),
            ),
          );
          return;
        }
        if (_eeeConclusive == null ||
            _lbcConclusive == null ||
            _aweConclusive == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please add all the details to save the location.'),
            ),
          );
          return;
        }
      }
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Saving Location...')));
    var saveResult = realmServices.addupdateInvasiveSection(
      currentInvasiveSection,
      _invasiveDescriptionController.text,
      postInvasiveRepairsRequired,
    );

    if (!mounted) {
      return;
    }
    bool conclusiveSaveResult = false;
    if (postInvasiveRepairsRequired) {
      if (!invasiveRepairsCompleted) {
        conclusiveSaveResult = realmServices.addupdateConclusiveSection(
          currentConclusiveSection,
          propOwnerAgreed,
          invasiveRepairsCompleted,
          "",
          "",
          "",
          "",
        );
      } else {
        conclusiveSaveResult = realmServices.addupdateConclusiveSection(
          currentConclusiveSection,
          propOwnerAgreed,
          invasiveRepairsCompleted,
          _eeeConclusive!.name,
          _lbcConclusive!.name,
          _aweConclusive!.name,
          _conclusiveDescriptionController.text,
        );
      }
    } else {
      conclusiveSaveResult = true;
    }
    if (saveResult && conclusiveSaveResult) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location invasive/conclusive details saved successfully.',
          ),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to save the invasive/conclusive details of the location.',
          ),
        ),
      );
    }
    if (saveResult) {
      String invasiveImageName =
          '${currentVisualSection.name as String}-invasive';
      if (capturedInvasiveImages.isNotEmpty) {
        // var imagesToUpload =
        //     capturedInvasiveImages.where((e) => !e.startsWith('http')).toList();
        var imagesToUpload = await realmServices.getImagesNotUploaded(
          capturedInvasiveImages,
          appSettings.activeConnection,
          isNewSection,
        );
        if (imagesToUpload.isNotEmpty) {
          imagesBloc
              .uploadMultipleImages(
                imagesToUpload,
                invasiveImageName,
                userFullName,
                currentInvasiveSection.id.toString(),
                parentType,
                'invasivesection',
              )
              .then((value) async {
                List<String> urls = [];
                for (var element in value) {
                  if (element is ImageResponse) {
                    await GallerySaver.saveImage(
                      element.originalPath as String,
                    );
                    urls.add(element.url as String);
                  }
                }
                realmServices.addInvasiveImagesUrl(
                  invasiveImageName,
                  currentInvasiveSection,
                  urls,
                );
              });
        }
      }
      if (invasiveRepairsCompleted) {
        String conclusiveImageName =
            '${currentVisualSection.name as String}-conclusive';
        // var imagesToUpload = capturedConclusiveImages
        //     .where((e) => !e.startsWith('http'))
        //     .toList();
        var imagesToUpload = await realmServices.getImagesNotUploaded(
          capturedConclusiveImages,
          appSettings.activeConnection,
          isNewSection,
        );
        if (imagesToUpload.isEmpty) {
          return;
        }
        imagesBloc
            .uploadMultipleImages(
              imagesToUpload,
              conclusiveImageName,
              userFullName,
              currentConclusiveSection.id.toString(),
              parentType,
              'conclusivesection',
            )
            .then((value) async {
              List<String> urls = [];
              for (var element in value) {
                if (element is ImageResponse) {
                  await GallerySaver.saveImage(element.originalPath as String);
                  urls.add(element.url as String);
                }
              }
              realmServices.addConclusiveImagesUrl(
                conclusiveImageName,
                currentConclusiveSection,
                urls,
              );
            });
      }
    }
  }

  List<String> capturedImages = [];
  List<String> capturedInvasiveImages = [];
  List<String> capturedConclusiveImages = [];
  bool hasSignsOfLeak = false;
  bool invasiveReviewRequired = false;
  bool postInvasiveRepairsRequired = false;
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

  _onMenuItemSelected(int value, int selectedTabIndex) async {
    if (value == 1) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CameraScreen()),
      ).then((value) {
        setState(() {
          if (value != null) {
            if (selectedTabIndex == 1) {
              capturedInvasiveImages.addAll(value);
            }
            if (selectedTabIndex == 2) {
              capturedConclusiveImages.addAll(value);
            }
            //capturedImages.addAll(value);
            if (value.isNotEmpty) {
              setState(() {});
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
          if (selectedTabIndex == 1) {
            capturedInvasiveImages.addAll(
              imageFiles.map((e) => e.path).toList(),
            );
          }
          if (selectedTabIndex == 2) {
            capturedConclusiveImages.addAll(
              imageFiles.map((e) => e.path).toList(),
            );
          }
        });
      }
    }
  }

  Widget sectionForm(BuildContext context) {
    // Build a Form widget using the _formKey created above.

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Location name'),
          const SizedBox(height: 4),
          Text(
            _nameController.text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text('Unit photos(${capturedImages.length})'),
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
                height: MediaQuery.of(context).size.height / 3.5,
                child: ListView.builder(
                  shrinkWrap: true,
                  scrollDirection: Axis.horizontal,
                  itemCount: capturedImages.length,
                  itemBuilder:
                      (BuildContext context, int index) => Container(
                        margin: const EdgeInsets.fromLTRB(2, 8, 8, 8),
                        height: 180,
                        width: 300,
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          // image: DecorationImage(
                          //     image:
                          //         AssetImage('assets/images/icon.png'),
                          //     fit: BoxFit.cover),
                          borderRadius: BorderRadius.all(Radius.circular(8.0)),
                          boxShadow: [
                            BoxShadow(blurRadius: 1.0, color: Colors.blue),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: networkImage(capturedImages[index]),
                        ),
                      ),
                ),
              ),
          const SizedBox(height: 4),
          AbsorbPointer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      'Exterior Elements',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    InkWell(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${selectedExteriorelements.length} Selected',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.arrow_forward_ios_outlined,
                            size: 14,
                            color: Colors.black,
                          ),
                        ],
                      ),
                      onTap: () {},
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Waterproofing Elements',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    InkWell(
                      onTap: () {},
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${selectedWaterproofingElements.length} Selected',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.arrow_forward_ios_outlined,
                            size: 14,
                            color: Colors.black,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(
                  color: Color.fromARGB(255, 222, 213, 213),
                  height: 20,
                  thickness: 1,
                  indent: 2,
                  endIndent: 2,
                ),
                const Text(
                  'Visual Review',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                radioWidget('visual', 3),
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
                    const Text(
                      'Any visual signs of leaks',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Switch(
                      onChanged: (value) {
                        // toggleSwitch(value);
                      },
                      value: hasSignsOfLeak,
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
                    const Text(
                      'Further invasive review required',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Switch(
                      onChanged: (value) {
                        //toggleSwitchInvasive(value);
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
                const Text(
                  'Conditional Assessment',
                  textAlign: TextAlign.left,
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                radioWidget('conditional', 3),
                const Divider(
                  color: Color.fromARGB(255, 222, 213, 213),
                  height: 15,
                  thickness: 1,
                  indent: 2,
                  endIndent: 2,
                ),
                const Text('Additional considerations or concerns'),
                const SizedBox(height: 8),
                inputWidgetwithValidation(
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
                const Text(
                  'Life expectancy exterior elevated elements (EEE)',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                radioWidget('EEE', 4),
                const Divider(
                  color: Color.fromARGB(255, 222, 213, 213),
                  height: 15,
                  thickness: 1,
                  indent: 2,
                  endIndent: 2,
                ),
                const Text(
                  'Life expectancy load bearing components (LBC)',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                radioWidget('LBC', 4),
                const Divider(
                  color: Color.fromARGB(255, 222, 213, 213),
                  height: 15,
                  thickness: 1,
                  indent: 2,
                  endIndent: 2,
                ),
                const Text(
                  'Life expectancy assciated waterproofing elements (AWE)',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                radioWidget('AWE', 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void removePhoto(BuildContext context, int index, bool isConclusive) {
    if (isConclusive) {
      realmServices.removeConclusiveImageUrl(
        currentConclusiveSection,
        capturedConclusiveImages[index],
      );
    } else {
      realmServices.removeInvasiveImageUrl(
        currentInvasiveSection,
        capturedInvasiveImages[index],
      );
    }

    setState(() {
      isConclusive
          ? capturedConclusiveImages.removeAt(index)
          : capturedInvasiveImages.removeAt(index);
    });
  }

  gotoImageEditorPage(
    BuildContext context,
    String capturedImage,
    int index,
    bool isConclusive,
  ) async {
    Uint8List imageData;
    if (capturedImage.contains('http')) {
      http.Response response = await http.get(Uri.parse(capturedImage));
      imageData = response.bodyBytes;
    } else {
      imageData = await File(capturedImage).readAsBytes();
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
    String imageid = ObjectId().toString();
    final pathOfImage =
        await File('${destDirectory.path}/$imageid.jpg').create();
    if (editedImage != null) {
      var editedFile = await pathOfImage.writeAsBytes(editedImage);
      setState(() {
        if (isConclusive) {
          capturedConclusiveImages.removeAt(index);
          realmServices.removeConclusiveImageUrl(
            currentConclusiveSection,
            capturedImage,
          );
          capturedConclusiveImages.insert(index, editedFile.path);
        } else {
          capturedInvasiveImages.removeAt(index);
          realmServices.removeInvasiveImageUrl(
            currentInvasiveSection,
            capturedImage,
          );
          capturedInvasiveImages.insert(index, editedFile.path);
        }
      });
    }
  }

  void toggleSwitch(bool value) {
    if (postInvasiveRepairsRequired == false) {
      setState(() {
        postInvasiveRepairsRequired = true;
        _tabBarCount = 3;
      });
    } else {
      setState(() {
        postInvasiveRepairsRequired = false;
        _tabBarCount = 2;
      });
    }
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

  static const List<ElementModel> exteriorElements = <ElementModel>[
    //ElementModel('SELECT ALL', '10');
    ElementModel('Decks', '1'),
    ElementModel('Porches/Entry', '2'),
    ElementModel('Stairs', '3'),
    ElementModel('Stairs Landing', '4'),
    ElementModel('Walkways', '5'),
    ElementModel('Railings', '6'),
    ElementModel('Integrations', '7'),
    ElementModel('Door Threshold', '8'),
    ElementModel('Stucco Interface', '9'),
  ];
  List<ElementModel> selectedExteriorelements = [];

  static const List<ElementModel> waterproofingElements = <ElementModel>[
    //ElementModel('SELECT ALL', '5'),
    ElementModel('Flashings', '1'),
    ElementModel('Waterproofing', '2'),
    ElementModel('Coatings', '3'),
    ElementModel('Sealants', '4'),
  ];
  List<ElementModel> selectedWaterproofingElements = [];

  //Radios

  Widget getListTile(String radioType, int position) {
    if (radioType == 'visual') {
      switch (position) {
        case 1:
          return ListTile(
            horizontalTitleGap: 2,
            contentPadding: const EdgeInsets.all(0),
            title: const Text('Good'),
            leading: Radio<VisualReview>(
              value: VisualReview.good,
              groupValue: _review,
              onChanged: (VisualReview? value) {
                setState(() {
                  _review = value;
                });
                // debugPrint(_review!.name);
              },
            ),
          );
        //break;
        case 2:
          return ListTile(
            horizontalTitleGap: 2,
            contentPadding: const EdgeInsets.all(0),
            title: const Text('Fair'),
            leading: Radio<VisualReview>(
              value: VisualReview.fair,
              groupValue: _review,
              onChanged: (VisualReview? value) {
                setState(() {
                  _review = value;
                });
                //debugPrint(_review!.name);
              },
            ),
          );
        case 3:
          return ListTile(
            horizontalTitleGap: 2,
            contentPadding: const EdgeInsets.all(0),
            title: const Text('Bad'),
            leading: Radio<VisualReview>(
              value: VisualReview.bad,
              groupValue: _review,
              onChanged: (VisualReview? value) {
                setState(() {
                  _review = value;
                });
                //debugPrint(_review!.name);
              },
            ),
          );
      }
    } else if (radioType == "EEE") {
      switch (position) {
        case 1:
          return ListTile(
            contentPadding: const EdgeInsets.all(0),
            title: const Text('0-1 Years'),
            leading: Radio<ExpectancyYears>(
              value: ExpectancyYears.one,
              groupValue: _eee,
              onChanged: (ExpectancyYears? value) {
                setState(() {
                  _eee = value;
                });
                //debugPrint(_review!.name);
              },
            ),
          );
        //break;
        case 2:
          return ListTile(
            contentPadding: const EdgeInsets.all(0),
            title: const Text('1-4 Years'),
            leading: Radio<ExpectancyYears>(
              value: ExpectancyYears.four,
              groupValue: _eee,
              onChanged: (ExpectancyYears? value) {
                setState(() {
                  _eee = value;
                });
              },
            ),
          );
        case 3:
          return ListTile(
            contentPadding: const EdgeInsets.all(0),
            title: const Text('4-7 Years'),
            leading: Radio<ExpectancyYears>(
              value: ExpectancyYears.seven,
              groupValue: _eee,
              onChanged: (ExpectancyYears? value) {
                setState(() {
                  _eee = value;
                });
              },
            ),
          );
        case 4:
          return ListTile(
            contentPadding: const EdgeInsets.all(0),
            title: const Text('7+ Years'),
            leading: Radio<ExpectancyYears>(
              value: ExpectancyYears.sevenplus,
              groupValue: _eee,
              onChanged: (ExpectancyYears? value) {
                setState(() {
                  _eee = value;
                });
              },
            ),
          );
      }
    } else if (radioType == "EEEConclusive") {
      switch (position) {
        case 1:
          return ListTile(
            contentPadding: const EdgeInsets.all(0),
            title: const Text('0-1 Years'),
            leading: Radio<ExpectancyYears>(
              value: ExpectancyYears.one,
              groupValue: _eeeConclusive,
              onChanged: (ExpectancyYears? value) {
                setState(() {
                  _eeeConclusive = value;
                });
                //debugPrint(_review!.name);
              },
            ),
          );
        //break;
        case 2:
          return ListTile(
            contentPadding: const EdgeInsets.all(0),
            title: const Text('1-4 Years'),
            leading: Radio<ExpectancyYears>(
              value: ExpectancyYears.four,
              groupValue: _eeeConclusive,
              onChanged: (ExpectancyYears? value) {
                setState(() {
                  _eeeConclusive = value;
                });
              },
            ),
          );
        case 3:
          return ListTile(
            contentPadding: const EdgeInsets.all(0),
            title: const Text('4-7 Years'),
            leading: Radio<ExpectancyYears>(
              value: ExpectancyYears.seven,
              groupValue: _eeeConclusive,
              onChanged: (ExpectancyYears? value) {
                setState(() {
                  _eeeConclusive = value;
                });
              },
            ),
          );
        case 4:
          return ListTile(
            contentPadding: const EdgeInsets.all(0),
            title: const Text('7+ Years'),
            leading: Radio<ExpectancyYears>(
              value: ExpectancyYears.sevenplus,
              groupValue: _eeeConclusive,
              onChanged: (ExpectancyYears? value) {
                setState(() {
                  _eeeConclusive = value;
                });
              },
            ),
          );
      }
    } else if (radioType == "LBC") {
      switch (position) {
        case 1:
          return ListTile(
            contentPadding: const EdgeInsets.all(0),
            title: const Text('0-1 Years'),
            leading: Radio<ExpectancyYears>(
              value: ExpectancyYears.one,
              groupValue: _lbc,
              onChanged: (ExpectancyYears? value) {
                setState(() {
                  _lbc = value;
                });
              },
            ),
          );
        //break;
        case 2:
          return ListTile(
            contentPadding: const EdgeInsets.all(0),
            title: const Text('1-4 Years'),
            leading: Radio<ExpectancyYears>(
              value: ExpectancyYears.four,
              groupValue: _lbc,
              onChanged: (ExpectancyYears? value) {
                setState(() {
                  _lbc = value;
                });
              },
            ),
          );
        case 3:
          return ListTile(
            contentPadding: const EdgeInsets.all(0),
            title: const Text('4-7 Years'),
            leading: Radio<ExpectancyYears>(
              value: ExpectancyYears.seven,
              groupValue: _lbc,
              onChanged: (ExpectancyYears? value) {
                setState(() {
                  _lbc = value;
                });
              },
            ),
          );
        case 4:
          return ListTile(
            contentPadding: const EdgeInsets.all(0),
            title: const Text('7+ Years'),
            leading: Radio<ExpectancyYears>(
              value: ExpectancyYears.sevenplus,
              groupValue: _lbc,
              onChanged: (ExpectancyYears? value) {
                setState(() {
                  _lbc = value;
                });
              },
            ),
          );
      }
    } else if (radioType == "LBCConclusive") {
      switch (position) {
        case 1:
          return ListTile(
            contentPadding: const EdgeInsets.all(0),
            title: const Text('0-1 Years'),
            leading: Radio<ExpectancyYears>(
              value: ExpectancyYears.one,
              groupValue: _lbcConclusive,
              onChanged: (ExpectancyYears? value) {
                setState(() {
                  _lbcConclusive = value;
                });
              },
            ),
          );
        //break;
        case 2:
          return ListTile(
            contentPadding: const EdgeInsets.all(0),
            title: const Text('1-4 Years'),
            leading: Radio<ExpectancyYears>(
              value: ExpectancyYears.four,
              groupValue: _lbcConclusive,
              onChanged: (ExpectancyYears? value) {
                setState(() {
                  _lbcConclusive = value;
                });
              },
            ),
          );
        case 3:
          return ListTile(
            contentPadding: const EdgeInsets.all(0),
            title: const Text('4-7 Years'),
            leading: Radio<ExpectancyYears>(
              value: ExpectancyYears.seven,
              groupValue: _lbcConclusive,
              onChanged: (ExpectancyYears? value) {
                setState(() {
                  _lbcConclusive = value;
                });
              },
            ),
          );
        case 4:
          return ListTile(
            contentPadding: const EdgeInsets.all(0),
            title: const Text('7+ Years'),
            leading: Radio<ExpectancyYears>(
              value: ExpectancyYears.sevenplus,
              groupValue: _lbcConclusive,
              onChanged: (ExpectancyYears? value) {
                setState(() {
                  _lbcConclusive = value;
                });
              },
            ),
          );
      }
    } else if (radioType == "AWEConclusive") {
      switch (position) {
        case 1:
          return ListTile(
            contentPadding: const EdgeInsets.all(0),
            title: const Text('0-1 Years'),
            leading: Radio<ExpectancyYears>(
              value: ExpectancyYears.one,
              groupValue: _aweConclusive,
              onChanged: (ExpectancyYears? value) {
                setState(() {
                  _aweConclusive = value;
                });
              },
            ),
          );
        //break;
        case 2:
          return ListTile(
            contentPadding: const EdgeInsets.all(0),
            title: const Text('1-4 Years'),
            leading: Radio<ExpectancyYears>(
              value: ExpectancyYears.four,
              groupValue: _aweConclusive,
              onChanged: (ExpectancyYears? value) {
                setState(() {
                  _aweConclusive = value;
                });
              },
            ),
          );
        case 3:
          return ListTile(
            contentPadding: const EdgeInsets.all(0),
            title: const Text('4-7 Years'),
            leading: Radio<ExpectancyYears>(
              value: ExpectancyYears.seven,
              groupValue: _aweConclusive,
              onChanged: (ExpectancyYears? value) {
                setState(() {
                  _aweConclusive = value;
                });
              },
            ),
          );
        case 4:
          return ListTile(
            contentPadding: const EdgeInsets.all(0),
            title: const Text('7+ Years'),
            leading: Radio<ExpectancyYears>(
              value: ExpectancyYears.sevenplus,
              groupValue: _aweConclusive,
              onChanged: (ExpectancyYears? value) {
                setState(() {
                  _aweConclusive = value;
                });
              },
            ),
          );
      }
    } else if (radioType == "AWE") {
      switch (position) {
        case 1:
          return ListTile(
            contentPadding: const EdgeInsets.all(0),
            title: const Text('0-1 Years'),
            leading: Radio<ExpectancyYears>(
              value: ExpectancyYears.one,
              groupValue: _awe,
              onChanged: (ExpectancyYears? value) {
                setState(() {
                  _awe = value;
                });
              },
            ),
          );
        //break;
        case 2:
          return ListTile(
            contentPadding: const EdgeInsets.all(0),
            title: const Text('1-4 Years'),
            leading: Radio<ExpectancyYears>(
              value: ExpectancyYears.four,
              groupValue: _awe,
              onChanged: (ExpectancyYears? value) {
                setState(() {
                  _awe = value;
                });
              },
            ),
          );
        case 3:
          return ListTile(
            contentPadding: const EdgeInsets.all(0),
            title: const Text('4-7 Years'),
            leading: Radio<ExpectancyYears>(
              value: ExpectancyYears.seven,
              groupValue: _awe,
              onChanged: (ExpectancyYears? value) {
                setState(() {
                  _awe = value;
                });
              },
            ),
          );
        case 4:
          return ListTile(
            contentPadding: const EdgeInsets.all(0),
            title: const Text('7+ Years'),
            leading: Radio<ExpectancyYears>(
              value: ExpectancyYears.sevenplus,
              groupValue: _awe,
              onChanged: (ExpectancyYears? value) {
                setState(() {
                  _awe = value;
                });
              },
            ),
          );
      }
    } else {
      switch (position) {
        case 1:
          return ListTile(
            horizontalTitleGap: 2,
            contentPadding: const EdgeInsets.all(0),
            title: const Text('Pass'),
            leading: Radio<ConditionalAssessment>(
              value: ConditionalAssessment.pass,
              groupValue: _assessment,
              onChanged: (ConditionalAssessment? value) {
                setState(() {
                  _assessment = value;
                });
                debugPrint(_review!.name);
              },
            ),
          );
        //break;
        case 2:
          return ListTile(
            horizontalTitleGap: 2,
            contentPadding: const EdgeInsets.all(0),
            title: const Text('Fail'),
            leading: Radio<ConditionalAssessment>(
              value: ConditionalAssessment.fail,
              groupValue: _assessment,
              onChanged: (ConditionalAssessment? value) {
                setState(() {
                  _assessment = value;
                });
              },
            ),
          );
        case 3:
          return ListTile(
            horizontalTitleGap: 2,
            contentPadding: const EdgeInsets.all(0),
            title: const Text('Future Inspection'),
            leading: Radio<ConditionalAssessment>(
              value: ConditionalAssessment.futureinspection,
              groupValue: _assessment,
              onChanged: (ConditionalAssessment? value) {
                setState(() {
                  _assessment = value;
                });
              },
            ),
          );
      }
    }
    return ListTile(
      horizontalTitleGap: 2,
      contentPadding: const EdgeInsets.all(0),
      title: const Text('Fair'),
      leading: Radio<VisualReview>(
        value: VisualReview.fair,
        groupValue: _review,
        onChanged: (VisualReview? value) {
          setState(() {
            _review = value;
          });
          debugPrint(_review!.name);
        },
      ),
    );
  }

  VisualReview? _review; //= VisualReview.good;
  ConditionalAssessment? _assessment; //= ConditionalAssessment.pass;
  ExpectancyYears? _eee; //= ExpectancyYears.four;
  ExpectancyYears? _lbc; // = ExpectancyYears.four;
  ExpectancyYears? _awe; //= ExpectancyYears.four;

  Widget radioWidget(String radioType, int radioCount) {
    if (radioCount == 4) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: <Widget>[
              Expanded(child: getListTile(radioType, 1)),
              Expanded(child: getListTile(radioType, 2)),
            ],
          ),
          Row(
            children: <Widget>[
              Expanded(child: getListTile(radioType, 3)),
              Expanded(child: getListTile(radioType, 4)),
            ],
          ),
        ],
      );
    }
    return Row(
      children: <Widget>[
        Expanded(flex: 2, child: getListTile(radioType, 1)),
        Expanded(flex: 2, child: getListTile(radioType, 2)),
        Expanded(flex: 3, child: getListTile(radioType, 3)),
      ],
    );
  }

  visualSectionWidget() {
    return sectionForm(context);
  }

  invasiveSectionWidget() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Post invasive repairs required',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              Switch(
                onChanged: (value) {
                  toggleSwitch(value);
                },
                value: postInvasiveRepairsRequired,
              ),
            ],
          ),
          const SizedBox(height: 8),
          inputWidgetwithValidation(
            'Invasive Description',
            'Please description',
            7,
            _invasiveDescriptionController,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Invasive photos(${capturedInvasiveImages.length})'),
              PopupMenuButton(
                child: const Chip(
                  avatar: Icon(Icons.add_a_photo_outlined, color: Colors.blue),
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
                  _onMenuItemSelected(value as int, 1);
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
                    ],
              ),
            ],
          ),
          capturedInvasiveImages.isEmpty
              ? const SizedBox(
                height: 180,
                child: Center(
                  child: Text(
                    'Add location invasive images.',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              )
              : SizedBox(
                height: MediaQuery.of(context).size.height / 3.5,
                child: ListView.builder(
                  shrinkWrap: true,
                  scrollDirection: Axis.horizontal,
                  itemCount: capturedInvasiveImages.length,
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
                                        capturedInvasiveImages[index],
                                        index,
                                        false,
                                      ),
                                  child: Container(
                                    margin: const EdgeInsets.fromLTRB(
                                      2,
                                      8,
                                      8,
                                      8,
                                    ),
                                    height: 180,
                                    width: 300,
                                    decoration: const BoxDecoration(
                                      color: Colors.orange,
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
                                          color: Colors.orange,
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8.0),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          networkImage(
                                            capturedInvasiveImages[index],
                                          ),
                                          Align(
                                            alignment: Alignment.bottomRight,
                                            child:
                                                capturedInvasiveImages[index]
                                                        .startsWith('http')
                                                    ? const Icon(
                                                      weight: 3,
                                                      size: 50,
                                                      Icons.done,
                                                      color: Colors.blue,
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
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide.none,
                                  // the height is 50, the width is full
                                  minimumSize: const Size.fromHeight(30),
                                  backgroundColor: Colors.white,
                                  shadowColor: Colors.orange,
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  removePhoto(context, index, false);
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
        ],
      ),
    );
  }

  bool propOwnerAgreed = false;
  bool invasiveRepairsCompleted = false;
  ExpectancyYears? _eeeConclusive;
  ExpectancyYears? _lbcConclusive;
  ExpectancyYears? _aweConclusive;

  conclusiveSectionWidget() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Prop owner agreed to repairs',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              Switch(
                onChanged: (value) {
                  togglePropOwnerSwitch(value);
                },
                value: propOwnerAgreed,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  maxLines: 2,
                  'Invasive repairs inspected and completed',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Switch(
                onChanged: (value) {
                  toggleCompletedSwitch(value);
                },
                value: invasiveRepairsCompleted,
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
          Visibility(
            visible: invasiveRepairsCompleted,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const Text(
                  'Life expectancy exterior elevated elements (EEE) updated',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                radioWidget('EEEConclusive', 4),
                const Divider(
                  color: Color.fromARGB(255, 222, 213, 213),
                  height: 15,
                  thickness: 1,
                  indent: 2,
                  endIndent: 2,
                ),
                const Text(
                  'Life expectancy load bearing components (LBC) updated',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                radioWidget('LBCConclusive', 4),
                const Divider(
                  color: Color.fromARGB(255, 222, 213, 213),
                  height: 15,
                  thickness: 1,
                  indent: 2,
                  endIndent: 2,
                ),
                const Text(
                  'Life expectancy associated waterproofing elements (AWE) updated',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                radioWidget('AWEConclusive', 4),
                const Divider(
                  color: Color.fromARGB(255, 222, 213, 213),
                  height: 15,
                  thickness: 1,
                  indent: 2,
                  endIndent: 2,
                ),
                inputWidgetwithValidation(
                  'Conclusive Description',
                  'Please add conclusive description',
                  7,
                  _conclusiveDescriptionController,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Conclusive photos(${capturedConclusiveImages.length})',
                    ),
                    Expanded(
                      child: PopupMenuButton(
                        child: const Chip(
                          avatar: Icon(
                            Icons.add_a_photo_outlined,
                            color: Colors.blue,
                          ),
                          labelPadding: EdgeInsets.all(2),
                          label: Text(
                            maxLines: 2,
                            'Add Photos',
                            style: TextStyle(color: Colors.blue, fontSize: 15),
                          ),
                          shadowColor: Colors.transparent,
                          backgroundColor: Colors.transparent,
                          elevation: 10,
                          autofocus: true,
                        ),
                        onSelected: (value) {
                          _onMenuItemSelected(value as int, 2);
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
                            ],
                      ),
                    ),
                  ],
                ),
                capturedConclusiveImages.isEmpty
                    ? const SizedBox(
                      height: 180,
                      child: Center(
                        child: Text(
                          'Add location conclusive images.',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    )
                    : SizedBox(
                      height: MediaQuery.of(context).size.height / 3.5,
                      child: ListView.builder(
                        shrinkWrap: true,
                        scrollDirection: Axis.horizontal,
                        itemCount: capturedConclusiveImages.length,
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
                                              capturedConclusiveImages[index],
                                              index,
                                              true,
                                            ),
                                        child: Container(
                                          margin: const EdgeInsets.fromLTRB(
                                            2,
                                            8,
                                            8,
                                            8,
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
                                                  capturedConclusiveImages[index],
                                                ),
                                                Align(
                                                  alignment:
                                                      Alignment.bottomRight,
                                                  child:
                                                      capturedConclusiveImages[index]
                                                              .startsWith(
                                                                'http',
                                                              )
                                                          ? const Icon(
                                                            weight: 3,
                                                            size: 50,
                                                            Icons.done,
                                                            color: Colors.blue,
                                                          )
                                                          : const Icon(
                                                            weight: 3,
                                                            size: 50,
                                                            Icons.sync,
                                                            color:
                                                                Colors.orange,
                                                          ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide.none,
                                        // the height is 50, the width is full
                                        minimumSize: const Size.fromHeight(30),
                                        backgroundColor: Colors.white,
                                        shadowColor: Colors.blue,
                                        elevation: 0,
                                      ),
                                      onPressed: () {
                                        removePhoto(context, index, true);
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  void togglePropOwnerSwitch(bool value) {
    if (propOwnerAgreed == false) {
      setState(() {
        propOwnerAgreed = true;
      });
    } else {
      setState(() {
        propOwnerAgreed = false;
      });
    }
  }

  void toggleCompletedSwitch(bool value) {
    if (invasiveRepairsCompleted == false) {
      setState(() {
        invasiveRepairsCompleted = true;
      });
    } else {
      setState(() {
        invasiveRepairsCompleted = false;
      });
    }
  }
}
