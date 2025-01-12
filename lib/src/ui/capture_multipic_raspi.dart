import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:udp/udp.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'image_widget.dart';

class PiZeroCameraScreen extends StatefulWidget {
  const PiZeroCameraScreen({super.key});

  @override
  State<PiZeroCameraScreen> createState() => PiZeroCameraScreenState();
}

class PiZeroCameraScreenState extends State<PiZeroCameraScreen> {
  String baseUrl = "";
  late WebViewController controller;
  List<XFile> capturedImages = [];
  bool isCapturing = false;

  @override
  void initState() {
    super.initState();
    _listenForPiIpAddress();
    controller = WebViewController();
  }

  Future<void> _listenForPiIpAddress() async {
    var receiver = await UDP.bind(Endpoint.any(port: const Port(5005)));
    //receiver.send([1, 2, 3, 4], Endpoint.any(port: const Port(5005)));
    receiver.asStream().listen((datagram) {
      if (datagram != null) {
        String message = String.fromCharCodes(datagram.data);
        setState(() {
          baseUrl = 'http://${message.split(' ')[0]}:5000';
          debugPrint('Raspberry Pi IP Address: ${message.split(' ')[0]}');

          controller.setJavaScriptMode(JavaScriptMode.unrestricted);
          controller.loadRequest(Uri.parse('$baseUrl/video_feed'));
        });
        receiver.close();
      }
    });
    // Keep the receiver open for 60 seconds
    await Future.delayed(const Duration(seconds: 60));
    receiver.close();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        // floatingActionButton: FloatingActionButton(
        //   onPressed: refresh,
        //   tooltip: 'Refresh',
        //   child: const Icon(Icons.video_call),
        // ),
        appBar: AppBar(
          title: baseUrl == ""
              ? const Text('Loading')
              : const Text('Live Stream from E3 Camera'),
        ),
        body: Column(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Expanded(
                        child: WebViewWidget(controller: controller),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14.0),
                                side: const BorderSide(color: Colors.blue),
                              ),
                            ),
                            // This saves the images when 'Done' is pressed
                            // Currently just returning paths to caller
                            onPressed: () {
                              Navigator.of(context).pop(
                                  capturedImages.map((e) => e.path).toList());
                            },
                            icon: const Icon(
                              Icons.done,
                              size: 40,
                            ),
                            label: Text(
                              'Save ${capturedImages.length}',
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.center,
                          child: InkWell(
                            onTap: isCapturing
                                ? null
                                : () async {
                                    if (isCapturing) return;
                                    setState(() {
                                      isCapturing = true;
                                    });

                                    try {
                                      final response = await http
                                          .get(Uri.parse('$baseUrl/capture'));

                                      if (response.statusCode == 200 &&
                                          response.headers['content-type']
                                                  ?.contains('image/jpeg') ==
                                              true) {
                                        // Get temporary directory - images will be lost when app closes
                                        final directory =
                                            await getTemporaryDirectory();

                                        // Create unique filename
                                        final imagePath =
                                            '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
                                        final file = File(imagePath);

                                        // Save image to temporary storage
                                        await file
                                            .writeAsBytes(response.bodyBytes);

                                        setState(() {
                                          capturedImages.add(XFile(imagePath));
                                        });

                                        Get.snackbar(
                                          "Success",
                                          "Image captured",
                                          backgroundColor: Colors.green,
                                          colorText: Colors.white,
                                          duration: const Duration(seconds: 2),
                                        );
                                      }
                                    } catch (e) {
                                      Get.snackbar(
                                        "Error",
                                        "Failed to capture image: $e",
                                        backgroundColor: Colors.red,
                                        colorText: Colors.white,
                                        duration: const Duration(seconds: 3),
                                      );
                                    } finally {
                                      setState(() {
                                        isCapturing = false;
                                      });
                                    }
                                  },
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: isCapturing ? Colors.grey : Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: isCapturing
                                    ? const CircularProgressIndicator(
                                        color: Colors.white)
                                    : const Icon(
                                        Icons.camera,
                                        color: Colors.lightBlue,
                                        size: 70,
                                      ),
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: SizedBox(
                            height: 100,
                            child: ListView.builder(
                              shrinkWrap: true,
                              scrollDirection: Axis.horizontal,
                              itemCount: capturedImages.length,
                              itemBuilder: (BuildContext context, int index) {
                                return horizontalScrollChildren(context, index);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void refresh() {
    controller.reload();
  }

  Widget horizontalScrollChildren(BuildContext context, int index) {
    return SizedBox(
        width: 100,
        height: 100,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              Container(
                decoration: const BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.all(Radius.circular(8.0)),
                    boxShadow: [
                      BoxShadow(blurRadius: 1.0, color: Colors.blue)
                    ]),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: networkImage(capturedImages[index].path),
                ),
              ),
              Positioned(
                top: 0,
                width: 30,
                height: 20,
                child: Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: () {
                      if (capturedImages.isNotEmpty) {
                        // Delete file from storage when removed from list
                        File(capturedImages[index].path).deleteSync();
                        setState(() {
                          capturedImages.removeAt(index);
                        });
                      }
                    },
                    icon: const Icon(Icons.delete_forever,
                        size: 20, color: Colors.blueAccent),
                  ),
                ),
              ),
            ],
          ),
        ));
  }
}
