import 'dart:io';

import 'package:cbl/cbl.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../bloc/images_bloc.dart';
import '../bloc/settings_bloc.dart';
import '../models/couchbase/couchbase_models.dart';
import '../models/success_response.dart';
import '../resources/couchbase/database_provider.dart';

class ImageSyncService {
  // DatabaseProvider is a singleton — we always get the same initialised instance.
  final DatabaseProvider _db = DatabaseProvider();

  Future<void> retryPendingUploads() async {
    // Skip if the user has manually enabled offline mode.
    if (DatabaseProvider.offlineModeOn) return;
    // Skip if a previous sync run is still in progress.
    if (appSettings.isImageUploading) return;
    // DB and collections are only ready after login (initDatabases).
    if (_db.e3inspectionsDatabase == null) return;

    appSettings.isImageUploading = true;
    // Keep the device awake while uploading (ignore if platform channel unavailable).
    // try {
    //   //await WakelockPlus.enable();
    // } on PlatformException catch (e) {
    //   debugPrint('[ImageSyncService] Wakelock not available: ${e.message}');
    // }

    try {
      final pending = await _queryPendingImages();
      debugPrint('[ImageSyncService] ${pending.length} pending image(s).');

      for (final entry in pending) {
        // Bail out mid-loop if the connection drops again.
        if (!appSettings.activeConnection || DatabaseProvider.offlineModeOn) {
          debugPrint('[ImageSyncService] Connection lost — pausing sync.');
          break;
        }

        final docId = entry.key;
        final image = entry.value;
        final rawLocalPath = image.remoteUrl;
        if (rawLocalPath == null || rawLocalPath.isEmpty) continue;

        // On iOS, local paths stored in DeckImage are relative to
        // getApplicationSupportDirectory(), matching what uploadImageLocally
        // stores in ImageResponse.url on iOS.
        String transformedPath = rawLocalPath;
        if (Platform.isIOS && !rawLocalPath.startsWith('/')) {
          final dir = await getApplicationSupportDirectory();
          transformedPath = path.join(dir.path, rawLocalPath);
        }

        // Skip if the file has been deleted from the device.
        if (!File(transformedPath).existsSync()) {
          debugPrint(
            '[ImageSyncService] File missing, skipping: $transformedPath',
          );
          continue;
        }

        try {
          // containerName  → sectionname  (entity name for Azure Blob container)
          // id             → parentid     (parent document id)
          // parentType     → parenttype
          // entityName     → sectiontype
          final result = await imagesBloc.uploadImage(
            transformedPath,
            image.sectionname ?? '',
            image.uploadedBy ?? '',
            image.parentid ?? '',
            image.parenttype ?? '',
            image.sectiontype ?? '',
          );

          if (result is ImageResponse && result.url != null) {
            final remoteUrl = result.url!;

            // Only mark as fully uploaded when we received an http URL;
            // a local path means the upload fell back to local storage again.
            final uploaded = remoteUrl.startsWith('http');

            await _markDeckImage(docId, image, remoteUrl, uploaded);

            if (uploaded) {
              await _updateParentDocument(image, rawLocalPath, remoteUrl);
              debugPrint(
                '[ImageSyncService] ✓ ${image.sectiontype} '
                '(${image.parentid}) → $remoteUrl',
              );
            }
          }
        } catch (e) {
          // Log and continue — never abort the whole batch for one failure.
          debugPrint('[ImageSyncService] Error uploading $transformedPath: $e');
        }
      }
    } catch (e) {
      debugPrint('[ImageSyncService] retryPendingUploads error: $e');
    } finally {
      appSettings.isImageUploading = false;
      // try {
      //   await WakelockPlus.disable();
      // } on PlatformException catch (e) {
      //   debugPrint('[ImageSyncService] Wakelock disable failed: ${e.message}');
      // }
    }
  }

  // ── CBL query ─────────────────────────────────────────────────────────────

  Future<List<MapEntry<String, DeckImage>>> _queryPendingImages() async {
    final query = QueryBuilder.createAsync()
        .select(SelectResult.all(), SelectResult.expression(Meta.id))
        .from(DataSource.collection(_db.deckImageCollection).as('DeckImage'))
        .where(
          Expression.property('isuploaded').equalTo(Expression.boolean(false)),
        );

    final rows = await (await query.execute()).allResults();
    final result = <MapEntry<String, DeckImage>>[];
    for (final row in rows) {
      final map = row.toPlainMap();
      final docId = map['id'] as String? ?? '';
      final data = map['DeckImage'] as Map<String, dynamic>?;
      if (data == null || docId.isEmpty) continue;
      result.add(MapEntry(docId, DeckImage.fromDocument(data)));
    }
    return result;
  }

