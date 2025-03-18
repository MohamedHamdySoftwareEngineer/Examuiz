import 'package:examuiz/constants.dart';
import 'package:examuiz/core/widgets/my_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/app_router.dart';


class ChoiceScreen extends StatelessWidget {
  const ChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar:  AppBar(
      elevation: 0,
       automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      title:  const Text(
        'Examuiz',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 24,
          color: Colors.white,
        ),
      ),
      centerTitle: true,
      
    ),
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
                    // to distribute content evenly
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          const Spacer(),
                          _buildWelcomeBox(),
                          const Spacer(),
                          _buildQuizOptionsBox(context),
                          const Spacer(),
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

  Widget _buildQuizOptionsBox(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         const Padding(
          padding: EdgeInsets.only(left: 8.0, bottom: 16.0),
          child: Text(
            'Choose an option:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _buildOptionCard(
                context,
                icon: Icons.add_circle_outline,
                title: 'Generate Quiz',
                color: const Color(0xFF5FC6FF),
                onTap: () => GoRouter.of(context).push(AppRouter.rQuizGenerating),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildOptionCard(
                context,
                icon: Icons.check_circle_outline,
                title: 'Mark Quiz',
                color: const Color(0xFF4CD97B),
                onTap: () => GoRouter.of(context).push(AppRouter.rQuizMarking),
              ),
            ),
          ],
        ),
      ],
    );
  }


  Widget _buildOptionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeBox() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.psychology,
              size: 50,
              color: Color(0xFF6448FE),
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'Ready to test your knowledge?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Generate an exam or check the results',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  
}