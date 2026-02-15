import 'package:cbl/cbl.dart';
import 'package:flutter/material.dart';

import '../../models/couchbase/couchbase_models.dart';
import 'database_provider.dart';

class InvasiveSectionRepository {
  final DatabaseProvider databaseProvider;

  InvasiveSectionRepository({required this.databaseProvider});

  Future<InvasiveSection?> getInvasiveSection(String id) async {
    try {
      final doc = await databaseProvider.invasiveSectionCollection.document(id);

      if (doc != null) {
        final data = doc.toPlainMap();
        final section = InvasiveSection.fromDocument(data);
        section.id = id; // Preserve the document ID
        return section;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch invasive section: $e');
    }
  }

  Future<InvasiveSection?> getInvasiveSectionByVisualId(String id) async {
    try {
      final query = QueryBuilder.createAsync()
          .select(SelectResult.all())
          .from(
            DataSource.collection(
              databaseProvider.invasiveSectionCollection,
            ).as('InvasiveSection'),
          )
          .where(
            Expression.property('docType')
                .equalTo(Expression.string('InvasiveSection'))
                .and(
                  Expression.property(
                    'visualSectionId',
                  ).equalTo(Expression.string(id)),
                ),
          );
      final result = await query.execute();
      final results = await result.allResults();
      return InvasiveSection.fromDocument(results.first.toPlainMap());
    } catch (e) {
      throw Exception('Failed to fetch invasive section: $e');
    }
  }

  Future<InvasiveSection> addupdateInvasiveSection({
    required InvasiveSection section,
    required String description,
    required bool postInvasiveRepairsRequired,
    required List<String> invasiveImages,
    required bool isNewSection,
  }) async {
    try {
      section.invasiveDescription = description;
      section.postinvasiverepairsrequired = postInvasiveRepairsRequired;
      section.invasiveimages = invasiveImages;

      if (isNewSection && (section.id == null || section.id!.isEmpty)) {
        section.id = generateId();
      }

      final doc = MutableDocument.withId(
        section.id as String,
        section.toDocument(),
      );
      await databaseProvider.invasiveSectionCollection.saveDocument(doc);

      return section;
    } catch (e) {
      throw Exception('Failed to save invasive section: $e');
    }
  }

  Future<String> deleteInvasiveSection(InvasiveSection invasiveSection) async {
    try {
      final doc = await databaseProvider.invasiveSectionCollection.document(
        invasiveSection.id as String,
      );
      if (doc != null) {
        await databaseProvider.invasiveSectionCollection.deleteDocument(doc);
      }
      return 'success';
    } catch (e) {
      debugPrint('Error deleting invasive section: $e');
      return 'failed';
    }
  }

  String generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }
}
