import 'package:flutter/material.dart';
import 'package:point/Services/FunHelper.dart';

/// Point OS snackbars: solid green/red so they read clearly on dark theme.
class OsSnackbar {
  OsSnackbar._();

  static void success(String title, String message) {
    FunHelper.showSnackbar(
      title,
      message,
      backgroundColor: const Color(0xFF15803D),
      colorText: Colors.white,
    );
  }

  static void error(String title, String message) {
    FunHelper.showSnackbar(
      title,
      message,
      backgroundColor: const Color(0xFFB91C1C),
      colorText: Colors.white,
    );
  }
}
