import 'package:flutter/material.dart';

void showCustomSnackbar(BuildContext context, String message, {Color? backgroundColor}) {
  backgroundColor ??= Theme.of(context).colorScheme.primary;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
      backgroundColor: backgroundColor,
      duration: Duration(seconds: 3),
      behavior: SnackBarBehavior.floating, 
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),
  );
}