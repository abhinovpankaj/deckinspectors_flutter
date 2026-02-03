import 'package:cbl/cbl.dart';
import 'package:flutter/material.dart';

import '../../models/couchbase/couchbase_models.dart';
import 'database_provider.dart';

class ImageRepository {
  final DatabaseProvider _databaseProvider;
  ImageRepository(this._databaseProvider);

  final String projectDocumentType = 'deckImage';
  final String attributeDocumentType = 'documentType';

  Future<void> saveImage(DeckImage image) async {
    try {
      final id = CouchbaseDocument.generateId();
      final doc = MutableDocument.withId(id, image.toDocument());
      await _databaseProvider.deckImageCollection.saveDocument(doc);
    } catch (e) {
      debugPrint('Error saving image: $e');
    }
  }

  Future<List<String>> getImagesNotUploaded(
    List<String> capturedImages,
    bool activeConnection,
    bool isNewSection,
  ) async {
    List<String> offlineImages = [];
    try {
      if (activeConnection && !_databaseProvider.isAppOfflineMode()) {
        return capturedImages.where((e) => !e.startsWith('http')).toList();
      } else {
        if (isNewSection) {
          return capturedImages;
        } else {
          for (var imgpath in capturedImages) {
            final query = QueryBuilder.createAsync()
                .select(SelectResult.all())
                .from(
                  DataSource.collection(
                    _databaseProvider.deckImageCollection,
                  ).as('DeckImage'),
                )
                .where(
                  Expression.property(
                    'localUrl',
                  ).equalTo(Expression.string(imgpath)),
                );
            final result = await query.execute();
            final results = await result.allResults();

            if (results.isEmpty) {
              offlineImages.add(imgpath);
            }
          }
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    }
    return offlineImages;
  }

  Future<String?> getLocalPathForRemoteUrl(String remoteUrl) async {
    try {
      if (!remoteUrl.startsWith('http')) {
        return remoteUrl;
      }

      final query = QueryBuilder.createAsync()
          .select(SelectResult.all())
          .from(
            DataSource.collection(
              _databaseProvider.deckImageCollection,
            ).as('DeckImage'),
          )
          .where(
            Expression.property(
              'remoteUrl',
            ).equalTo(Expression.string(remoteUrl)),
          );
      final result = await query.execute();
      final rows = await result.allResults();
      if (rows.isEmpty) return null;

      final data = rows.first['DeckImage'] as Map<String, dynamic>?;
      return data?['localUrl'] as String?;
    } catch (e) {
      debugPrint('Error getting local path: $e');
      return null;
    }
  }
}
