import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/settings_bloc.dart';
import '../models/couchbase/couchbase_models.dart';
import '../resources/couchbase/subproject_repository.dart';
import '../resources/couchbase/location_repository.dart';
import '../bloc/subproject_bloc.dart';
import '../bloc/subproject_event.dart';
import '../bloc/subproject_state.dart';
import 'addedit_location.dart';
import 'addedit_subproject.dart';

import 'cachedimage_widget.dart';
import 'app_theme.dart';
import 'breadcrumb_navigation.dart';
import 'location.dart';
import 'package:flutter/material.dart';

import 'showprojecttype_widget.dart';

class SubProjectDetailsPage extends StatefulWidget {
  final String id;
  final String userfullName;
  final String prevPageName;
  const SubProjectDetailsPage(
    this.id,
    this.prevPageName,
    this.userfullName, {
    super.key,
  });
  @override
  State<SubProjectDetailsPage> createState() => _SubProjectDetailsPageState();
  static MaterialPageRoute getRoute(
    String id,
    String prevPageName,
    String userName,
    String pageName,
  ) => MaterialPageRoute(
    settings: RouteSettings(name: pageName),
    builder:
        (context) => BlocProvider(
          create:
              (context) => SubProjectBloc(
                subprojectRepository: context.read<SubprojectRepository>(),
                // locationRepository: context.read<LocationRepository>(),
              )..add(LoadSubProjectEvent(id)),
          child: SubProjectDetailsPage(id, prevPageName, userName),
        ),
  );
}

