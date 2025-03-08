import 'dart:io';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PDFViewerPage extends StatefulWidget {
  final String pdfPath;
  const PDFViewerPage(this.pdfPath, {super.key});

  @override
  State<PDFViewerPage> createState() => _PDFViewerPageState();
}

class _PDFViewerPageState extends State<PDFViewerPage> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Project Report')),
      body: SfPdfViewer.file(File(widget.pdfPath)),
      key: _pdfViewerKey,
    );
  }
}