  // ── DeckImage record update ───────────────────────────────────────────────

  Future<void> _markDeckImage(
    String docId,
    DeckImage image,
    String remoteUrl,
    bool uploaded,
  ) async {
    // Preserve original localUrl; only update remoteUrl and isuploaded.
    final updated = DeckImage(
      localUrl: image.localUrl,
      remoteUrl: remoteUrl,
      isuploaded: uploaded,
      parentid: image.parentid,
      parenttype: image.parenttype,
      sectiontype: image.sectiontype,
      sectionname: image.sectionname,
      uploadedBy: image.uploadedBy,
    );
    final doc = MutableDocument.withId(docId, updated.toDocument());
    await _db.deckImageCollection.saveDocument(doc);
  }

  // ── Parent document updates ───────────────────────────────────────────────

  /// Routes the post-upload parent update to the correct handler based on
  /// [DeckImage.parenttype]. Parenttype values match what the CBL repositories
  /// write when they create DeckImage records offline.
  Future<void> _updateParentDocument(
    DeckImage image,
    String localUrl,
    String remoteUrl,
  ) async {
    final parentId = image.parentid;
    if (parentId == null || parentId.isEmpty) return;

    switch (image.parenttype) {
      // ── Single-URL entities ──────────────────────────────────────────────
      case 'project':
        await _updateProjectUrl(parentId, remoteUrl);

      case 'subProject':
        // 1. Update the subProject's own url field.
        await _updateDocField(
          _db.subProjectCollection,
          parentId,
          'url',
          remoteUrl,
        );
        // 2. Update the url inside the parent project's children array.
        final subDoc = await _db.subProjectCollection.document(parentId);
        if (subDoc != null) {
          final parentProjectId =
              subDoc.toPlainMap()['parentid'] as String? ?? '';
          if (parentProjectId.isNotEmpty) {
            await _updateChildUrlInParent(
              _db.projectCollection,
              parentProjectId,
              parentId,
              remoteUrl,
            );
          }
        }

      case 'location':
        // 1. Update the location's own url field.
        await _updateDocField(
          _db.locationCollection,
          parentId,
          'url',
          remoteUrl,
        );
        // 2. Update the url inside the parent (project or subProject) children.
        final locDoc = await _db.locationCollection.document(parentId);
        if (locDoc != null) {
          final locMap = locDoc.toPlainMap();
          final locParentId = locMap['parentid'] as String? ?? '';
          final locParentType = locMap['parenttype'] as String? ?? '';
          if (locParentId.isNotEmpty) {
            final parentCollection =
                locParentType == 'project'
                    ? _db.projectCollection
                    : _db.subProjectCollection;
            await _updateChildUrlInParent(
              parentCollection,
              locParentId,
              parentId,
              remoteUrl,
            );
          }
        }

      // ── Image-list entities ───────────────────────────────────────────────
      case 'visualSection':
        await _replaceInImageList(
          _db.visualSectionCollection,
          parentId,
          'images',
          localUrl,
          remoteUrl,
        );
        // Update coverUrl on the parent location/project section entry.
        await _updateSectionCoverUrl(parentId, remoteUrl);

      case 'dynamicSection':
        await _replaceInImageList(
          _db.dynamicSectionCollection,
          parentId,
          'images',
          localUrl,
          remoteUrl,
        );
        await _updateSectionCoverUrl(parentId, remoteUrl);

      case 'invasiveSection':
        await _replaceInImageList(
          _db.invasiveSectionCollection,
          parentId,
          'invasiveimages',
          localUrl,
          remoteUrl,
        );

      case 'conclusiveSection':
        await _replaceInImageList(
          _db.conclusiveSectionCollection,
          parentId,
          'conclusiveimages',
          localUrl,
          remoteUrl,
        );

      default:
        debugPrint(
          '[ImageSyncService] Unknown parenttype "${image.parenttype}" — skipping parent update.',
        );
    }
  }

