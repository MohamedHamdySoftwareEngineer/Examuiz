import 'package:flutter/material.dart';

class MyAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MyAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      // automaticallyImplyLeading: false, // Add this line to hide the back button
      backgroundColor: Colors.transparent,
      title: const Text(
        'Examuiz',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 24,
          color: Colors.white,
        ),
      ),
      centerTitle: true,
      
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
