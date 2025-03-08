import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

//import 'package:flutter_html/flutter_html.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class HTMLViewerPage extends StatefulWidget {
  final String htmlText;
  final String projectType;
  final String filePath;
  const HTMLViewerPage(this.htmlText, this.projectType, this.filePath,
      {super.key});

  @override
  State<HTMLViewerPage> createState() => _HTMLViewerPageState();
}

class _HTMLViewerPageState extends State<HTMLViewerPage> {
  late String projectType;
  late String htmlText;
  late WebViewController _webViewController;
  late String filePath;
  int downloadPerc = 0;
  bool isLoading = true;
  @override
  void initState() {
    super.initState();
    projectType = widget.projectType;
    htmlText = widget.htmlText;
    filePath = widget.filePath;
    // #docregion platform_features
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);
    // #enddocregion platform_features

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              if (progress == 100) {
                isLoading = false;
              }
              downloadPerc = progress;
            });
          },
          // onPageStarted: (String url) {
          //   debugPrint('Page started loading: $url');
          // },
          onPageFinished: (String url) {},
          onWebResourceError: (WebResourceError error) {
            debugPrint('''
Page resource error:
  code: ${error.errorCode}
  description: ${error.description}
  errorType: ${error.errorType}
  isForMainFrame: ${error.isForMainFrame}
          ''');
          },
        ),
      )
      ..addJavaScriptChannel(
        'Toaster',
        onMessageReceived: (JavaScriptMessage message) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message.message)),
          );
        },
      );
    // ..loadRequest(Uri.parse('https://flutter.dev'));

    // #docregion platform_features
    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
    // #enddocregion platform_features

    _webViewController = controller;

    _webViewController.loadHtmlString(htmlText);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Project $projectType Report'),
        ),
        floatingActionButton: PopupMenuButton(
          child: const Chip(
            avatar: Icon(
              Icons.save_as,
              color: Colors.blue,
            ),
            labelPadding: EdgeInsets.all(8),
            label: Text(
              'Save As',
              style: TextStyle(color: Colors.blue, fontSize: 15),
            ),
            shadowColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            elevation: 10,
            autofocus: true,
          ),
          onSelected: (value) {
            _onMenuItemSelected(value as int);
          },
          itemBuilder: (ctx) => [
            _buildPopupMenuItem('PDF', Icons.picture_as_pdf_outlined, 1),
            _buildPopupMenuItem('DOCX', Icons.document_scanner_outlined, 2),
          ],
        ),
        body: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                backgroundColor: Colors.blue,
                color: Colors.green,
                //valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              ))
            : WebViewWidget(controller: _webViewController));
  }

  _onMenuItemSelected(int value) async {
    if (value == 1) {
      //var savedPath = filePath.replaceAll('.html', '.pdf');
      await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => await Printing.convertHtml(
                format: format,
                html: htmlText,
              ));
      if (!mounted) {
        return;
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('DOCX under development.')));
    }
  }

  PopupMenuItem _buildPopupMenuItem(
      String title, IconData iconData, int position) {
    return PopupMenuItem(
      value: position,
      child: Row(
        children: [
          Icon(
            iconData,
            color: Colors.blue,
          ),
          const SizedBox(
            width: 15,
          ),
          Text(title),
        ],
      ),
    );
  }
}
