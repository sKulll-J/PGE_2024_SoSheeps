import 'package:flutter/material.dart';
import 'package:path/path.dart';

// Fonction utilitaire pour afficher un SnackBar stylé
void showStylishSnackBar(String message, {Color backgroundColor = Colors.blue}) {
  ScaffoldMessenger.of(context as BuildContext).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ),
  );
}
