import 'dart:io';

import 'package:camera/camera.dart';
import 'package:deckinspectors/src/ui/preview_screen.dart';
import 'package:flutter/material.dart';


class CapturesScreen extends StatelessWidget {
  final List<XFile> imageFileList;

  const CapturesScreen({super.key, required this.imageFileList});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:  [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child:  Text(
                'Captures',
                style: TextStyle(
                  fontSize: 32.0,
                  color: Colors.white,
                ),
              ),
            ),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              children: [
                for (XFile imageFile in imageFileList)
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.black,
                        width: 2,
                      ),
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => PreviewScreen(
                              fileList: imageFileList,
                              imageFile:  File(imageFile.path),
                            ),
                          ),
                        );
                      },
                      child: Image.file(
                        File(imageFile.path),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}