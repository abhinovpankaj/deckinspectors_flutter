import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

Widget networkImage(String? netWorkImageURL) {
  String imageURL = netWorkImageURL ?? '';

  if (imageURL.isEmpty) {
    return Image.asset(
      'assets/images/icon.png',
      fit: BoxFit.fill,
      width: double.infinity,
    );
  }

  if (imageURL.startsWith('http')) {
    return CachedNetworkImage(
      placeholder:
          (context, url) => const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(),
          ),
      imageUrl: imageURL,
      fit: BoxFit.cover,
    );
  }

  // Local file: resolve path asynchronously (handles iOS support dir) and render
  return FutureBuilder<File?>(
    future: getImageFile(imageURL),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(),
        );
      }

      if (snapshot.hasData && snapshot.data != null) {
        return Image.file(
          snapshot.data!,
          fit: BoxFit.fill,
          width: double.infinity,
        );
      }

      // Fallback when file doesn't exist or an error occurred
      return Image.asset(
        'assets/images/icon.png',
        fit: BoxFit.fill,
        width: double.infinity,
      );
    },
  );
}

Future<File?> getImageFile(String imageURL) async {
  try {
    var resolved = imageURL;
    if (Platform.isIOS) {
      resolved = path.join(await localPath, imageURL);
    }

    final file = File(resolved);
    if (await file.exists()) return file;
  } catch (_) {
    // ignore
  }
  return null;
}

Future<String> get localPath async {
  final directory = await getApplicationSupportDirectory();
  return directory.path;
}
