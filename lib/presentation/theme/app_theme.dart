import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: Colors.blueGrey.shade800,
    scaffoldBackgroundColor: Colors.grey.shade900,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.blueGrey.shade900,
      elevation: 2,
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),
    cardColor: Colors.grey.shade800,
    buttonTheme: ButtonThemeData(
      buttonColor: Colors.blueAccent.shade700,
      textTheme: ButtonTextTheme.primary,
    ),
    colorScheme: ColorScheme.dark(
      primary: Colors.blueAccent.shade400,
      secondary: Colors.greenAccent.shade400,
      background: Colors.grey.shade900,
      surface: Colors.grey.shade800, // Для карточек
    ),
  );
}