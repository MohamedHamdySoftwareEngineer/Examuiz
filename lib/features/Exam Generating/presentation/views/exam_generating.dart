import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
// import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:html_to_pdf/html_to_pdf.dart';
import '../../../../core/utils/constants.dart';
import '../../../../core/widgets/my_app_bar.dart';

class ExamGenerating extends StatefulWidget {
  const ExamGenerating({super.key});

  @override
  State<ExamGenerating> createState() => _ExamGeneratingState();
}

class _ExamGeneratingState extends State<ExamGenerating> {
  PlatformFile? selectedFile;
  bool isUploading = false;
  String? fileName;
  String? errorDetails;

  /// Inserts a CSS style block into the HTML that adds margins and forces the answers
  /// section (marked with <section class='answers'>) to start on a new page.
  String _injectStyles(String htmlContent) {
    const String styleBlock = '''
<style>
  /* Set the PDF page margins for top, right, bottom, and left */
  @page {
    margin: 50px 60px;
  }
  /* Reset any default body margin so the page margins take full effect */
  body {
    margin: 0;
  }
  /* Force a page break before each element with the "answers" class */
  .answers {
    page-break-before: always;
  }
</style>
''';

    // If the HTML contains a <head>, inject the styles there. Otherwise, prepend them.
    if (htmlContent.contains("<head>")) {
      return htmlContent.replaceFirst("<head>", "<head>$styleBlock");
    } else {
      return "$styleBlock$htmlContent";
    }
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
                            //  the map function is taking each difficulty level from your list and turning it into a selectable option in your dropdown menu.
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
                        content: Text('Number of Questions must be positive')),
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

      // log the file name and parameters to the console
      debugPrint('Uploading file: ${selectedFile!.name}');
      debugPrint('Number of Questions: $numberOfQuestions');
      debugPrint('From Page: $fromPage, To Page: $toPage');
      debugPrint('Question Types: $questionTypes');
      debugPrint('Difficulty: $difficulty');

      String apiUrl = 'https://192.168.1.8:7053/api/exam/create';
      final queryParams = {
        'NumberOfQuestions': numberOfQuestions.toString(),
        'FromPage': fromPage.toString(),
        'ToPage': toPage.toString(),
        'QuestionTypes': questionTypes,
        'Difficulty': difficulty,
      };

      // we will replace that https://192.168.1.6:7053/api/exam/create with that https://192.168.1.6:7053/api/exam/create?NumberOfQuestions=10&FromPage=1&ToPage=10&QuestionTypes=MCQ&Difficulty=Medium
      var uri = Uri.parse(apiUrl).replace(queryParameters: queryParams);
      debugPrint('Request URL: ${uri.toString()}');

      // A MultipartRequest is designed for situations where you need to upload multiple pieces of data at once—such as a file along with additional form fields. This makes it ideal for sending both your PDF file and the exam parameters in a single HTTP request.
      var request = http.MultipartRequest('POST', uri);
      request.headers['Content-Type'] = 'multipart/form-data';

      // Using these two conditions ensures that your code can handle file uploads regardless of whether the file is available as a file path or only as raw bytes (doens't have a path because it stored in memory).
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
        const Duration(minutes: 2),
        onTimeout: () {
          throw TimeoutException(
              'Connection timed out. Ensure the server is running and accessible.');
        },
      );
      var response = await http.Response.fromStream(streamedResponse);

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response headers: ${response.headers}');

      // Handle Successful Response
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Success (Status Code 200-299):
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
  void _showDownloadDialog(Uint8List htmlBytes) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Exam Generated'),
          content: const Text(
              'Your exam has been generated successfully.\nWould you like to open the generated PDF file?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                String htmlContent = utf8.decode(htmlBytes);
                // Inject our CSS for margins and page break.
                String modifiedHtml = _injectStyles(htmlContent);
                Directory tempDir = await getTemporaryDirectory();
                File pdfFile = await HtmlToPdf.convertFromHtmlContent(
                  htmlContent: modifiedHtml,
                  printPdfConfiguration: PrintPdfConfiguration(
                    targetDirectory: tempDir.path,
                    targetName: "exam_pdf_${DateTime.now()}",
                    printSize: PrintSize.A4,
                    printOrientation: PrintOrientation.Portrait,
                    linksClickable: false,
                  ),
                );
                Navigator.of(context).pop(); // Close dialog

                await OpenFilex.open(pdfFile.path);
              },
              child: const Text('Open'),
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
                const Text(
                    '• Check that the PDF file is valid and not corrupted'),
                const Text(
                    '• Verify that From Page and To Page values are valid for the document'),
                const Text(
                    '• Make sure the number of questions is reasonable for the content'),
                const Text(
                    '• Confirm that the API server is running correctly'),
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

  Widget _buildSelectFileButton() {
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
                colors: [firstGradientColor, secondGradientColor],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: firstGradientColor.withOpacity(0.3),
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
        if (errorDetails != null && errorDetails!.isNotEmpty) handleError(),
      ],
    );
  }

  Widget handleError() {
    return Padding(
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
    );
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
          // Use our own button widget
          _buildSelectFileButton(),
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
            colors: [firstGradientColor, secondGradientColor],
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
