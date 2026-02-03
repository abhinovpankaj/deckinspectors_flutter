// import 'package:cbl/cbl.dart';

// import '../../models/couchbase/couchbase_models.dart';
// import 'database_provider.dart';

// class InvasiveSectionRepository {
//   final DatabaseProvider databaseProvider;

//   InvasiveSectionRepository({required this.databaseProvider});

//   Future<InvasiveSection?> getInvasiveSection(String id) async {
//     try {
//       final doc =
//           await databaseProvider.invasiveSectionCollection
//               .document(id)
//               ?.getDocument();

//       if (doc != null) {
//         final data = doc.toPlainMap();
//         final section = InvasiveSection.fromDocument(data);
//         section.id = id; // Preserve the document ID
//         return section;
//       }
//       return null;
//     } catch (e) {
//       throw Exception('Failed to fetch invasive section: $e');
//     }
//   }

//   Future<InvasiveSection> addupdateInvasiveSection({
//     required InvasiveSection section,
//     required String description,
//     required bool postInvasiveRepairsRequired,
//     required List<String> invasiveImages,
//     required bool isNewSection,
//   }) async {
//     try {
//       section.invasiveDescription = description;
//       section.postinvasiverepairsrequired = postInvasiveRepairsRequired;
//       section.invasiveimages = invasiveImages;

//       if (isNewSection && (section.id == null || section.id!.isEmpty)) {
//         section.id = generateId();
//       }

//       final doc = MutableDocument.withId(
//         section.id as String,
//         section.toDocument(),
//       );
//       await databaseProvider.invasiveSectionCollection.saveDocument(doc);

//       return section;
//     } catch (e) {
//       throw Exception('Failed to save invasive section: $e');
//     }
//   }

//   Future<void> deleteInvasiveSection(InvasiveSection section) async {
//     try {
//       await databaseProvider.invasiveSectionCollection
//           .document(section.id!)
//           .delete();
//     } catch (e) {
//       throw Exception('Failed to delete invasive section: $e');
//     }
//   }

//   String generateId() {
//     return '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
//   }
// }
