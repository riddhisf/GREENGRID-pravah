import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pravah/pages/home_page.dart';
import 'package:pravah/pages/profile_page.dart';
import 'package:provider/provider.dart';
import 'package:pravah/providers/weather_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Helper functions for user preferences
Future<void> _saveUserPreferencesLocally({
  double? lat,
  double? lng,
  String? name,
  double? windEfficiency,
  double? bladeLength,
  double? solarPanelEfficiency,
  double? solarPanelArea,
}) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();

  // Save location data if provided
  if (lat != null) await prefs.setDouble('selected_lat', lat);
  if (lng != null) await prefs.setDouble('selected_lng', lng);
  if (name != null) await prefs.setString('selected_name', name);

  // Save power parameters if provided
  if (windEfficiency != null) await prefs.setDouble('wind_efficiency', windEfficiency);
  if (bladeLength != null) await prefs.setDouble('blade_length', bladeLength);
  if (solarPanelEfficiency != null) await prefs.setDouble('solar_panel_efficiency', solarPanelEfficiency);
  if (solarPanelArea != null) await prefs.setDouble('solar_panel_area', solarPanelArea);

  // Save timestamp of last update
  await prefs.setInt('last_updated', DateTime.now().millisecondsSinceEpoch);
}


class SolarPanelSetupPage extends StatefulWidget {
  const SolarPanelSetupPage({super.key});

  @override
  State<SolarPanelSetupPage> createState() => _SolarPanelSetupPageState();
}

class _SolarPanelSetupPageState extends State<SolarPanelSetupPage> {
  // Controllers for solar parameters
  final TextEditingController _solarPanelEfficiencyController = TextEditingController(text: "20.0");
  final TextEditingController _solarPanelAreaController = TextEditingController(text: "100.0");

  String username = "Guest User";
  String email = "Not logged in";
  bool isUserLoggedIn = false;
  bool isLoading = true;
  bool isPredicting = false;
  Map<String, dynamic>? _dailyPrediction;
  String? _predictionError;

