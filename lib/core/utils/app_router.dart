import 'package:examuiz/splah_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/Choice Screen/choice_screen.dart';
import '../../features/Exam Generating/presentation/views/exam_generating.dart';
import '../../features/Exam Analysis/exam_analysis.dart';

abstract class AppRouter {
  static const rSplashScreen = '/';
  static const rChoiceScreen = '/ChoiceScreen';
  static const rQuizGenerating = '/QuizGenerating';
  static const rQuizMarking = '/QuizMarking';

  static final router = GoRouter(
    routes: [
      _route(rSplashScreen, const SplashScreen()),
      _route(rChoiceScreen, const ChoiceScreen()),
      _route(rQuizGenerating, const ExamGenerating()),
      _route(rQuizMarking, const ExamAnalysis()),
    ],
  );

  static GoRoute _route(String path, Widget screen) {
    return GoRoute(
      path: path,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
      ),
    );
  }
}
