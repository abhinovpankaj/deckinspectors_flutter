import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
//import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import '../bloc/users_bloc.dart';
import '../models/error_response.dart';
import '../models/success_response.dart';
import 'package:path/path.dart' as path;

import 'urls.dart';

class ImagesApiProvider {
  Future<Object> uploadImage(
    String imageFilePath,
    String containerName,
    String uploader,
    String id,
    String parentType,
    String entityName,
  ) async {
    var endPoint = '${URLS.manageImagesUrl}upload';
    final baseUrl = Uri.parse(endPoint);
    Map<String, String> headers = {
      "authorization": usersBloc.userDetails.token as String,
    };
    var request = http.MultipartRequest('POST', baseUrl);
    request.files.add(
      await http.MultipartFile.fromPath('picture', imageFilePath),
    );
    if (containerName.length < 3) {
      containerName = containerName + uploader;
    }
    request.headers.addAll(headers);
    request.fields['id'] = id;
    request.fields['parentType'] = parentType;
    request.fields['type'] = entityName;
    request.fields['containerName'] =
        containerName.replaceAll(' ', '').toLowerCase();

    request.fields['uploader'] = uploader;

    var responseStream = await request.send();
    var response = await http.Response.fromStream(responseStream);
    if (response.statusCode == 201) {
      //return ImageResponse.fromJson(json.decode(response.body));
      var imgResponse = ImageResponse.fromJson(json.decode(response.body));
      imgResponse.originalPath = imageFilePath;
      return imgResponse;
    } else {
      return ErrorResponse.fromJson(json.decode(response.body));
    }
  }

  Future<Object> uploadImageLocally(
    String imageFilePath,
    String containerName,
    String uploader,
    String id,
    String parentType,
    String entityName,
  ) async {
    try {
      //Directory? directory = await getApplicationDocumentsDirectory();
      Directory? directory =
          Platform.isAndroid
              ? await getExternalStorageDirectory() //FOR ANDROID
              : await getApplicationSupportDirectory();

      if (File(imageFilePath).existsSync()) {
        File file = File(imageFilePath);
        var destDirectory = await Directory(
          path.join(directory!.path, entityName, containerName),
        ).create(recursive: true);
        var fileName = path.basename(imageFilePath);
        File copiedFile = await file.copy(
          path.join(destDirectory.path, fileName),
        );

        if (Platform.isAndroid) {
          //save to gallery
          // final result = await ImageGallerySaver.saveFile(copiedFile.path,
          //     name: 'E3Inspections');

          return ImageResponse(
            message: 'success',
            url: copiedFile.path,
            originalPath: copiedFile.path,
          );
        } else {
          // await ImageGallerySaver.saveFile(copiedFile.path,
          //     isReturnPathOfIOS: true, name: 'E3Inspections');
          return ImageResponse(
            message: 'success',
            url: path.join(entityName, containerName, fileName),
            originalPath: copiedFile.path,
          );
        }
      } else {
        return ErrorResponse(
          message: 'failure',
          errordata: 'file doesn\'t exist',
        );
      }
    } catch (e) {
      debugPrint(e.toString());
      return ErrorResponse(message: 'failure', errordata: e);
    }
  }
}