  // Add missing variables for location
  LatLng? coordinates;
  String selectedLocation = "New Delhi"; // Default location

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _loadSolarPanelData();
    _fetchWeatherData();
    _restoreSelectedLocation();
  }

  Future<void> _getPredictionFromGemini(Map<String, dynamic>? weatherData) async {
    if (weatherData == null) {
      setState(() {
        _predictionError = "Weather data not available for AI prediction";
        isPredicting = false;
      });
      return;
    }

    setState(() {
      isPredicting = true;
      _dailyPrediction = null;
      _predictionError = null;
    });

    try {
      // Get API key from environment variables
      final geminiApiKey = dotenv.env['AI_API_KEY'];
      if (geminiApiKey == null || geminiApiKey.isEmpty) {
        throw Exception("Gemini API key not found in environment variables");
      }

      // Extract relevant parameters with careful null checking
      final efficiency = double.tryParse(_solarPanelEfficiencyController.text) ?? 20.0;
      final area = double.tryParse(_solarPanelAreaController.text) ?? 100.0;

      final cloudCover = weatherData['clouds']?['all']?.toDouble() ?? 0.0;
      final temperature = weatherData['main']?['temp']?.toDouble() ?? 20.0;
      final location = weatherData['name'] ?? "Unknown location";

      final weatherList = weatherData['weather'];
      final weatherCondition = weatherList != null && weatherList is List && weatherList.isNotEmpty
          ? weatherList[0]['main'] ?? "Unknown weather"
          : "Unknown weather";

      final lat = weatherData['coord']?['lat'] ?? 0.0;
      final lng = weatherData['coord']?['lon'] ?? 0.0;

      // Format current date
      final now = DateTime.now();
      final String formattedDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      // UPDATED: Construct a prompt that will generate JSON matching your UI expectations
      final prompt = """
You are a solar power prediction expert. Based on these parameters, predict the hourly solar power generation for today.
Format your response as a JSON object that matches the structure below.

Parameters:
- Solar panel efficiency: $efficiency%
- Solar panel area: $area square meters
- Location: $location (Lat: $lat, Lng: $lng)
- Current weather: $weatherCondition
- Cloud cover: $cloudCover%
- Temperature: $temperature°C
- Current date: $formattedDate

IMPORTANT: Your prediction should directly account for these specific factors:
1. Panel efficiency ($efficiency%) - higher efficiency means more power per unit of solar radiation
2. Panel area ($area sq meters) - power output scales linearly with panel area
3. Temperature ($temperature°C) - account for temperature coefficient where efficiency decreases by ~0.4% per degree above 25°C
4. Cloud cover ($cloudCover%) - reduces direct sunlight proportionally
5. Local solar irradiance based on location, date and time of day

Respond with a JSON object with this structure:
{
  "date": "$formattedDate",
  "summary": {
    "total_kwh": 42.3,
    "peak_hour": "12:00",
    "peak_kw": 7.8,
    "weather_impact": "Moderate cloud cover reduces efficiency by approximately 25%, temperature of $temperature°C affects panel efficiency by approximately X%"
  },
  "hourly": [
    {
      "hour": "06:00",
      "power_kw": 0.2
    },
    {
      "hour": "07:00",
      "power_kw": 1.1
    },
    // remaining hours...
  ]
}

Use this formula for calculating power: Power (kW) = Solar Irradiance (kW/m²) × Panel Area (m²) × Efficiency (%) × [1 - 0.004 × (Temperature - 25°C)] × [1 - (Cloud Cover % × 0.7)/100]

Generate realistic predictions considering all parameter impacts, and typical daily solar irradiance curves for this location and time of year.
Only return the JSON structure with no additional text.
""";

      // Using the correct endpoint from your working example
      final Uri url = Uri.parse(
          "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent?key=$geminiApiKey"
      );

      // Construct the request body as in your working example
      Map<String, dynamic> requestBody = {
        "contents": [
          {
            "role": "user",
            "parts": [
              {
                "text": prompt
              }
            ]
          }
        ]
      };

      // Make the API call
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      // Print status code for debugging
      print("API response status code: ${response.statusCode}");

      if (response.statusCode != 200) {
        print("Error response body: ${response.body}");
        throw Exception("API error: ${response.statusCode}");
      }

      // Parse the response
      final jsonResponse = jsonDecode(response.body);

      // Extract the text from the response following your working example's structure
      final textResponse = jsonResponse["candidates"]?[0]["content"]?["parts"]?[0]["text"] ?? "No content generated.";

      print("Raw text response: $textResponse");

      // Clean up the JSON string if needed (removing markdown code blocks)
      String jsonString = textResponse;
      if (textResponse.contains('```json')) {
        jsonString = textResponse.split('```json')[1].split('```')[0].trim();
      } else if (textResponse.contains('```')) {
        jsonString = textResponse.split('```')[1].split('```')[0].trim();
      }

      // Parse the JSON
      final predictionData = jsonDecode(jsonString);

      // Validate that the structure matches what we need
      if (!predictionData.containsKey('summary') || !predictionData.containsKey('hourly')) {
        throw Exception("The API response doesn't have the expected JSON structure");
      }

      setState(() {
        _dailyPrediction = predictionData;
        isPredicting = false;
      });

      print("Successfully received prediction from Gemini API!");

    } catch (e) {
      print("Error getting predictions from Gemini: $e");
      setState(() {
        _predictionError = "Failed to get AI predictions: ${e.toString()}";
        isPredicting = false;
      });
    }
  }


  Future<void> _restoreSelectedLocation() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    double? lat = prefs.getDouble('selected_lat');
    double? lng = prefs.getDouble('selected_lng');
    String? name = prefs.getString('selected_name');

    if (lat != null && lng != null && name != null) {
      setState(() {
        coordinates = LatLng(lat, lng);
        selectedLocation = name;
      });

      // Use mounted check before accessing context
      if (mounted) {
        // Fetch weather data using the saved coordinates
        Provider.of<WeatherProvider>(context, listen: false)
            .fetchWeatherDataByCoordinates(lat, lng);
      }
    } else {
      // Default to the last known location or manually set location
      if (mounted) {
        Provider.of<WeatherProvider>(context, listen: false)
            .fetchWeatherDataByCity(selectedLocation);
      }
    }
  }


  // Fetch weather data using the provided WeatherProvider
  Future<void> _fetchWeatherData() async {
    try {
      if (mounted) {
        final weatherProvider = Provider.of<WeatherProvider>(context, listen: false);
        // This method doesn't do anything - you probably want to actually fetch data here
        // For example:
        if (coordinates != null) {
          weatherProvider.fetchWeatherDataByCoordinates(coordinates!.latitude, coordinates!.longitude);
        } else {
          weatherProvider.fetchWeatherDataByCity(selectedLocation);
        }
      }
    } catch (e) {
      print("Error fetching weather data: $e");
    }
  }

  // Check if user is logged in
  void _checkLoginStatus() {
    User? user = FirebaseAuth.instance.currentUser;
    setState(() {
      isUserLoggedIn = user != null;
      if (isUserLoggedIn && user != null) {
        email = user.email ?? "Email not available";
      }
    });
  }

  // Load solar panel data from Firestore (if logged in) or SharedPreferences
  Future<void> _loadSolarPanelData() async {
    setState(() {
      isLoading = true;
    });

    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // User is logged in, load from Firestore
      await _loadDataFromFirestore(user);
    } else {
      // User is not logged in, load from SharedPreferences
      await _loadDataFromLocalStorage();
    }

    setState(() {
      isLoading = false;
    });
  }

  // Load data from Firestore
  Future<void> _loadDataFromFirestore(User user) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        setState(() {
          username = userDoc.get('username') ?? "Username not set";
        });

        // Load solar panel parameters
        if (userDoc.data() != null && userDoc.data() is Map) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

          if (userData.containsKey('solarPanelEfficiency')) {
            _solarPanelEfficiencyController.text = userData['solarPanelEfficiency'].toString();
          }

          if (userData.containsKey('solarPanelArea')) {
            _solarPanelAreaController.text = userData['solarPanelArea'].toString();
          }
        }
      }
    } catch (e) {
      print("Error loading user data from Firestore: $e");
    }
  }

  // Load data from SharedPreferences
  Future<void> _loadDataFromLocalStorage() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Load solar parameters with default values if not found
      double? solarEfficiency = prefs.getDouble('solar_panel_efficiency');
      if (solarEfficiency != null) {
        _solarPanelEfficiencyController.text = solarEfficiency.toString();
      }

      double? solarArea = prefs.getDouble('solar_panel_area');
      if (solarArea != null) {
        _solarPanelAreaController.text = solarArea.toString();
      }

      print("Loaded solar panel data from local storage");
    } catch (e) {
      print("Error loading data from SharedPreferences: $e");
    }
  }

  // Save all parameters to both Firestore (if logged in) and SharedPreferences
  Future<void> _saveSolarPanelData() async {
    // Save to Firestore if user is logged in
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _saveDataToFirestore(user.uid);
    }

    // Always save to SharedPreferences (for all users, including guests)
    _saveDataToLocalStorage();
  }

  // Save to Firestore
  void _saveDataToFirestore(String userId) {
    try {
      Map<String, dynamic> dataToUpdate = {
        'solarPanelEfficiency': double.tryParse(_solarPanelEfficiencyController.text) ?? 20.0,
        'solarPanelArea': double.tryParse(_solarPanelAreaController.text) ?? 100.0,
        'lastUpdated': DateTime.now(),
      };

      FirebaseFirestore.instance.collection('users')
          .doc(userId)
          .update(dataToUpdate);
      print("Solar panel data saved to Firestore");
    } catch (e) {
      print('Error saving solar panel data to Firestore: $e');
    }
  }

  // Save to SharedPreferences
  Future<void> _saveDataToLocalStorage() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Save core parameters used across pages
      double? solarEfficiency = double.tryParse(_solarPanelEfficiencyController.text);
      if (solarEfficiency != null) {
        await prefs.setDouble('solar_panel_efficiency', solarEfficiency);
      }

      double? solarArea = double.tryParse(_solarPanelAreaController.text);
      if (solarArea != null) {
        await prefs.setDouble('solar_panel_area', solarArea);
      }

      // Save timestamp of last update
      await prefs.setInt('last_updated', DateTime.now().millisecondsSinceEpoch);

      print("Solar panel data saved to local storage");
    } catch (e) {
      print("Error saving data to SharedPreferences: $e");
    }
  }

  // Calculate theoretical power potential using real weather data from provider
  String _calculateSolarPowerPotential(Map<String, dynamic>? weatherData) {
    if (weatherData == null) return "N/A";

    try {
      // This is a simplified model that considers cloud cover and time of day
      double cloudCover = weatherData['clouds']['all'].toDouble(); // %
      double efficiency = double.tryParse(_solarPanelEfficiencyController.text) ?? 20.0; // %
      double area = double.tryParse(_solarPanelAreaController.text) ?? 100.0;

      // Get current temperature
      double temperature = weatherData['main']['temp'].toDouble();

      // Temperature correction factor (simplified - panels are less efficient at higher temps)
      double tempCorrectionFactor = 1.0 - (0.005 * (temperature - 25.0)); // 0.5% reduction per degree above 25°C
      tempCorrectionFactor = tempCorrectionFactor.clamp(0.8, 1.1); // Limit the correction factor

      // Get current time to factor in time of day
      final now = DateTime.now();
      final hour = now.hour;

      // Day/night factor (simplified)
      double timeOfDayFactor = 0.0;
      if (hour >= 6 && hour <= 18) { // Daylight hours (6 AM to 6 PM)
        // Peak at noon (12), decreasing towards morning and evening
        int hourFromNoon = (hour - 12).abs();
        timeOfDayFactor = 1.0 - (hourFromNoon / 8); // Decreases as we move away from noon
        timeOfDayFactor = timeOfDayFactor.clamp(0.2, 1.0);
      }

      // Standard solar irradiance (clear sky) ~= 1000 W/m²
      double irradiance = 1000.0 * timeOfDayFactor * (1.0 - (cloudCover / 100.0) * 0.7) * tempCorrectionFactor;

      // Calculate power
      double power = irradiance * (efficiency / 100.0) * area;

      // Convert to kilowatts
      double powerKW = power / 1000.0;

      return powerKW.toStringAsFixed(2) + " kW";
    } catch (e) {
      print("Error calculating solar power: $e");
      return "Error calculating";
    }
  }

  // Calculate estimated daily solar energy production in kWh
  String _calculateEstimatedDailyOutput(Map<String, dynamic>? weatherData) {
    try {
      double efficiency = double.tryParse(_solarPanelEfficiencyController.text) ?? 20.0; // %
      double area = double.tryParse(_solarPanelAreaController.text) ?? 100.0;

      // Get cloud cover from weather data if available
      double cloudFactor = 1.0;
      if (weatherData != null && weatherData.containsKey('clouds') && weatherData['clouds'].containsKey('all')) {
        double cloudCover = weatherData['clouds']['all'].toDouble();
        cloudFactor = 1.0 - (cloudCover / 100.0) * 0.5; // Less impact on daily average than instantaneous
      }

      // Average solar irradiance (assumed 4.5 kWh/m²/day for a moderate location)
      // Adjust based on current conditions
      double avgSolarIrradiance = 4.5 * cloudFactor; // kWh/m²/day

      // Calculate energy production
      double dailyOutput = avgSolarIrradiance * (efficiency / 100.0) * area;

      return dailyOutput.toStringAsFixed(2) + " kWh";
    } catch (e) {
      print("Error calculating daily output: $e");
      return "Error calculating";
    }
  }

  @override
  void dispose() {
    _solarPanelEfficiencyController.dispose();
    _solarPanelAreaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Get weather data from provider
    final weatherProvider = Provider.of<WeatherProvider>(context);
    final weatherData = weatherProvider.weatherData;
    final isWeatherLoading = weatherProvider.isLoading;
    final weatherError = weatherProvider.errorMessage;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Solar Panel Setup'),
        leading: BackButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomePage()),
            );
          },
        ),
        actions: [

          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => ProfilePage()),
              );
            },
            tooltip: 'Go to Profile',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info card
            _buildUserInfoCard(colorScheme),
            const SizedBox(height: 16),

            // Weather info card
            isWeatherLoading
                ? _buildWeatherLoadingCard(colorScheme)
                : _buildWeatherInfoCard(
                colorScheme,
                weatherData,
                weatherData != null ? weatherData['name'] : null,
                weatherError
            ),
            const SizedBox(height: 16),

            // Core solar parameters card
            _buildCoreSolarParametersCard(),
            const SizedBox(height: 16),

            // Solar power potential card
            _buildSolarPotentialCard(colorScheme, weatherData),
            const SizedBox(height: 16),

            //prediction card
            _buildDailyPredictionCard(colorScheme, weatherData),
            const SizedBox(height: 16),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: colorScheme.secondaryContainer),
                onPressed: () {
                  _saveSolarPanelData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Solar panel settings saved')),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    'Save Settings',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Weather loading card
  Widget _buildWeatherLoadingCard(ColorScheme colorScheme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Loading Weather Data...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            CircularProgressIndicator(
              color: colorScheme.onSecondaryContainer,
            ),
          ],
        ),
      ),
    );
  }

  // Weather info card (updated to handle errors)
  Widget _buildWeatherInfoCard(
      ColorScheme colorScheme,
      Map<String, dynamic>? weatherData,
      String? city,
      String? error
      ) {
    if (error != null) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Weather Data Error',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                error,
                style: TextStyle(
                  color: colorScheme.onErrorContainer,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Solar estimates will use default values',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: colorScheme.onErrorContainer,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (weatherData == null) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              "Weather data not available. Tap refresh to try again.",
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
        ),
      );
    }

    // Extract weather information
    final temperature = weatherData['main']['temp'];
    final weatherCondition = weatherData['weather'][0]['main'];
    final weatherDescription = weatherData['weather'][0]['description'];
    final cloudCover = weatherData['clouds']['all'];

    // Get appropriate weather icon
    IconData weatherIcon = Icons.cloud;
    if (weatherCondition.toString().toLowerCase().contains('clear')) {
      weatherIcon = Icons.wb_sunny;
    } else if (weatherCondition.toString().toLowerCase().contains('rain')) {
      weatherIcon = Icons.water_drop;
    } else if (weatherCondition.toString().toLowerCase().contains('storm')) {
      weatherIcon = Icons.thunderstorm;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cloud,
                  color: colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  'Current Weather Conditions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Icon(
                      weatherIcon,
                      size: 48,
                      color: colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      weatherDescription.toString().toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Temperature: ${temperature.toStringAsFixed(1)}°C',
                      style: TextStyle(
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                    Text(
                      'Cloud Cover: ${cloudCover}%',
                      style: TextStyle(
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                    Text(
                      'Location: ${city ?? "Unknown"}',
                      style: TextStyle(
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // User info card
  Widget _buildUserInfoCard(ColorScheme colorScheme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isUserLoggedIn ? colorScheme.primary : colorScheme.secondary,
                  radius: 24,
                  child: Text(
                    username.isNotEmpty
                        ? username[0].toUpperCase()
                        : "?",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isUserLoggedIn ? colorScheme.onPrimary : colorScheme.onSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                      if (!isUserLoggedIn)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Solar panel settings will be saved locally',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Core solar parameters card
  Widget _buildCoreSolarParametersCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.solar_power,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Solar Panel Parameters',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildParameterInputField(
              'Panel Efficiency (%)',
              _solarPanelEfficiencyController,
              '0-100',
                  (value) {
                double? parsed = double.tryParse(value!);
                if (parsed != null && parsed >= 0 && parsed <= 100) {
                  return null;
                }
                return 'Enter a valid percentage';
              },
            ),
            const SizedBox(height: 12),
            _buildParameterInputField(
              'Panel Area (m²)',
              _solarPanelAreaController,
              '1-1000',
                  (value) {
                double? parsed = double.tryParse(value!);
                if (parsed != null && parsed > 0 && parsed <= 1000) {
                  return null;
                }
                return 'Enter a valid area';
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // Solar power potential card (updated to use real weather data)
  Widget _buildSolarPotentialCard(ColorScheme colorScheme, Map<String, dynamic>? weatherData) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.insights,
                  color: colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  'Solar Production Estimates',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildEstimateInfoColumn(
                  Icons.power,
                  'Current Potential',
                  _calculateSolarPowerPotential(weatherData),
                  colorScheme,
                ),
                _buildEstimateInfoColumn(
                  Icons.wb_sunny,
                  'Theoretical Output',
                  _calculateEstimatedDailyOutput(weatherData),
                  colorScheme,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Note: Estimates are based on current weather conditions, average solar radiation, and may vary based on seasonal changes and your location.',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onPrimaryContainer,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyPredictionCard(ColorScheme colorScheme, Map<String, dynamic>? weatherData) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.insights,
                      color: colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AI Solar Power Forecast',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
                if (!isPredicting && _dailyPrediction == null && _predictionError == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: ElevatedButton(
                      onPressed: () => _getPredictionFromGemini(weatherData),
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.all(colorScheme.primary),
                        foregroundColor: MaterialStateProperty.all(Colors.white), // For better visibility
                        padding: MaterialStateProperty.all(const EdgeInsets.symmetric(horizontal: 12.0)),
                        shape: MaterialStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                      ),
                      child: const Text(
                        "Generate",
                        style: TextStyle(color: Colors.white,fontSize: 10),
                      ),
                    ),
                  ),
                if (_dailyPrediction != null)
                  IconButton(
                    icon: Icon(Icons.refresh),
                    onPressed: () => _getPredictionFromGemini(weatherData),
                    tooltip: 'Refresh forecast',
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Show loading, error, or prediction results
            if (isPredicting)
              Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      color: colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Getting AI forecast from Gemini...',
                      style: TextStyle(
                        color: colorScheme.onSecondaryContainer,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              )
            else if (_predictionError != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Error: $_predictionError',
                      style: TextStyle(
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _getPredictionFromGemini(weatherData),
                      child: Text('Try Again'),
                    ),
                  ],
                ),
              )
            else if (_dailyPrediction != null)
                _buildForecastResults(colorScheme)
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorScheme.outline.withOpacity(0.5)),
                  ),
                  child: Center(
                    child: Text(
                      'Get an AI-powered forecast of your solar panel production throughout the day',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildForecastResults(ColorScheme colorScheme) {
    // Extract data from prediction response
    final summary = _dailyPrediction!['summary'];
    final hourlyData = _dailyPrediction!['hourly'] as List;
    final date = _dailyPrediction!['date'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date heading
        Text(
          'Forecast for $date',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSecondaryContainer,
          ),
        ),
        const SizedBox(height: 12),

        // Summary section
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.secondary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSummaryItem(
                    'Total Production',
                    '${summary['total_kwh']} kWh',
                    Icons.battery_charging_full,
                    colorScheme,
                  ),
                  _buildSummaryItem(
                    'Peak Production',
                    '${summary['peak_kw']} kW',
                    Icons.trending_up,
                    colorScheme,
                  ),
                  _buildSummaryItem(
                    'Best at',
                    summary['peak_hour'],
                    Icons.access_time,
                    colorScheme,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Hourly forecast
        Text(
          'Hourly Forecast',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSecondaryContainer,
          ),
        ),
        const SizedBox(height: 8),

        // Hourly chart
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: hourlyData.length,
            itemBuilder: (context, index) {
              final hourData = hourlyData[index];
              final hour = hourData['hour'];
              final powerKw = hourData['power_kw'];
              final barHeight = (powerKw / summary['peak_kw']) * 120;

              return Container(
                width: 60,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    Text(
                      hour,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: barHeight.toDouble(),
                        width: 30,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              colorScheme.primary.withOpacity(0.7),
                              colorScheme.primary,
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${powerKw.toStringAsFixed(1)} kW',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 8),

        // Weather impact
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            summary['weather_impact'],
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, ColorScheme colorScheme) {
    return Column(
      children: [
        Icon(
          icon,
          color: colorScheme.secondary,
          size: 22,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: colorScheme.onSecondaryContainer,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.onSecondaryContainer.withOpacity(0.7),
          ),
        ),
      ],
    );
  }



  Widget _buildEstimateInfoColumn(IconData icon, String label, String value, ColorScheme colorScheme) {
    return Expanded(
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: colorScheme.primary,
            child: Icon(
              icon,
              color: colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParameterInputField(
      String label,
      TextEditingController controller,
      String hint,
      String? Function(String?)? validator, {
        String? tooltip,
      }) {
    Widget field = TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      validator: validator,
      onChanged: (value) {
        // Only trigger validation, don't save on every keystroke
        if (validator != null) {
          validator(value);
        }
      },
    );

    if (tooltip != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          field,
          Padding(
            padding: const EdgeInsets.only(top: 4.0, left: 8.0),
            child: Text(
              tooltip,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      );
    }

    return field;
  }
}