import 'package:examuiz/core/widgets/my_app_bar.dart';
import 'package:flutter/material.dart';

import '../../constants.dart';

class ExamMarking extends StatelessWidget {
  const ExamMarking({super.key});

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const SizedBox(height: 30),

                // Marking container
                Container(
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
                              color:  firstGradientColor.withOpacity(0.2),
                              blurRadius: 15,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_circle_outline,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 25),
                      const Text(
                        'Mark Your Quiz',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        'Upload your answers and get them evaluated',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 25),

                      // File types indicator
                      _buildFileTypeChip(Icons.picture_as_pdf, 'PDF'),

                      const SizedBox(height: 30),

                      // Upload answer button
                      GestureDetector(
                        onTap: () {
                          // Answer upload logic
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Upload answers...')),
                          );
                        },
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
                                color: const Color(0xFF6448FE).withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.upload_file,
                                color: Colors.white,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Upload Answers',
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
                ),
                const SizedBox(height: 30),
                 _buildAnalyticsCard(),
                 const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileTypeChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      shadowColor: Colors.purple.withOpacity(0.1),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Performance Overview',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _buildGradeSummary(),
              const SizedBox(height: 12),
              const Text('Grade Distribution',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              SizedBox(
                height: 150,
                child: BarChartWidget(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGradeSummary() {
    return const SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GradeTile(
            subject: 'Limit',
            grade: 85,
            color: Color(0xFF6C5CE7)),
            SizedBox(width: 10,),
          GradeTile(
            subject: 'Functions',
            grade: 90,
            color: Color(0xFF00B894)),
            SizedBox(width: 10,),
          GradeTile(
            subject: 'Integration',
            grade: 78,
            color: Color(0xFFFF7675)),
          
        ],
      ),
    );
  }
}

class GradeTile extends StatelessWidget {
  final String subject;
  final int grade;
  final Color color;

  const GradeTile({
    super.key,
    required this.subject,
    required this.grade,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      constraints:const BoxConstraints(
        minWidth: 80,
        // maxWidth: 120,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Text(subject,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(grade.toString(),
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }
}

class BarChartWidget extends StatelessWidget {
  final List<double> grades = [85, 90, 78, 92, 70];

   BarChartWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double maxHeight = constraints.maxHeight * 0.8;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: grades.asMap().entries.map((entry) {
            final index = entry.key;
            final grade = entry.value;
            final barHeight = (grade / 100) * maxHeight;
            
            return Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 30,
                  height: barHeight,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C5CE7), Color(0xFF8477FF)],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(grade.toInt().toString(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Sub ${index + 1}',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
              ],
            );
          }).toList(),
        );
      },
    );
  }

}
