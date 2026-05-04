import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/location_bloc.dart';
import '../bloc/location_event.dart';
import '../bloc/location_state.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/users_bloc.dart';
import '../models/couchbase/couchbase_models.dart';
import '../resources/couchbase/image_repository.dart';
import '../resources/couchbase/location_repository.dart';
import '../resources/couchbase/section_repository.dart';
//import 'breadcrumb_navigation.dart';
import 'addedit_location.dart';
import 'app_theme.dart';
import 'breadcrumb_navigation.dart';
import 'cachedimage_widget.dart';
import 'dynamic_section.dart';
import 'invasivesection.dart';
import 'section.dart';
import 'showprojecttype_widget.dart';

class LocationPage extends StatefulWidget {
  final String id;
  final String userFullName;
  final String parentType;
  final String locationType;
  const LocationPage(
    this.id,
    this.parentType,
    this.locationType,
    this.userFullName, {
    super.key,
  });
  @override
  State<LocationPage> createState() => _LocationPageState();
  static MaterialPageRoute getRoute(
    String id,
    String parentType,
    String locationType,
    String userName,
    String pageName,
  ) => MaterialPageRoute(
    settings: RouteSettings(name: pageName),
    builder:
        (context) => BlocProvider(
          create:
              (context) => LocationBloc(
                locationRepository: context.read<LocationRepository>(),
              )..add(LoadLocationEvent(id)),
          child: LocationPage(id, parentType, locationType, userName),
        ),
  );
}

class _LocationPageState extends State<LocationPage> {
  @override
  void initState() {
    locationId = widget.id;
    parenttype = widget.parentType;
    userFullName = widget.userFullName;
    locationType = widget.locationType;
    super.initState();
  }

