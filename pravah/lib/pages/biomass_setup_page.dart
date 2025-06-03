import 'package:flutter/material.dart';

class BioMassSetupPage extends StatelessWidget {
  const BioMassSetupPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Define theme colors
    final darkBlue = const Color(0xFF0B2732);
    final cream = const Color(0xFFF5F5DC);

    return Scaffold(
      appBar: AppBar(
        title: Text('Bio Mass Setup'),
        backgroundColor: const Color(0xFFF5F5DC),
        foregroundColor: const Color(0xFF0B2732),
      ),
      backgroundColor: darkBlue, // Set background color for the scaffold
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: darkBlue,
            borderRadius: BorderRadius.circular(15.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10.0,
                spreadRadius: 2.0,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Coming soon icon
              Icon(
                Icons.construction,
                size: 80.0,
                color: Colors.amber[700],
              ),
              const SizedBox(height: 20.0),

              // Coming soon title
              Text(
                'Coming Soon!',
                style: TextStyle(
                  fontSize: 28.0,
                  fontWeight: FontWeight.bold,
                  color: cream,
                ),
              ),
              const SizedBox(height: 16.0),

              // Description message
              Text(
                'We are currently working on the Bio Mass Setup feature. Our team is developing this functionality to help you manage your biomass resources more efficiently.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.0,
                  color: cream,
                ),
              ),
              const SizedBox(height: 30.0),



              // Estimated time
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0),
                decoration: BoxDecoration(
                  color: cream.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30.0),
                  border: Border.all(color: cream.withOpacity(0.3), width: 1),
                ),
                child: Text(
                  'Expected Release: Coming Soon',
                  style: TextStyle(
                    color: cream,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}