//Add New Project
class _SubProjectDetailsPageState extends State<SubProjectDetailsPage>
    with SingleTickerProviderStateMixin {
  late int selectedTabIndex = 0;
  //Tab Controls
  late TabController _tabController;
  String userFullName = "";
  late String buildingId;

  late SubProject currentBuilding;
  late List<Child?> buildinglocations;
  late List<Child?> apartments;
  late Location newLocation;
  late Location newApartment;
  late String prevPageName;

  Location getLocation(String type) {
    return Location(
      parentid: buildingId,
      parenttype: 'subproject',
      name: '',
      description: '',
      createdby: userFullName,
      type: type,
      url: '',
    );
  }

  @override
  void initState() {
    buildingId = widget.id;
    userFullName = widget.userfullName;
    super.initState();
    prevPageName = widget.prevPageName;

    _tabController = TabController(vsync: this, length: 2);
    _tabController.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    switch (_tabController.index) {
      case 0:
        selectedTabIndex = 0;
        break;
      case 1:
        selectedTabIndex = 1;
        break;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void addEditSubProject() {
    setState(() {});
    final subprojectRepo = RepositoryProvider.of<SubprojectRepository>(context);
    final bloc = context.read<SubProjectBloc>();
    Navigator.push(
      context,
      AddEditSubProjectPage.getRoute(
        currentBuilding,
        false,
        userFullName,
        currentBuilding.name as String,
        subprojectRepository: subprojectRepo,
      ),
    ).then((value) {
      if (value == true) {
        bloc.add(LoadSubProjectEvent(widget.id));
      }
      setState(() {});
    });
  }

  void addNewChild(String name) {
    // setState(() {});
    final bloc = context.read<SubProjectBloc>();
    if (selectedTabIndex == 1) {
      final locationRepo = RepositoryProvider.of<LocationRepository>(context);
      Navigator.push(
        context,
        AddEditLocationPage.getRoute(
          getLocation('buildinglocation'),
          true,
          userFullName,
          name,
          locationRepository: locationRepo,
        ),
      ).then((value) {
        bloc.add(LoadSubProjectEvent(widget.id));
        setState(() {});
      });
    } else {
      final locationRepo = RepositoryProvider.of<LocationRepository>(context);
      Navigator.push(
        context,
        AddEditLocationPage.getRoute(
          getLocation('apartment'),
          true,
          userFullName,
          name,
          locationRepository: locationRepo,
        ),
      ).then((value) {
        bloc.add(LoadSubProjectEvent(widget.id));
        setState(() {});
      });
    }
  }

  void gotoDetails(String id, String type, String pageName) {
    final bloc = context.read<SubProjectBloc>();
    Navigator.push(
      context,
      LocationPage.getRoute(
        id,
        currentBuilding.name as String,
        type,
        userFullName,
        pageName,
      ),
      // MaterialPageRoute(
      //     builder: (context) => LocationPage(
      //         id, currentBuilding.name as String, type, userFullName)),
    ).then((value) {
      bloc.add(LoadSubProjectEvent(widget.id));
      setState(() => {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new),
          tooltip: 'Back',
        ),
        title: BlocBuilder<SubProjectBloc, SubProjectState>(
          buildWhen: (_, state) => state is SubProjectLoaded,
          builder: (context, state) {
            if (state is SubProjectLoaded) {
              return Text(
                state.subProject.name ?? 'Building',
                style: AppTextStyles.titleLarge,
                overflow: TextOverflow.ellipsis,
              );
            }
            return Text('Building', style: AppTextStyles.titleLarge);
          },
        ),
        actions: [
          if (!appSettings.isInvasiveMode)
            IconButton(
              onPressed: addEditSubProject,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Building',
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: BreadCrumbNavigator(),
        ),
      ),
      // floatingActionButton removed — breadcrumb now in AppBar bottom
      body: BlocBuilder<SubProjectBloc, SubProjectState>(
        builder: (context, state) {
          if (state is SubProjectLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is SubProjectLoaded) {
            currentBuilding = state.subProject;
            return SingleChildScrollView(
              child: Column(
                children: [
                  StatefulBuilder(
                    builder: (BuildContext context, StateSetter setState) {
                      return buildingDetails();
                    },
                  ),
                  subProjectChildrenTab(context),
                ],
              ),
            );
          } else if (state is SubProjectFailure) {
            return Center(child: Text(state.error));
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget buildingDetails() {
    return Padding(
      padding: const EdgeInsets.all(0.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          const ProjectType(),
          Container(
            height: 220,
            decoration: BoxDecoration(
              color:
                  appSettings.isInvasiveMode
                      ? AppColors.warning
                      : AppColors.primary,
              borderRadius: const BorderRadius.all(Radius.circular(12.0)),
              boxShadow: [
                BoxShadow(
                  blurRadius: 4.0,
                  color: AppColors.primary.withAlpha(60),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: cachedNetworkImage(currentBuilding.url),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Text(
                currentBuilding.name as String,
                maxLines: 2,
                style: AppTextStyles.headlineMedium,
                textAlign: TextAlign.left,
              ),
            ),
          ),
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Text(
                'Description',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.left,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: Text(
                      maxLines: 2,
                      currentBuilding.description as String,
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.left,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }

  Widget subProjectChildrenTab(BuildContext context) {
    // return DefaultTabController(
    //   length: 2,
    //   child:
    buildinglocations = List.empty(growable: true);
    apartments = List.empty(growable: true);
    if (appSettings.isInvasiveMode) {
      buildinglocations =
          currentBuilding.children
              .where(
                (element) =>
                    element.type == 'buildinglocation' && element.isInvasive,
              )
              .toList();

      apartments =
          currentBuilding.children
              .where(
                (element) => element.type == 'apartment' && element.isInvasive,
              )
              .toList();
    } else {
      buildinglocations =
          currentBuilding.children
              .where((element) => element.type == 'buildinglocation')
              .toList();
      apartments =
          currentBuilding.children
              .where((element) => element.type == 'apartment')
              .toList();
    }
    buildinglocations.sort((l1, l2) {
      if (l1!.sequenceNo != null && l2!.sequenceNo != null) {
        if (int.parse(l1.sequenceNo!) < int.parse(l2.sequenceNo!)) {
          return -1;
        } else {
          return 1;
        }
      } else {
        return l1.id.toString().compareTo(l2!.id.toString());
      }
    });
    apartments.sort((l1, l2) {
      if (l1!.sequenceNo != null && l2!.sequenceNo != null) {
        if (int.parse(l1.sequenceNo!) < int.parse(l2.sequenceNo!)) {
          return -1;
        } else {
          return 1;
        }
      } else {
        return l1.id.toString().compareTo(l2!.id.toString());
      }
    });
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              height: 44,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.apartment_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text('Apartments (${apartments.length})'),
                ],
              ),
            ),
            Tab(
              height: 44,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.place_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text('Locations (${buildinglocations.length})'),
                ],
              ),
            ),
          ],
        ),
        SizedBox(
          height: MediaQuery.of(context).size.height / 2,
          child: TabBarView(
            controller: _tabController,
            children: [
              locationsWidget('apartment'),
              locationsWidget('building location'),
            ],
          ),
        ),
      ],
      // ),
    );
  }

  Widget locationsWidget(String type) {
    bool isLocation = true;
    isLocation =
        type == 'building location'
            ? buildinglocations.isEmpty
            : apartments.isEmpty;
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Visibility(
            visible: !appSettings.isInvasiveMode,
            child: Align(
              alignment: Alignment.topRight,
              child: TextButton.icon(
                onPressed: () => addNewChild(currentBuilding.name as String),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: Text('Add $type'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          isLocation
              ? Align(
                alignment: Alignment.center,
                child: Text(
                  'No $type, Add $type.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              )
              : type == 'building location'
              ? Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  scrollDirection: Axis.horizontal,
                  itemCount: buildinglocations.length,
                  itemBuilder: (BuildContext context, int index) {
                    return horizontalScrollChildren(context, index);
                  },
                ),
              )
              : Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  scrollDirection: Axis.horizontal,
                  itemCount: apartments.length,
                  itemBuilder: (BuildContext context, int index) {
                    return horizontalScrollChildrenApartments(context, index);
                  },
                ),
              ),
        ],
      ),
    );
  }

  //Todo create widget for locations
  Widget horizontalScrollChildren(BuildContext context, int index) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.52,
      height: 210,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: GestureDetector(
          onTap:
              () => gotoDetails(
                buildinglocations[index]!.id!,
                'Common Location',
                buildinglocations[index]!.name as String,
              ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: [
                BoxShadow(
                  blurRadius: 4,
                  color: Colors.black.withAlpha(12),
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: SizedBox(
                    height: 130,
                    width: double.infinity,
                    child: cachedNetworkImage(buildinglocations[index]!.url),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
                  child: Text(
                    buildinglocations[index]!.name as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titleMedium,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                  child: Text(
                    buildinglocations[index]!.description as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget horizontalScrollChildrenApartments(BuildContext context, int index) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.52,
      height: 210,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: GestureDetector(
          onTap:
              () => gotoDetails(
                apartments[index]!.id!,
                'Apartment',
                apartments[index]!.name as String,
              ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: [
                BoxShadow(
                  blurRadius: 4,
                  color: Colors.black.withAlpha(12),
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: SizedBox(
                    height: 130,
                    width: double.infinity,
                    child: cachedNetworkImage(apartments[index]!.url),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
                  child: Text(
                    apartments[index]!.name as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titleMedium,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                  child: Text(
                    apartments[index]!.description as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
