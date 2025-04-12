import '../realm/realm_schemas.dart';

class SyncData {
  List<Project> projects;
  List<SubProject> subProjects;
  List<Location> locations;
  List<VisualSection> visualSections;
  List<InvasiveSection> invasiveSections;
  List<ConclusiveSection> conclusiveSections;
  List<DeckImage> deckImages;
  List<DynamicVisualSection> dynamicVisualSections;
  List<LocationForm> locationForms;

  SyncData({
    required this.projects,
    required this.subProjects,
    required this.locations,
    required this.visualSections,
    required this.invasiveSections,
    required this.conclusiveSections,
    required this.deckImages,
    required this.dynamicVisualSections,
    required this.locationForms,
  });

  // Map<String, dynamic> toJson() {
  //   return {
  //     'projects': projects.map((e) => e.toJson()).toList(),
  //     'subProjects': subProjects.map((e) => e.toJson()).toList(),
  //     'locations': locations.map((e) => e.toJson()).toList(),
  //     'visualSections': visualSections.map((e) => e.toJson()).toList(),
  //     'invasiveSections': invasiveSections.map((e) => e.toJson()).toList(),
  //     'conclusiveSections': conclusiveSections.map((e) => e.toJson()).toList(),
  //     'deckImages': deckImages.map((e) => e.toJson()).toList(),
  //     'dynamicVisualSections':
  //         dynamicVisualSections.map((e) => e.toJson()).toList(),
  //     'locationForms': locationForms.map((e) => e.toJson()).toList(),
  //   };
  // }
}