  // ── Low-level helpers ─────────────────────────────────────────────────────

  /// Sets a single string [field] on [docId] in [collection] to [value].
  Future<void> _updateDocField(
    Collection collection,
    String docId,
    String field,
    String value,
  ) async {
    final doc = await collection.document(docId);
    if (doc == null) return;
    final map = Map<String, dynamic>.from(doc.toPlainMap());
    map[field] = value;
    await collection.saveDocument(MutableDocument.withId(docId, map));
  }

  /// Updates [project.url] and also updates [project.children[*].url]
  /// where the child id matches [projectId] itself (for project image).
  Future<void> _updateProjectUrl(String projectId, String remoteUrl) async {
    final doc = await _db.projectCollection.document(projectId);
    if (doc == null) return;
    final map = Map<String, dynamic>.from(doc.toPlainMap());
    map['url'] = remoteUrl;
    await _db.projectCollection.saveDocument(
      MutableDocument.withId(projectId, map),
    );
  }

  /// Finds [childId] inside the `children` array of [parentDocId] in
  /// [parentCollection] and updates its `url` field.
  Future<void> _updateChildUrlInParent(
    Collection parentCollection,
    String parentDocId,
    String childId,
    String newUrl,
  ) async {
    final doc = await parentCollection.document(parentDocId);
    if (doc == null) return;
    final map = Map<String, dynamic>.from(doc.toPlainMap());
    final children =
        (map['children'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
    if (children == null) return;
    bool changed = false;
    for (final child in children) {
      if (child['id'] == childId) {
        child['url'] = newUrl;
        changed = true;
      }
    }
    if (!changed) return;
    map['children'] = children;
    await parentCollection.saveDocument(
      MutableDocument.withId(parentDocId, map),
    );
  }

  /// Replaces [oldUrl] with [newUrl] inside the [imageField] list of
  /// [docId] in [collection].
  Future<void> _replaceInImageList(
    Collection collection,
    String docId,
    String imageField,
    String oldUrl,
    String newUrl,
  ) async {
    final doc = await collection.document(docId);
    if (doc == null) return;
    final map = Map<String, dynamic>.from(doc.toPlainMap());
    final images = (map[imageField] as List<dynamic>?)?.cast<String>();
    if (images == null) return;
    final index = images.indexOf(oldUrl);
    if (index < 0) return;
    images[index] = newUrl;
    map[imageField] = images;
    await collection.saveDocument(MutableDocument.withId(docId, map));
  }

  /// After a visualSection/dynamicSection image is uploaded, updates the
  /// `coverUrl` (and optionally image count) in the parent location or
  /// project's `sections` array entry for that section.
  Future<void> _updateSectionCoverUrl(String sectionId, String coverUrl) async {
    // Find the section doc to get its parentid and parenttype.
    // Try visualSectionCollection first; fall back to dynamicSectionCollection.
    Map<String, dynamic>? sectionMap;
    for (final col in [
      _db.visualSectionCollection,
      _db.dynamicSectionCollection,
    ]) {
      final doc = await col.document(sectionId);
      if (doc != null) {
        sectionMap = doc.toPlainMap();
        break;
      }
    }
    if (sectionMap == null) return;

    final parentId = sectionMap['parentid'] as String? ?? '';
    final parentType = sectionMap['parenttype'] as String? ?? '';
    final images =
        (sectionMap['images'] as List<dynamic>?)?.cast<String>() ?? [];

    if (parentId.isEmpty) return;

    final Collection parentCollection;
    if (parentType == 'project') {
      parentCollection = _db.projectCollection;
    } else {
      // parentType == 'location' for standard visual sections
      parentCollection = _db.locationCollection;
    }

    final parentDoc = await parentCollection.document(parentId);
    if (parentDoc == null) return;
    final parentMap = Map<String, dynamic>.from(parentDoc.toPlainMap());
    final sections =
        (parentMap['sections'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
    if (sections == null) return;

    bool changed = false;
    for (final section in sections) {
      if (section['id'] == sectionId) {
        section['count'] = images.length;
        if (coverUrl.isNotEmpty) section['coverUrl'] = coverUrl;
        changed = true;
      }
    }
    if (!changed) return;
    parentMap['sections'] = sections;
    await parentCollection.saveDocument(
      MutableDocument.withId(parentId, parentMap),
    );
  }
}
