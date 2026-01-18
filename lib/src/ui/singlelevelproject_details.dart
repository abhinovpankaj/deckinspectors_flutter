// import 'dart:async' as async;

// import 'package:E3InspectionsMultiTenant/src/bloc/projects_bloc.dart';
// import 'package:E3InspectionsMultiTenant/src/bloc/settings_bloc.dart';
// import 'package:E3InspectionsMultiTenant/src/models/error_response.dart';
// import 'package:E3InspectionsMultiTenant/src/models/success_response.dart';
// import 'package:E3InspectionsMultiTenant/src/resources/couchbase/couchbase_project_services.dart';
// //import 'package:E3InspectionsMultiTenant/src/ui/breadcrumb_navigation.dart';
// import 'package:E3InspectionsMultiTenant/src/ui/cachedimage_widget.dart';
// import 'package:E3InspectionsMultiTenant/src/ui/pdfviewer.dart';
// import 'package:E3InspectionsMultiTenant/src/ui/showprojecttype_widget.dart';
// import 'package:provider/provider.dart';
// import '../models/couchbase/couchbase_models.dart';
// import 'invasivesection.dart';
// import 'package:flutter/material.dart';
// import 'addedit_project.dart';
// import 'section.dart';
// import 'package:intl/intl.dart';

// class SingleProjectDetailsPage extends StatefulWidget {
//   final ObjectId id;
//   final String userFullName;
//   final bool isInvasiveMode;
//   const SingleProjectDetailsPage(
//     this.id,
//     this.userFullName,
//     this.isInvasiveMode, {
//     super.key,
//   });

//   @override
//   State<SingleProjectDetailsPage> createState() =>
//       _SingleProjectDetailsPageState();

//   static MaterialPageRoute getRoute(
//     ObjectId id,
//     String userName,
//     bool isInvasive,
//     String pageName,
//   ) => MaterialPageRoute(
//     settings: RouteSettings(name: pageName),
//     builder: (context) => SingleProjectDetailsPage(id, userName, isInvasive),
//   );
// }

// //Add New Project
// class _SingleProjectDetailsPageState extends State<SingleProjectDetailsPage>
//     with SingleTickerProviderStateMixin {
//   late Project currentProject;
//   late String userFullName;
//   late String createdAt;
//   late List<Section?> sections;
//   late bool isInvasiveMode;
//   late ObjectId projectId;

//   @override
//   void initState() {
//     super.initState();

//     projectId = widget.id;
//     isInvasiveMode = widget.isInvasiveMode;
//     appSettings.isInvasiveMode = isInvasiveMode;
//     userFullName = widget.userFullName;

//     sections = List.empty(growable: true);
//   }

//   async.FutureOr refreshProjectDetails(dynamic value) async {
//     // var response = await projectsBloc.getProject(currentProject.id as String);
//     // if (response is Project) {
//     //   currentProject = response;
//     // } else {
//     //   //
//     // }
//     setState(() {
//       if (currentProject.isValid) {
//         if (isInvasiveMode) {
//           sections =
//               currentProject.sections
//                   .where((element) => element.isInvasive)
//                   .toList();
//         } else {
//           sections = currentProject.sections.toList();
//         }
//       }
//     });
//   }

//   void addEditProject() {
//     Navigator.push(
//       context,
//       AddEditProjectPage.getRoute(currentProject, false, userFullName),
//     ).then((value) => setState(() {}));
//   }

//   void addNewChild() {
//     Navigator.push(
//       context,
//       SectionPage.getRoute(
//         ObjectId(),
//         currentProject.id,
//         userFullName,
//         'project',
//         currentProject.name as String,
//         true,
//         'New',
//       ),
//     ).then((value) => setState(() {}));
//   }

