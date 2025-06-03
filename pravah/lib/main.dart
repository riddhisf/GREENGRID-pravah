import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:pravah/pages/home_page.dart';
import 'package:pravah/pages/location_page.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

// Import your WeatherProvider
import 'package:pravah/providers/weather_provider.dart'; // You might need to create this file

String globalCarbonFootprint = '0.0';
String globaldailySolar = '0.0';
String globaldailyWind = '0.0';
String globaldailyBiomass = '0.0';
String globaldailyGeothermal = '0.0';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load .env file
  await dotenv.load(fileName: ".env");
  print('.env file loaded successfully');

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully');
    print('API Key: ${dotenv.env['API_KEY']}'); // Print the API key
  } catch (e) {
    print('Error initializing Firebase: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => WeatherProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color.fromARGB(255, 0, 48, 72),
            secondary: Color.fromARGB(255, 16, 197, 88),
            surface: Color.fromARGB(255, 2, 37, 55),
            onPrimary: Color.fromARGB(255, 250, 249, 233),
            onSecondary: Color.fromARGB(255, 250, 249, 233),
            onSurface: Color.fromARGB(255, 250, 249, 233),
          ),
          scaffoldBackgroundColor: const Color.fromARGB(255, 0, 48, 72),
          textTheme: GoogleFonts.montserratTextTheme().apply(
            bodyColor: Colors.white,
            displayColor: Colors.white70,
          ),
        ),
        home: HomePage(),
      ),
    );
  }
}