  String locationType = '';
  String parenttype = 'Project';
  String userFullName = "";
  late String locationId;
  late Location currentLocation;
  late List<Section> sections;
  String? formId;
  @override
  Widget build(BuildContext context) {
    formId = usersBloc.currentFormId;
    return BlocBuilder<LocationBloc, LocationState>(
      builder: (context, state) {
        if (state is LocationLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (state is LocationLoaded) {
          currentLocation = state.location;

          return Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              leading: IconButton(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.arrow_back_ios_new),
                tooltip: 'Back',
              ),
              title: Text(
                currentLocation.name ?? locationType,
                style: AppTextStyles.titleLarge,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                if (!appSettings.isInvasiveMode)
                  IconButton(
                    onPressed: () => addEditLocation(currentLocation),
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit Location',
                  ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(24),
                child: BreadCrumbNavigator(),
              ),
            ),
            body: SingleChildScrollView(
              child: Column(
                children: [
                  locationDetails(currentLocation),
                  locationsWidget(context),
                ],
              ),
            ),
          );
        }

        if (state is LocationError) {
          return Scaffold(body: Center(child: Text(state.message)));
        }

        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }

  Widget locationDetails(Location currentLocation) {
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
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12.0),
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 4.0,
                  color: AppColors.primary.withAlpha(60),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(8.0),
              ),
              child: cachedNetworkImage(currentLocation.url),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Text(
                currentLocation.name as String,
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
                      currentLocation.description as String,
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

  Widget locationsWidget(BuildContext context) {
    sections =
        appSettings.isInvasiveMode
            ? currentLocation.sections
                .where((element) => element.isInvasive)
                .toList()
            : currentLocation.sections.toList();
    return SizedBox(
      height: 550,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Padding(
                  padding: EdgeInsets.all(4),
                  child: Text(
                    'Sections',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (!appSettings.isInvasiveMode)
                  TextButton.icon(
                    onPressed: addNewChild,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Add Section'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      textStyle: AppTextStyles.labelMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),
            sections.isEmpty
                ? const Center(
                  child: Text(
                    'No locations to show.',
                    style: TextStyle(fontSize: 16),
                  ),
                )
                : SizedBox(
                  height: 310,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: sections.length,
                    itemBuilder:
                        (BuildContext context, int index) =>
                            horizontalScrollChildren(context, index),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget horizontalScrollChildren(BuildContext context, int index) {
    String vreview = '';
    String visualReview = '';
    if (sections[index].visualreview == null) {
      visualReview = 'good';
    } else {
      visualReview = sections[index].visualreview as String;
    }

    switch (visualReview.toLowerCase()) {
      case 'good':
        vreview = 'Good';
        break;
      case 'fair':
        vreview = 'Fair';
        break;
      case 'bad':
        vreview = 'Bad';
        break;
      default:
    }
    String assessment = '';
    String? coverUrl = sections[index].coverUrl;

    String assessmentActual = '';
    if (sections[index].conditionalassessment == null) {
      assessmentActual = 'pass';
    } else {
      assessmentActual = (sections[index].conditionalassessment as String);
    }
    switch (assessmentActual.toLowerCase()) {
      case 'pass':
        assessment = 'Pass';
        break;
      case 'fail':
        assessment = 'Fail';
        break;
      case 'futureinspection':
        assessment = 'Future Inspection';
        break;
      default:
    }
    bool furtherInvasive = sections[index].furtherinvasivereviewrequired;
    //print("${sections[index].name}:${sections[index].isUploading}");
    bool visualLeaks = sections[index].visualsignsofleak;
    return SizedBox(
      width: MediaQuery.of(context).size.width - 70,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 8, 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (appSettings.isInvasiveMode) {
              gotoInvasiveDetails(
                sections[index].id,
                sections[index].name as String,
              );
            } else {
              gotoDetails(sections[index].id, sections[index].name as String);
            }
          },
          child: Card(
            elevation: 2,
            shadowColor: AppColors.cardBorder,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.cardBorder, width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Image — 140px with photo count badge overlaid
                SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      cachedNetworkImage(coverUrl),
                      if (sections[index].isuploading)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: LinearProgressIndicator(
                            backgroundColor: AppColors.primary.withAlpha(60),
                            color: AppColors.primary,
                            minHeight: 3,
                          ),
                        ),
                      // photo count badge bottom-right
                      Positioned(
                        bottom: 6,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.photo_outlined,
                                size: 10,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                sections[index].count.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Details — name + mode badge + compact 2-col stats
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              sections[index].name as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.titleMedium,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: appSettings.isInvasiveMode
                                  ? AppColors.warning.withAlpha(30)
                                  : AppColors.primary.withAlpha(20),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              appSettings.isInvasiveMode
                                  ? 'Invasive'
                                  : 'Visual',
                              style: TextStyle(
                                color: appSettings.isInvasiveMode
                                    ? AppColors.warning
                                    : AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (formId == null) ...[
                        const SizedBox(height: 6),
                        const Divider(height: 1),
                        const SizedBox(height: 6),
                        _SectionStat('Review', vreview),
                        const SizedBox(height: 4),
                        _SectionStat('Assessment', assessment),
                        const SizedBox(height: 4),
                        _SectionStat('Leaks', visualLeaks ? 'Yes' : 'No'),
                        const SizedBox(height: 4),
                        _SectionStat('Further', furtherInvasive ? 'Yes' : 'No'),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void addNewChild() {
    final bloc = context.read<LocationBloc>();
    final locationRepo = RepositoryProvider.of<LocationRepository>(context);
    final sectionRepo = RepositoryProvider.of<SectionRepository>(context);
    final imageRepo = RepositoryProvider.of<ImageRepository>(context);
    if (formId == null) {
      Navigator.push(
        context,
        SectionPage.getRoute(
          '',
          currentLocation.id as String,
          userFullName,
          locationType,
          currentLocation.name as String,
          true,
          "New",
          sectionRepository: sectionRepo,
          locationRepository: locationRepo,
          imageRepository: imageRepo,
          onUploadComplete: () {
            if (mounted) {
              bloc.add(RefreshLocationEvent(locationId));
            }
          },
        ),
      ).then((value) {
        if (value == true) {
          Future.delayed(const Duration(milliseconds: 200), () {
            bloc.add(RefreshLocationEvent(locationId));
          });
        }
        setState(() {});
      });
    } else {
      Navigator.push(
        context,
        DynamicVisualSectionPage.getRoute(
          currentLocation.id as String,
          userFullName,
          locationType,
          currentLocation.name as String,
          formId as String,
          true,
          "New",
        ),
      ).then((value) {
        if (value == true) {
          bloc.add(LoadLocationEvent(locationId));
        }
        setState(() {});
      });
    }
  }

  void gotoDetails(String sectionId, String sectionName) {
    final bloc = context.read<LocationBloc>();
    final locationRepo = RepositoryProvider.of<LocationRepository>(context);
    final sectionRepo = RepositoryProvider.of<SectionRepository>(context);
    final imageRepo = RepositoryProvider.of<ImageRepository>(context);
    if (formId != null) {
      Navigator.push(
        context,
        DynamicVisualSectionPage.getRoute(
          currentLocation.id as String,
          userFullName,
          locationType,
          currentLocation.name as String,
          formId as String,
          false,
          sectionId,
        ),
      ).then((value) {
        if (!mounted) return;
        if (value == true) {
          Future.delayed(const Duration(milliseconds: 200), () {
            bloc.add(LoadLocationEvent(locationId));
          });
        }
        setState(() {});
      });
    } else {
      Navigator.push(
        context,
        SectionPage.getRoute(
          sectionId,
          currentLocation.id as String,
          userFullName,
          locationType,
          currentLocation.name as String,
          false,
          sectionName,
          sectionRepository: sectionRepo,
          locationRepository: locationRepo,
          imageRepository: imageRepo,
          onUploadComplete: () {
            if (mounted) {
              bloc.add(LoadLocationEvent(locationId));
            }
          },
        ),
      ).then((value) {
        if (!mounted) {
          return;
        }
        if (value is bool) {
          if (value == true) {
            Future.delayed(const Duration(milliseconds: 200), () {
              bloc.add(LoadLocationEvent(locationId));
            });
          }
        }
        setState(() {});
      });
    }
  }

  void addEditLocation(Location currentLocation) {
    final locationRepo = RepositoryProvider.of<LocationRepository>(context);
    Navigator.push(
      context,
      AddEditLocationPage.getRoute(
        currentLocation,
        false,
        userFullName,
        currentLocation.name as String,
        locationRepository: locationRepo,
      ),
    ).then((value) {
      if (value == true) {
        try {
          context.read<LocationBloc>().add(LoadLocationEvent(locationId));
        } catch (exception) {
          debugPrint(
            'Error reloading location after edit.'
            '$exception',
          );
        }
      }
    });
  }

  void gotoInvasiveDetails(String id, String sectionName) {
    final sectionRepo = RepositoryProvider.of<SectionRepository>(context);
    final imageRepo = RepositoryProvider.of<ImageRepository>(context);
    Navigator.push(
      context,
      InvasiveSectionPage.getRoute(
        id,
        currentLocation.id as String,
        userFullName,
        locationType,
        currentLocation.name as String,
        false,
        sectionName,
        sectionRepository: sectionRepo,
        imageRepository: imageRepo,
      ),
    ).then((value) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }
}

class _SectionStat extends StatelessWidget {
  final String label;
  final String value;
  const _SectionStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
