import 'dart:io';
import 'dart:typed_data';
import 'package:examuiz/features/Exam%20Generating/presentation/views/widgets/select_file_button.dart';
import 'package:flutter/material.dart';
import 'package:html_to_pdf/html_to_pdf.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../constants.dart';
import '../../../../core/widgets/my_app_bar.dart';
import 'package:open_filex/open_filex.dart';

class ExamGenerating extends StatelessWidget {
  const ExamGenerating({super.key});

  /// Inserts a CSS style block into the HTML that adds margins and forces the answers
  /// section (marked with <section class='answers'>) to start on a new page.
  String _injectStyles(String htmlContent) {
    const String styleBlock =
        "<style> body { margin: 20px; } .answers { page-break-before: always; } </style>";
    if (htmlContent.contains("<head>")) {
      return htmlContent.replaceFirst("<head>", "<head>$styleBlock");
    } else {
      return "$styleBlock$htmlContent";
    }
  }

  /// Converts an HTML string to a PDF file.
  /// The HTML is modified so that the answers section appears on its own page and the page margins are set.
  Future<File> _convertHtmlToPdf(String htmlContent) async {
    String modifiedHtml = _injectStyles(htmlContent);
    Directory tempDir = await getTemporaryDirectory();
    File generatedPdfFile = await HtmlToPdf.convertFromHtmlContent(
      htmlContent: modifiedHtml,
      printPdfConfiguration: PrintPdfConfiguration(
        targetDirectory: tempDir.path,
        targetName: "exam_pdf_${DateTime.now().millisecondsSinceEpoch}",
        printSize: PrintSize.A4,
        printOrientation: PrintOrientation.Portrait,
        linksClickable: false,
      ),
    );
    return generatedPdfFile;
  }

  Widget _buildUploadContainer(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [firstGradientColor, secondGradientColor],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: firstGradientColor.withOpacity(0.2),
                  blurRadius: 15,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.upload_file_rounded,
              size: 60,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 25),
          const Text(
            'Upload your Document',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 15),
          Text(
            'Select your PDF file to generate exam questions',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 25),
          // File type indicator.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.picture_as_pdf, size: 18, color: Colors.grey[700]),
                const SizedBox(width: 8),
                Text(
                  'PDF',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          // Pass a callback to the SelectFileButton to handle HTML conversion.
          SelectFileButton(
            onHtmlReceived: (Uint8List htmlBytes) async {
              String htmlContent = String.fromCharCodes(htmlBytes);
              File pdfFile = await _convertHtmlToPdf(htmlContent);
              await OpenFilex.open(pdfFile.path);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const MyAppBar(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6448FE), Color(0xFF5FC6FF)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Spacer(flex: 1),
                          _buildUploadContainer(context),
                          const Spacer(flex: 1),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
