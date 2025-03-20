import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
// Hide the Border class from excel so it doesn't conflict with Flutter's Border.
import 'package:excel/excel.dart' hide Border;
import 'package:pie_chart/pie_chart.dart';

class ExamAnalysis extends StatefulWidget {
  const ExamAnalysis({Key? key}) : super(key: key);

  @override
  State<ExamAnalysis> createState() => _ExamAnalysisState();
}

class _ExamAnalysisState extends State<ExamAnalysis> {
  final TextEditingController _subjectNameController = TextEditingController();

  String? _pdfPath;
  String? _excelPath;
  bool _isLoading = false;
  bool _showResults = false;

  Map<String, dynamic>? _analysisResults;
  // Map to hold the averages for each question
  Map<String, double>? _questionAverages;

  @override
  void dispose() {
    _subjectNameController.dispose();
    super.dispose();
  }

  // Picks a PDF file
  Future<void> _pickPDF() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _pdfPath = result.files.single.path;
      });
    }
  }

  // Picks an Excel/CSV file and calculate averages from it.
  Future<void> _pickExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _excelPath = result.files.single.path;
      });
      // After selecting Excel file, calculate the averages
      _calculateAverages();
    }
  }

  // Reads the Excel file and calculates the average for each question column
  Future<void> _calculateAverages() async {
  if (_excelPath == null) return;

  try {
    // 1. Read the file bytes and decode the Excel file.
    final bytes = File(_excelPath!).readAsBytesSync();
    final excel = Excel.decodeBytes(bytes);

    // 2. Assume data is in the first sheet.
    final sheet = excel.tables[excel.tables.keys.first];
    if (sheet == null) {
      debugPrint("No sheet found in Excel file.");
      return;
    }

    // 3. The first row is the header row.
    // For example: [Student Name, Q1, Q2, Q3, Q4]
    final headerRow = sheet.row(0).map((cell) => cell?.value?.toString() ?? '').toList();
    final totalColumns = headerRow.length;

    debugPrint("Header row: $headerRow");

    // 4. Calculate total number of students.
    // We assume every row after header is one student.
    final totalStudents = sheet.maxRows - 1;
    if (totalStudents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No student data found in Excel file.')),
      );
      return;
    }

    // 5. For each question column (columns 1 to totalColumns-1), calculate the sum.
    // If a cell is missing or non-numeric, treat its value as 0.
    Map<int, double> sumMap = {};
    for (int rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
      final row = sheet.row(rowIndex);
      // Loop for each question column starting at 1 (skipping Student Name)
      for (int colIndex = 1; colIndex < totalColumns; colIndex++) {
        // Get the cell value as a double; if parsing fails, use 0.
        double cellValue = double.tryParse(row[colIndex]?.value?.toString() ?? '0') ?? 0;
        sumMap[colIndex] = (sumMap[colIndex] ?? 0) + cellValue;
      }
    }

    // 6. Compute the average for each question by dividing the sum by totalStudents.
    Map<String, double> averages = {};
    for (int colIndex = 1; colIndex < totalColumns; colIndex++) {
      final columnName = headerRow[colIndex]; // e.g., "Q1", "Q2", etc.
      final total = sumMap[colIndex] ?? 0;
      final average = total / totalStudents;
      averages[columnName] = average;
      debugPrint("Column '$columnName': total = $total, average = $average");
    }

    setState(() {
      _questionAverages = averages;
      debugPrint("_questionAverages: $_questionAverages");
    });

    if (_questionAverages!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No numeric data found in the Excel columns.')),
      );
    }
  } catch (e) {
    debugPrint("Error reading Excel file: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error reading Excel file: $e')),
    );
  }
}

  Future<void> _analyzeExam() async {
    if (_subjectNameController.text.isEmpty || _pdfPath == null || _excelPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in SubjectName and select both PDF & Excel files')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiUrl = 'https://192.168.1.6:7053/api/exam/analyze';
      final queryParams = {'SubjectName': _subjectNameController.text};
      final uri = Uri.parse(apiUrl).replace(queryParameters: queryParams);

      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        await http.MultipartFile.fromPath('StudentsAnswersExcelFile', _excelPath!),
      );
      request.files.add(
        await http.MultipartFile.fromPath('ExamPDF_File', _pdfPath!),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final backendResponse = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _analysisResults = backendResponse;
          // Show the results page
          _showResults = true;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${response.statusCode} ${response.reasonPhrase}\n${response.body}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exception: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6448FE), Color(0xFF5FC6FF)],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        const SizedBox(height: 30),
                        Expanded(
                          child: _showResults ? _buildResultsView() : _buildInputForm(),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // -------------------------
  // 1) The Input Form Screen
  // -------------------------
  Widget _buildInputForm() {
    return Container(
      padding: const EdgeInsets.all(25),
      width: double.infinity,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              'Exam Analysis',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
          ),
          const SizedBox(height: 15),
          Center(
            child: Text(
              'Upload your exam PDF and Excel file to get analysis.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            'Subject Name',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _subjectNameController,
            decoration: InputDecoration(
              hintText: 'Enter subject name',
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 20),
          _buildFileUploadButton(
            label: 'Upload Excel (StudentsAnswersExcelFile)',
            icon: Icons.table_chart,
            fileType: 'Excel',
            onTap: _pickExcel,
            filePath: _excelPath,
          ),
          const SizedBox(height: 20),
          _buildFileUploadButton(
            label: 'Upload PDF (ExamPDF_File)',
            icon: Icons.picture_as_pdf,
            fileType: 'PDF',
            onTap: _pickPDF,
            filePath: _pdfPath,
          ),
          const Spacer(),
          const SizedBox(height: 30),
          GestureDetector(
            onTap: _isLoading ? null : _analyzeExam,
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
                    color: Color(0xFF6448FE).withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.analytics, color: Colors.white),
                          SizedBox(width: 12),
                          Text(
                            'Analyze Exam',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileUploadButton({
    required String label,
    required IconData icon,
    required String fileType,
    required VoidCallback onTap,
    String? filePath,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.grey[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    filePath != null ? filePath.split('/').last : 'Select $fileType File',
                    style: TextStyle(
                      color: filePath != null ? Colors.black87 : Colors.grey[600],
                      fontWeight: FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.upload_file, color: Colors.grey[700]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --------------------------
  // 2) The Results Page Screen
  // --------------------------
  Widget _buildResultsView() {
    if (_analysisResults == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      width: double.infinity,
      child: Column(
        children: [
          // Header
          _buildResultsHeader(),
          const SizedBox(height: 20),

          // -------------------------------
          // Show the Pie Chart AFTER Analyze
          // -------------------------------
          if (_questionAverages != null && _questionAverages!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(20),
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
                children: [
                  const Text(
                    'Average Scores per Question',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 250,
                    child: PieChart(
                      dataMap: _questionAverages!,
                      chartType: ChartType.disc,
                      chartValuesOptions: const ChartValuesOptions(
                        showChartValuesInPercentage: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Check for "Subjects" and "Suggestions" keys in the analysis results
          if (_analysisResults!.containsKey('Subjects') &&
              _analysisResults!['Subjects'] is Map<String, dynamic>)
            ...[
              _buildSubjectsCard(),
              const SizedBox(height: 20),
            ],
          if (_analysisResults!.containsKey('Suggestions') &&
              _analysisResults!['Suggestions'] is List)
            ...[
              _buildSuggestionsCard(),
              const SizedBox(height: 20),
            ],
          if (!_analysisResults!.containsKey('Subjects') ||
              !_analysisResults!.containsKey('Suggestions'))
            _buildGenericResultsCard(),
          const Spacer(),

          // Back / "Analyze Another Exam" button
          GestureDetector(
            onTap: () {
              setState(() {
                _showResults = false;
                _subjectNameController.clear();
                _pdfPath = null;
                _excelPath = null;
                _analysisResults = null;
                _questionAverages = null;
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Colors.grey[400]!, Colors.grey[600]!],
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_back, color: Colors.white),
                  SizedBox(width: 12),
                  Text(
                    'Analyze Another Exam',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------
  // Helper Widgets (Unchanged)
  // --------------------------

  Widget _buildResultsHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.green, Colors.teal],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.2),
                  blurRadius: 15,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.check_circle,
              size: 60,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Analysis Complete',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Subject: ${_subjectNameController.text}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Color(0xFF555555),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Analyzed ${DateTime.now().toString().split(' ')[0]}',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectsCard() {
    final subjects = _analysisResults!['Subjects'] as Map<String, dynamic>;

    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Wrap(
            spacing: 10,
            children: [
              Icon(Icons.subject, color: Color(0xFF6448FE), size: 24),
              Text(
                'Subject Analysis',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (subjects.containsKey('Hardest'))
            _buildSubjectDifficultyCard(
              title: 'Hardest Subject',
              subject: subjects['Hardest'].toString(),
              color: Colors.redAccent,
            ),
          if (subjects.containsKey('Hardest') && subjects.containsKey('Easiest'))
            const SizedBox(height: 15),
          if (subjects.containsKey('Easiest'))
            _buildSubjectDifficultyCard(
              title: 'Easiest Subject',
              subject: subjects['Easiest'].toString(),
              color: Colors.green,
            ),
          ...subjects.entries
              .where((entry) => entry.key != 'Hardest' && entry.key != 'Easiest')
              .map((entry) {
            return Column(
              children: [
                const SizedBox(height: 15),
                _buildSubjectDifficultyCard(
                  title: entry.key,
                  subject: entry.value.toString(),
                  color: Colors.blue,
                ),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSubjectDifficultyCard({
    required String title,
    required String subject,
    required Color color,
  }) {
    IconData iconData;
    if (title.contains('Hardest')) {
      iconData = Icons.trending_up;
    } else if (title.contains('Easiest')) {
      iconData = Icons.trending_down;
    } else {
      iconData = Icons.subject;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              iconData,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subject,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsCard() {
    final suggestions = _analysisResults!['Suggestions'] as List;

    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Wrap(
            spacing: 10,
            children: [
              Icon(Icons.lightbulb_outline, color: Color(0xFF6448FE), size: 24),
              Text(
                'Improvement Suggestions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...suggestions.asMap().entries.map((entry) {
            final index = entry.key;
            final suggestion = entry.value.toString();
            return Column(
              children: [
                if (index > 0) const SizedBox(height: 15),
                _buildSuggestionItem(index + 1, suggestion),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSuggestionItem(int index, String suggestion) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: TextStyle(
                color: Colors.blue[800],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              suggestion,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenericResultsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Wrap(
            spacing: 10,
            children: [
              Icon(Icons.assessment, color: Color(0xFF6448FE), size: 24),
              Text(
                'Analysis Results',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _analysisResults.toString(),
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