//   void gotoDetails(ObjectId sectionId, String pageName) {
//     Navigator.push(
//       context,
//       SectionPage.getRoute(
//         sectionId,
//         currentProject.id,
//         userFullName,
//         'project',
//         currentProject.name as String,
//         false,
//         pageName,
//       ),
//     ).then((value) {
//       if (!mounted) {
//         return;
//       }
//       setState(() {});
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     final realmServices = Provider.of<RealmLocalServices>(
//       context,
//       listen: false,
//     );
//     return Scaffold(
//       // floatingActionButton: Padding(
//       //   padding: const EdgeInsets.fromLTRB(20, 0, 0, 0),
//       //   child: BreadCrumbNavigator(),
//       // ),
//       appBar: AppBar(
//         automaticallyImplyLeading: false,
//         leadingWidth: 140,
//         leading: ElevatedButton.icon(
//           onPressed: () => Navigator.of(context).pop(),
//           icon: const Icon(Icons.arrow_back_ios, color: Colors.blue),
//           label: const Text('Home', style: TextStyle(color: Colors.blue)),
//           style: ElevatedButton.styleFrom(
//             elevation: 0,
//             backgroundColor: Colors.transparent,
//           ),
//         ),
//         backgroundColor: Colors.white,
//         foregroundColor: Colors.blue,
//         elevation: 0,
//         title: const Text(
//           'Project',
//           style: TextStyle(color: Colors.black, fontWeight: FontWeight.normal),
//         ),
//       ),
//       body: StreamBuilder<RealmObjectChanges<Project>>(
//         //projectsBloc.projects
//         stream: realmServices.getProject(projectId)?.changes,
//         builder: (context, snapshot) {
//           if (snapshot.hasData) {
//             final data = snapshot.data;

//             if (data == null) {
//               return Center(
//                 child: Text(
//                   '${snapshot.error} occurred',
//                   style: const TextStyle(fontSize: 18),
//                 ),
//               );

//               // if we got our data
//             } else {
//               currentProject = data.object;
//               if (currentProject.isValid) {
//                 if (isInvasiveMode) {
//                   sections =
//                       currentProject.sections
//                           .where((element) => element.isInvasive)
//                           .toList();
//                 } else {
//                   sections = currentProject.sections.toList();
//                 }

//                 var shortDate = DateTime.tryParse(
//                   currentProject.createdat as String,
//                 );
//                 if (shortDate != null) {
//                   createdAt = DateFormat.yMMMEd().format(shortDate);
//                 } else {
//                   createdAt = "";
//                 }
//               }

//               return SingleChildScrollView(
//                 child: Column(
//                   children: [
//                     // StatefulBuilder(builder: (context, StateSetter setState) {
//                     projectDetails(
//                       currentProject.name as String,
//                       currentProject.url as String,
//                       currentProject.id,
//                       currentProject.description as String,
//                     ),
//                     //}),
//                     locationsWidget(context),
//                   ],
//                 ),
//               );

//               // if (data is ErrorResponse) {
//               //   return Center(
//               //     child: Text(
//               //       '${data.message}',
//               //       style: const TextStyle(fontSize: 18),
//               //     ),
//               //   );
//               // }
//             }
//           }

//           // Displaying LoadingSpinner to indicate waiting state
//           return const Center(child: CircularProgressIndicator());
//         },
//       ),
//     );
//   }

//   Widget projectDetails(
//     String name,
//     String url,
//     ObjectId id,
//     String description,
//   ) {
//     return Padding(
//       padding: const EdgeInsets.all(0.0),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.start,
//         children: [
//           const SizedBox(height: 4),
//           const ProjectType(),
//           Container(
//             height: 220,
//             decoration: BoxDecoration(
//               color: isInvasiveMode ? Colors.orange : Colors.blue,
//               // image: networkImage(currentProject.url as String),
//               borderRadius: const BorderRadius.vertical(
//                 bottom: Radius.circular(8.0),
//               ),
//               boxShadow: const [BoxShadow(blurRadius: 1.0, color: Colors.blue)],
//             ),
//             child: ClipRRect(
//               borderRadius: const BorderRadius.vertical(
//                 bottom: Radius.circular(8.0),
//               ),
//               child: cachedNetworkImage(url),
//             ),
//           ),
//           //networkImage(currentProject.url as String),
//           Align(
//             alignment: Alignment.centerLeft,
//             child: Padding(
//               padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Expanded(
//                     child: Text(
//                       name,
//                       maxLines: 2,
//                       style: const TextStyle(
//                         fontSize: 18,
//                         overflow: TextOverflow.ellipsis,
//                         fontWeight: FontWeight.bold,
//                       ),
//                       textAlign: TextAlign.left,
//                     ),
//                   ),
//                   Expanded(
//                     child: InkWell(
//                       onTap: () {
//                         isDownloading
//                             ? null
//                             : downloadProjectReport(id, 'visual');
//                       },
//                       child: Chip(
//                         avatar:
//                             isDownloading
//                                 ? const SizedBox(
//                                   width: 20,
//                                   height: 20,
//                                   child: CircularProgressIndicator(
//                                     strokeWidth: 3,
//                                   ),
//                                 )
//                                 : const Icon(
//                                   Icons.file_download_done_outlined,
//                                   color: Colors.blue,
//                                 ),
//                         labelPadding: const EdgeInsets.all(2),
//                         label: const Text(
//                           'Download Report ',
//                           style: TextStyle(color: Colors.blue),
//                           selectionColor: Colors.transparent,
//                         ),
//                         shadowColor: Colors.white,
//                         backgroundColor: Colors.transparent,
//                         elevation: 0,
//                         autofocus: true,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           const Align(
//             alignment: Alignment.centerLeft,
//             child: Padding(
//               padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
//               child: Text(
//                 'Description',
//                 style: TextStyle(fontSize: 14),
//                 textAlign: TextAlign.left,
//               ),
//             ),
//           ),
//           Align(
//             alignment: Alignment.centerLeft,
//             child: Padding(
//               padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                 children: [
//                   Expanded(
//                     child: Text(
//                       maxLines: 2,
//                       description,
//                       style: const TextStyle(
//                         overflow: TextOverflow.ellipsis,
//                         fontSize: 16,
//                       ),
//                       textAlign: TextAlign.left,
//                     ),
//                   ),
//                   Visibility(
//                     visible: !isInvasiveMode,
//                     child: InkWell(
//                       onTap: () {
//                         addEditProject();
//                       },
//                       child: const Chip(
//                         avatar: Icon(Icons.edit_outlined, color: Colors.blue),
//                         labelPadding: EdgeInsets.all(2),
//                         label: Text(
//                           'Edit Project ',
//                           style: TextStyle(color: Colors.blue),
//                           selectionColor: Colors.transparent,
//                         ),
//                         shadowColor: Colors.white,
//                         backgroundColor: Colors.transparent,
//                         elevation: 0,
//                         autofocus: true,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           const Align(
//             alignment: Alignment.centerLeft,
//             child: Padding(
//               padding: EdgeInsets.all(8),
//               child: Text(
//                 'Created By:',
//                 style: TextStyle(fontSize: 14),
//                 textAlign: TextAlign.left,
//               ),
//             ),
//           ),
//           Align(
//             alignment: Alignment.centerLeft,
//             child: Padding(
//               padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text(
//                     userFullName,
//                     style: const TextStyle(
//                       fontSize: 15,
//                       fontWeight: FontWeight.w700,
//                     ),
//                     textAlign: TextAlign.left,
//                   ),
//                   const SizedBox(width: 20),
//                   Text(
//                     createdAt,
//                     style: const TextStyle(color: Colors.black, fontSize: 14),
//                     textAlign: TextAlign.left,
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           const Divider(
//             color: Color.fromARGB(255, 222, 213, 213),
//             height: 5,
//             thickness: 2,
//             indent: 0,
//             endIndent: 0,
//           ),
//         ],
//       ),
//     );
//   }

//   Widget locationsWidget(BuildContext context) {
//     return SizedBox(
//       height: MediaQuery.of(context).size.height / 1.4,
//       child: Padding(
//         padding: const EdgeInsets.all(4),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 const Padding(
//                   padding: EdgeInsets.all(2),
//                   child: Text(
//                     'Locations',
//                     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                   ),
//                 ),
//                 Visibility(
//                   visible: !appSettings.isInvasiveMode,
//                   child: Align(
//                     alignment: Alignment.topRight,
//                     child: InkWell(
//                       onTap: () {
//                         addNewChild();
//                       },
//                       child: const Chip(
//                         avatar: Icon(
//                           Icons.add_circle_outline,
//                           color: Colors.blue,
//                         ),
//                         labelPadding: EdgeInsets.all(2),
//                         label: Text(
//                           'Add Location',
//                           style: TextStyle(color: Colors.blue),
//                           selectionColor: Colors.transparent,
//                         ),
//                         shadowColor: Colors.white,
//                         backgroundColor: Colors.transparent,
//                         elevation: 0,
//                         autofocus: true,
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//             sections.isEmpty
//                 ? const Center(
//                   child: Text(
//                     'No locations, Add locations.',
//                     style: TextStyle(fontSize: 16),
//                   ),
//                 )
//                 : Expanded(
//                   child: ListView.builder(
//                     shrinkWrap: true,
//                     scrollDirection: Axis.horizontal,
//                     itemCount: sections.length,
//                     itemBuilder:
//                         (BuildContext context, int index) =>
//                             horizontalScrollChildren(context, index),
//                   ),
//                 ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget horizontalScrollChildren(BuildContext context, int index) {
//     String vreview = '';
//     String visualReview = (sections[index]!.visualreview as String);
//     switch (visualReview.toLowerCase()) {
//       case 'good':
//         vreview = 'Good';
//         break;
//       case 'fair':
//         vreview = 'Fair';
//         break;
//       case 'bad':
//         vreview = 'Bad';
//         break;
//       default:
//     }
//     String assessment = '';
//     String? coverUrl = sections[index]!.coverUrl;
//     String assessmentActual = sections[index]!.conditionalassessment as String;
//     switch (assessmentActual.toLowerCase()) {
//       case 'pass':
//         assessment = 'Pass';
//         break;
//       case 'fail':
//         assessment = 'Fail';
//         break;
//       case 'futureinspection':
//         assessment = 'Future Inspection';
//         break;
//       default:
//     }
//     bool furtherInvasive = sections[index]!.furtherinvasivereviewrequired;

//     bool visualLeaks = sections[index]!.visualsignsofleak;
//     return SizedBox(
//       width: MediaQuery.of(context).size.width - 70,
//       child: Padding(
//         padding: const EdgeInsets.fromLTRB(4, 2, 8, 4),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.start,
//           children: [
//             Container(
//               height: 180,
//               decoration: BoxDecoration(
//                 color: appSettings.isInvasiveMode ? Colors.orange : Colors.blue,
//                 borderRadius: const BorderRadius.vertical(
//                   top: Radius.circular(10),
//                   bottom: Radius.circular(00),
//                 ),
//               ),
//               child: ClipRRect(
//                 borderRadius: BorderRadius.circular(8.0),
//                 child: cachedNetworkImage(coverUrl),
//               ),
//             ),
//             InkWell(
//               onTap: () {
//                 if (appSettings.isInvasiveMode) {
//                   gotoInvasiveDetails(sections[index]!.id);
//                 } else {
//                   gotoDetails(
//                     sections[index]!.id,
//                     sections[index]!.name as String,
//                   );
//                 }
//               },
//               child: Card(
//                 shadowColor: Colors.blue,
//                 elevation: 8,
//                 child: Column(
//                   children: [
//                     Padding(
//                       padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceAround,
//                         children: [
//                           Text(
//                             sections[index]!.name as String,
//                             maxLines: 2,
//                             style: const TextStyle(
//                               fontSize: 15,
//                               fontWeight: FontWeight.bold,
//                             ),
//                             textAlign: TextAlign.center,
//                           ),
//                           const Icon(
//                             Icons.navigate_next_sharp,
//                             color: Colors.blue,
//                           ),
//                         ],
//                       ),
//                     ),
//                     const Divider(
//                       color: Colors.grey,
//                       height: 20,
//                       thickness: 1,
//                       indent: 15,
//                       endIndent: 15,
//                     ),
//                     Align(
//                       alignment: Alignment.centerLeft,
//                       child: Padding(
//                         padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
//                         child: Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                           children: [
//                             const Expanded(
//                               flex: 1,
//                               child: Text(
//                                 maxLines: 1,
//                                 'Visual Review',
//                                 style: TextStyle(
//                                   overflow: TextOverflow.ellipsis,
//                                   fontSize: 13,
//                                 ),
//                                 textAlign: TextAlign.right,
//                               ),
//                             ),
//                             Expanded(
//                               flex: 1,
//                               child: Text(
//                                 vreview,
//                                 style: const TextStyle(
//                                   overflow: TextOverflow.ellipsis,
//                                   fontSize: 14,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                                 textAlign: TextAlign.center,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                     Align(
//                       alignment: Alignment.centerLeft,
//                       child: Padding(
//                         padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
//                         child: Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                           children: [
//                             const Expanded(
//                               flex: 1,
//                               child: Text(
//                                 maxLines: 1,
//                                 'Visual signs of leak',
//                                 style: TextStyle(
//                                   overflow: TextOverflow.ellipsis,
//                                   fontSize: 13,
//                                 ),
//                                 textAlign: TextAlign.right,
//                               ),
//                             ),
//                             Expanded(
//                               flex: 1,
//                               child: Text(
//                                 visualLeaks == true ? 'True' : 'False',
//                                 style: const TextStyle(
//                                   overflow: TextOverflow.ellipsis,
//                                   fontSize: 14,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                                 textAlign: TextAlign.center,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                     Align(
//                       alignment: Alignment.centerLeft,
//                       child: Padding(
//                         padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
//                         child: Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                           children: [
//                             const Expanded(
//                               flex: 1,
//                               child: Text(
//                                 maxLines: 1,
//                                 'Further Inspection',
//                                 style: TextStyle(
//                                   overflow: TextOverflow.ellipsis,
//                                   fontSize: 13,
//                                 ),
//                                 textAlign: TextAlign.right,
//                               ),
//                             ),
//                             Expanded(
//                               flex: 1,
//                               child: Text(
//                                 furtherInvasive == true ? 'True' : 'False',
//                                 style: const TextStyle(
//                                   overflow: TextOverflow.ellipsis,
//                                   fontSize: 14,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                                 textAlign: TextAlign.center,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                     Align(
//                       alignment: Alignment.centerLeft,
//                       child: Padding(
//                         padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
//                         child: Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                           children: [
//                             const Expanded(
//                               flex: 1,
//                               child: Text(
//                                 maxLines: 1,
//                                 'Conditional assesment',
//                                 style: TextStyle(
//                                   overflow: TextOverflow.ellipsis,
//                                   fontSize: 13,
//                                 ),
//                                 textAlign: TextAlign.right,
//                               ),
//                             ),
//                             Expanded(
//                               flex: 1,
//                               child: Text(
//                                 assessment,
//                                 style: const TextStyle(
//                                   overflow: TextOverflow.ellipsis,
//                                   fontSize: 14,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                                 textAlign: TextAlign.center,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 2),
//                     Align(
//                       alignment: Alignment.centerLeft,
//                       child: Padding(
//                         padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
//                         child: Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                           children: [
//                             const Expanded(
//                               flex: 1,
//                               child: Text(
//                                 maxLines: 1,
//                                 'Images',
//                                 style: TextStyle(
//                                   overflow: TextOverflow.ellipsis,
//                                   fontSize: 13,
//                                 ),
//                                 textAlign: TextAlign.right,
//                               ),
//                             ),
//                             Expanded(
//                               flex: 1,
//                               child: Text(
//                                 sections[index]!.count.toString(),
//                                 style: const TextStyle(
//                                   color: Colors.blue,
//                                   fontSize: 14,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                                 textAlign: TextAlign.center,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 10),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   bool isDownloading = false;
//   void downloadProjectReport(ObjectId id, String projectType) async {
//     setState(() {
//       isDownloading = true;
//     });
//     var result = await projectsBloc.downloadProjectReport(
//       currentProject.name as String,
//       id.toString(),
//       'pdf',
//       50,
//       4,
//       projectType,
//       'DeckInspectors',
//     );
//     if (!mounted) {
//       return;
//     }
//     if (result is ErrorResponse) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             'Failed to download the report, please try again.${result.message}',
//           ),
//         ),
//       );
//     } else if (result is SuccessResponse) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: const Text('Report downloaded successfully.'),
//           action: SnackBarAction(
//             label: 'View Report',
//             onPressed: () => gotoReportView(result.message),
//           ),
//         ),
//       );
//       //gotoReportView(result.message);
//     }
//     setState(() {
//       isDownloading = false;
//     });
//   }

//   void gotoReportView(String? message) {
//     //navigate to pdf view.
//     Navigator.push(
//       context,
//       MaterialPageRoute(builder: (context) => PDFViewerPage(message as String)),
//     );
//   }

//   void gotoInvasiveDetails(ObjectId id) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder:
//             (context) => InvasiveSectionPage(
//               id,
//               currentProject.id,
//               userFullName,
//               'project',
//               currentProject.name as String,
//               false,
//             ),
//       ),
//     ).then((value) {
//       if (!mounted) {
//         return;
//       }
//       setState(() {});
//     });
//   }
// }
