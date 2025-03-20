import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:html_to_pdf/html_to_pdf.dart';

typedef HtmlCallback = Future<void> Function(Uint8List htmlBytes);

class SelectFileButton extends StatefulWidget {
  /// Callback that receives the HTML bytes from the backend.
  final HtmlCallback? onHtmlReceived;
  const SelectFileButton({Key? key, this.onHtmlReceived}) : super(key: key);

  @override
  State<SelectFileButton> createState() => _SelectFileButtonState();
}

class _SelectFileButtonState extends State<SelectFileButton> {
  PlatformFile? selectedFile;
  bool isUploading = false;
  String? fileName;
  String? errorDetails;

  /// Inserts an explicit page-break div before the answers section.
  String _injectPageBreak(String htmlContent) {
    // This inserts a div with a page break before the answers section.
    return htmlContent.replaceAll(
      "<section class='answers'>",
      "<div style='page-break-before: always;'></div><section class='answers'>",
    );
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          selectedFile = result.files.first;
          fileName = result.files.first.name;
          errorDetails = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Selected file: $fileName')),
        );

        // Open dialog to enter exam parameters.
        _showParametersDialog();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting file: $e')),
      );
    }
  }

  void _showParametersDialog() {
    final TextEditingController numberOfQuestionsController =
        TextEditingController(text: '10');
    final TextEditingController fromPageController =
        TextEditingController(text: '1');
    final TextEditingController toPageController =
        TextEditingController(text: '10');

    String selectedQuestionType = 'MCQ';
    String selectedDifficulty = 'Medium';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Exam Parameters'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: numberOfQuestionsController,
                  decoration:
                      const InputDecoration(labelText: 'Number of Questions'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: fromPageController,
                  decoration: const InputDecoration(labelText: 'From Page'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: toPageController,
                  decoration: const InputDecoration(labelText: 'To Page'),
                  keyboardType: TextInputType.number,
                ),
                DropdownButtonFormField<String>(
                  decoration:
                      const InputDecoration(labelText: 'Question Types'),
                  value: selectedQuestionType,
                  items: ['MCQ', 'True/False', 'Essay', 'Mixed']
                      .map((String value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          ))
                      .toList(),
                  onChanged: (newValue) {
                    selectedQuestionType = newValue!;
                  },
                ),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Difficulty'),
                  value: selectedDifficulty,
                  items: ['Easy', 'Medium', 'Hard']
                      .map((String value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          ))
                      .toList(),
                  onChanged: (newValue) {
                    selectedDifficulty = newValue!;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cancel
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                int numberOfQuestions =
                    int.tryParse(numberOfQuestionsController.text) ?? 10;
                int fromPage = int.tryParse(fromPageController.text) ?? 1;
                int toPage = int.tryParse(toPageController.text) ?? 10;

                if (fromPage > toPage) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'From Page must be less than or equal to To Page')),
                  );
                  return;
                }
                if (numberOfQuestions <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Number of Questions must be positive')),
                  );
                  return;
                }

                Navigator.of(context).pop(); // Close dialog

                // Upload file with parameters.
                _uploadFile(
                  numberOfQuestions: numberOfQuestions,
                  fromPage: fromPage,
                  toPage: toPage,
                  questionTypes: selectedQuestionType,
                  difficulty: selectedDifficulty,
                );
              },
              child: const Text('Generate'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _uploadFile({
    required int numberOfQuestions,
    required int fromPage,
    required int toPage,
    required String questionTypes,
    required String difficulty,
  }) async {
    if (selectedFile == null) return;

    try {
      setState(() {
        isUploading = true;
        errorDetails = null;
      });

      debugPrint('Uploading file: ${selectedFile!.name}');
      debugPrint('Number of Questions: $numberOfQuestions');
      debugPrint('From Page: $fromPage, To Page: $toPage');
      debugPrint('Question Types: $questionTypes');
      debugPrint('Difficulty: $difficulty');

      String apiUrl = 'https://192.168.1.6:7053/api/exam/create';
      final queryParams = {
        'NumberOfQuestions': numberOfQuestions.toString(),
        'FromPage': fromPage.toString(),
        'ToPage': toPage.toString(),
        'QuestionTypes': questionTypes,
        'Difficulty': difficulty,
      };

      var uri = Uri.parse(apiUrl).replace(queryParameters: queryParams);
      debugPrint('Request URL: ${uri.toString()}');

      var request = http.MultipartRequest('POST', uri);
      request.headers['Content-Type'] = 'multipart/form-data';

      if (selectedFile!.path != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'ExamTextBook',
          selectedFile!.path!,
          contentType: MediaType('application', 'pdf'),
        ));
      } else if (selectedFile!.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'ExamTextBook',
          selectedFile!.bytes!,
          filename: selectedFile!.name,
          contentType: MediaType('application', 'pdf'),
        ));
      }

      debugPrint('Request fields: ${request.fields}');
      for (var file in request.files) {
        debugPrint('File field: ${file.field}, filename: ${file.filename}');
      }

      var streamedResponse = await request.send().timeout(
        const Duration(minutes: 10),
        onTimeout: () {
          throw TimeoutException(
              'Connection timed out. Ensure the server is running and accessible.');
        },
      );
      var response = await http.Response.fromStream(streamedResponse);

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response headers: ${response.headers}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showDownloadDialog(response.bodyBytes);
      } else {
        debugPrint('Error response: ${response.body}');
        setState(() {
          errorDetails = response.body;
        });
        _showErrorDetails(response.statusCode, response.body);
      }
    } catch (e) {
      debugPrint('Exception: ${e.toString()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          duration: const Duration(seconds: 10),
        ),
      );
    } finally {
      setState(() {
        isUploading = false;
      });
    }
  }

  /// Shows a dialog that converts the returned HTML to PDF and opens it.
  Future<void> _showDownloadDialog(Uint8List htmlBytes) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Exam Generated'),
          content: const Text(
              'Your exam has been generated successfully.\nWould you like to open the generated PDF file?'),
          actions: [
            TextButton(
              onPressed: () async {
                String htmlContent = utf8.decode(htmlBytes);
                // Inject an explicit page-break before the answers section.
                String modifiedHtml = _injectPageBreak(htmlContent);
                Directory tempDir = await getTemporaryDirectory();
                File pdfFile = await HtmlToPdf.convertFromHtmlContent(
                  htmlContent: modifiedHtml,
                  printPdfConfiguration: PrintPdfConfiguration(
                    targetDirectory: tempDir.path,
                    targetName:
                        "exam_pdf_${DateTime.now().millisecondsSinceEpoch}",
                    printSize: PrintSize.A4,
                    printOrientation: PrintOrientation.Portrait,
                    linksClickable: false,
                  ),
                );
                Navigator.of(context).pop(); // Close dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('PDF file saved at ${pdfFile.path}')),
                );
                await OpenFilex.open(pdfFile.path);
                if (widget.onHtmlReceived != null) {
                  await widget.onHtmlReceived!(htmlBytes);
                }
              },
              child: const Text('Open'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDetails(int statusCode, String body) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error Details (Status $statusCode)'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Response body:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(body),
                const SizedBox(height: 16),
                const Text('Possible solutions:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('• Check that the PDF file is valid and not corrupted'),
                const Text(
                    '• Verify that From Page and To Page values are valid for the document'),
                const Text(
                    '• Make sure the number of questions is reasonable for the content'),
                const Text('• Confirm that the API server is running correctly'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: isUploading ? null : _pickFile,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFF6448FE), Color(0xFF5FC6FF)],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6448FE).withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isUploading)
                  const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                else
                  const Icon(
                    Icons.file_upload_outlined,
                    color: Colors.white,
                  ),
                const SizedBox(width: 12),
                Text(
                  isUploading
                      ? 'Generating exam...'
                      : selectedFile != null
                          ? 'Generate exam'
                          : 'Select File',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (errorDetails != null && errorDetails!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Error Details:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    errorDetails!.length > 200
                        ? '${errorDetails!.substring(0, 200)}...'
                        : errorDetails!,
                    style: TextStyle(color: Colors.red.shade800),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        _showErrorDetails(400, errorDetails!);
                      },
                      child: const Text('View Full Details'),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
