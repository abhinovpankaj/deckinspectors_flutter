import 'package:E3InspectionsMultiTenant/src/bloc/settings_bloc.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

Future<XFile?> captureImage(BuildContext context) async {
  final ImagePicker picker = ImagePicker();
  XFile? imageFile;
  int imageQuality = 100;
  var quality = appSettings.currentQuality;
  switch (quality) {
    case ImageQuality.high:
      imageQuality = 100;
      break;
    case ImageQuality.medium:
      imageQuality = 70;
      break;
    case ImageQuality.low:
      imageQuality = 40;
      break;
  }

  return showModalBottomSheet<XFile?>(
    context: context,
    isDismissible: true,
    builder: (context) {
      return Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined, color: Colors.blue),
            title: const Text('Camera'),
            onTap: () async {
              imageFile = await picker.pickImage(
                source: ImageSource.camera,
                imageQuality: imageQuality,
                requestFullMetadata: false,
              );

              Navigator.pop(context, imageFile);
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.browse_gallery_outlined,
              color: Colors.blue,
            ),
            title: const Text('Gallery'),
            onTap: () async {
              //todo
              imageFile = await picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: imageQuality,
              );

              Navigator.pop(context, imageFile);
            },
          ),
        ],
      );
    },
  );
  // return imageFile;
}
