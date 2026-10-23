

import 'package:flutter/material.dart';
import 'screens/register_screen.dart';

import 'utils/app_constants.dart';

void main() => runApp(const ClearPassApp());

class ClearPassApp extends StatelessWidget {
  const ClearPassApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '$libraryName Digital Register',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFEDF1FC),
        colorScheme: ColorScheme.fromSeed(seedColor: accent),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.65),
          contentPadding: const EdgeInsets.all(17),
          prefixIconColor: muted,
          hintStyle: const TextStyle(color: muted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFFDDE4F3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: accent, width: 1.5),
          ),
        ),
      ),
      home: const RegisterPage(),
    );
  }
}

