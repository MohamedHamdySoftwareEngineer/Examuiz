import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

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

  // Picks an Excel/CSV file
  Future<void> _pickExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _excelPath = result.files.single.path;
      });
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
      // 1. Build the URL with query param "SubjectName"
      final apiUrl = 'https://192.168.1.6:7053/api/exam/analyze';
      final queryParams = {'SubjectName': _subjectNameController.text};
      final uri = Uri.parse(apiUrl).replace(queryParameters: queryParams);

      // 2. Create the MultipartRequest
      final request = http.MultipartRequest('POST', uri);

      // 3. Attach the Excel file under key "StudentsAnswersExcelFile"
      request.files.add(
        await http.MultipartFile.fromPath('StudentsAnswersExcelFile', _excelPath!),
      );

      // 4. Attach the PDF file under key "ExamPDF_File"
      request.files.add(
        await http.MultipartFile.fromPath('ExamPDF_File', _pdfPath!),
      );

      // 5. Send the request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Parse the JSON response
        final backendResponse = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _analysisResults = backendResponse;
          _showResults = true;
        });
      } else {
        // Show error message if the server responds with non-2xx code
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${response.statusCode} ${response.reasonPhrase}\n${response.body}'),
          ),
        );
      }
    } catch (e) {
      // Show any exceptions (e.g. network errors, file I/O issues)
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
      // No AppBar as requested
      body: Container(
        // This ensures the background extends to full screen
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6448FE), Color(0xFF5FC6FF)],
          ),
        ),
        // Use LayoutBuilder to get the constraints of the parent widget
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                // This ensures the content has at least the height of the available space
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        const SizedBox(height: 30),
                        // Expand the content to fill available space
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
          }
        ),
      ),
    );
  }

  Widget _buildInputForm() {
    return Container(
      padding: const EdgeInsets.all(25),
      // This makes the container expand to fill available space
      width: double.infinity,
      // Remove fixed height to allow expansion
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
        // Make the column expand
        mainAxisSize: MainAxisSize.max,
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
              'Upload your exam PDF (ExamPDF_File) and Excel (StudentsAnswersExcelFile) to get analysis',
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
          // Add a spacer to push the button to the bottom when there's extra space
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
                    color: const Color(0xFF6448FE).withOpacity(0.3),
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
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF333333)),
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

  Widget _buildResultsView() {
    if (_analysisResults == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return Container(
      // Make sure results view also stretches to fill height
      width: double.infinity,
      child: Column(
        // Allow column to expand to fill available space
        mainAxisSize: MainAxisSize.max,
        children: [
          _buildResultsHeader(),
          const SizedBox(height: 20),
          
          // Check if 'Subjects' key exists in the results
          if (_analysisResults!.containsKey('Subjects') && 
              _analysisResults!['Subjects'] is Map<String, dynamic>) 
            ...[
              _buildSubjectsCard(),
              const SizedBox(height: 20),
            ],
          
          // Check if 'Suggestions' key exists in the results
          if (_analysisResults!.containsKey('Suggestions') && 
              _analysisResults!['Suggestions'] is List) 
            ...[
              _buildSuggestionsCard(),
              const SizedBox(height: 20),
            ],
          
          // Add a fallback for unexpected data structure
          if (!_analysisResults!.containsKey('Subjects') || 
              !_analysisResults!.containsKey('Suggestions'))
            _buildGenericResultsCard(),
            
          // Add a spacer to push the button to the bottom when there's extra space
          const Spacer(),
          
          // Back button
          GestureDetector(
            onTap: () {
              setState(() {
                _showResults = false;
                _subjectNameController.clear();
                _pdfPath = null;
                _excelPath = null;
                _analysisResults = null;
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

  // New method to display results when the structure is unexpected
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
          // Display other subjects if present
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
}