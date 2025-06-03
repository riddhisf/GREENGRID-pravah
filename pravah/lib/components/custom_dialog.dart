import 'package:flutter/material.dart';

class CustomDialogBox extends StatelessWidget {
  final String title;
  final String content;
  final String confirmText;
  final VoidCallback onConfirm;

  const CustomDialogBox({
    super.key,
    required this.title,
    required this.content,
    required this.confirmText,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Text(content),
      actions: [
        // Cancel Button
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.onPrimary,
            foregroundColor:
                Theme.of(context).colorScheme.surface, // Text color
          ),
          child: const Text("Cancel"),
        ),

        // Confirm Button
        ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                const Color.fromARGB(255, 57, 2, 2), // Button background color
            foregroundColor:
                Theme.of(context).colorScheme.onPrimary, // Text color
          ),
          child: Text(confirmText),
        ),
      ],
    );
  }
}
