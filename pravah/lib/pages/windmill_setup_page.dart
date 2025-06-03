import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pravah/pages/home_page.dart';
import 'package:pravah/pages/profile_page.dart';
import 'package:provider/provider.dart';
import 'package:pravah/providers/weather_provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class WindMillSetupPage extends StatefulWidget {
  const WindMillSetupPage({super.key});

  @override
  State<WindMillSetupPage> createState() => _WindMillSetupPageState();
}

class _WindMillSetupPageState extends State<WindMillSetupPage> {
  // Controllers for wind turbine parameters
  final TextEditingController _turbineEfficiencyController = TextEditingController(text: "35.0");
  final TextEditingController _bladeLengthController = TextEditingController(text: "5.0");

  String username = "Guest User";
  String email = "Not logged in";
  bool isUserLoggedIn = false;
  bool isLoading = true;
  Map<String, dynamic>? _dailyWindPrediction;
  Map<String, dynamic>? _windPrediction; // Added missing variable
  String? _windPredictionError;
  bool isWindPredicting = false;

  // Location variables
  LatLng? coordinates;
  String selectedLocation = "New Delhi"; // Default location

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _loadWindTurbineData();
    _fetchWeatherData();
    _restoreSelectedLocation();
  }

  // Added missing method
  Future<void> _getWindPredictionFromModel(Map<String, dynamic>? weatherData) async {
    // This method will call the Gemini API to get predictions
    await _getWindPredictionFromGemini(weatherData);
  }

  // Added missing method
  Widget _buildWindForecastResults(ColorScheme colorScheme) {
    if (_dailyWindPrediction == null) {
      return Center(child: Text("No forecast data available"));
    }

    // Extract data from the prediction
    final summary = _dailyWindPrediction!['summary'];
    final hourlyData = _dailyWindPrediction!['hourly'] as List;
    final totalKwh = summary['total_kwh'];
    final peakHour = summary['peak_hour'];
    final peakKw = summary['peak_kw'];
    final weatherImpact = summary['weather_impact'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary section
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildPredictionInfoItem("Total Production", "$totalKwh kWh", colorScheme),
                  _buildPredictionInfoItem("Peak Production", "$peakKw kW", colorScheme),
                  _buildPredictionInfoItem("Best at", peakHour, colorScheme),
                ],
              ),

            ],
          ),
        ),

        const SizedBox(height: 16),

        // Hourly chart
        Text(
          "Hourly Forecast",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.onTertiaryContainer,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 200,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8)
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: hourlyData.length,
            itemBuilder: (context, index) {
              final hourData = hourlyData[index];
              final hour = hourData['hour'];
              final powerKw = hourData['power_kw'].toDouble();
              final maxPower = hourlyData.fold(0.0, (max, item) =>
              item['power_kw'].toDouble() > max ? item['power_kw'].toDouble() : max);

              return Container(
                width: 60,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      "${powerKw.toStringAsFixed(1)}",
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 20,
                      height: 120 * (powerKw / maxPower) as double,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hour,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
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
        )
      ],
    );
  }

  Future<Map<String, dynamic>?> generateWindPowerPrediction({
    required BuildContext context,
    required Map<String, dynamic>? weatherData,
  }) async {
    // Check if we already have a prediction in memory
    if (_dailyWindPrediction != null) {
      return _dailyWindPrediction;
    }

    // Check if we have a cached prediction in SharedPreferences
    try {
      final today = DateTime.now();
      final formattedDate = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
      final location = weatherData?['name'] ?? "Unknown";

      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? cachedPrediction = prefs.getString('wind_prediction_${formattedDate}_$location');

      if (cachedPrediction != null) {
        Map<String, dynamic> predictionData = jsonDecode(cachedPrediction);
        _dailyWindPrediction = predictionData;
        return predictionData;
      }
    } catch (e) {
      print("Error checking cached prediction: $e");
    }

    // No cached prediction, generate a new one
    await _getWindPredictionFromGemini(weatherData);
    return _dailyWindPrediction;
  }


  Future<void> _getWindPredictionFromGemini(Map<String, dynamic>? weatherData) async {
    if (weatherData == null) {
      setState(() {
        _windPredictionError = "Weather data not available for AI prediction";
        isWindPredicting = false;
      });
      return;
    }

    setState(() {
      isWindPredicting = true;
      _dailyWindPrediction = null;
      _windPrediction = null; // Reset the _windPrediction variable
      _windPredictionError = null;
    });

    try {
      // Get API key from environment variables
      final geminiApiKey = dotenv.env['AI_API_KEY'];
      if (geminiApiKey == null || geminiApiKey.isEmpty) {
        throw Exception("Gemini API key not found in environment variables");
      }

      // Extract relevant parameters with careful null checking
      final efficiency = double.tryParse(_turbineEfficiencyController.text) ?? 35.0;
      final bladeLength = double.tryParse(_bladeLengthController.text) ?? 5.0;

      // Calculate swept area (A = πr²)
      final sweptArea = 3.14159 * (bladeLength * bladeLength);

      // Extract weather information with null safety
      final windSpeed = weatherData['wind']?['speed']?.toDouble() ?? 0.0;
      final windDirection = weatherData['wind']?['deg']?.toInt() ?? 0;
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

      // Construct a prompt that will generate JSON matching UI expectations
      final prompt = """
You are a wind power prediction expert. Based on these parameters, predict the hourly wind power generation for today.
Format your response as a JSON object that matches the structure below.

Parameters:
- Wind turbine efficiency: $efficiency%
- Blade swept area: $sweptArea square meters
- Location: $location (Lat: $lat, Lng: $lng)
- Current weather: $weatherCondition
- Wind speed: $windSpeed m/s
- Wind direction: $windDirection degrees
- Temperature: $temperature°C
- Current date: $formattedDate

IMPORTANT: Your prediction should directly account for these specific factors:
1. Turbine efficiency ($efficiency%) - higher efficiency means more power per unit of wind energy
2. Swept area ($sweptArea sq meters) - power output scales linearly with swept area
3. Wind speed ($windSpeed m/s) - power output scales with the cube of wind speed (v³)
4. Air density - affected by temperature and altitude
5. Local wind patterns based on location, terrain, and time of day
6. Typical daily wind pattern variations for this location

Use this formula for calculating power: Power (kW) = 0.5 × Air Density (kg/m³) × Swept Area (m²) × (Wind Speed (m/s))³ × (Efficiency/100)
Where air density at sea level is approximately 1.225 kg/m³, adjusted for temperature.

Respond with a JSON object with this structure:
{
  "date": "$formattedDate",
  "summary": {
    "total_kwh": 42.3,
    "peak_hour": "12:00",
    "peak_kw": 7.8,
    "weather_impact": "Current wind speed of $windSpeed m/s is optimal for power generation. Temperature of $temperature°C affects air density by approximately X%"
  },
  "hourly": [
    {
      "hour": "00:00",
      "power_kw": 0.2
    },
    {
      "hour": "01:00",
      "power_kw": 0.3
    },
    // remaining hours...
  ]
}

Generate realistic predictions considering typical daily wind patterns for this location and all parameter impacts.
Only return the JSON structure with no additional text.
""";

      // Using the correct endpoint for Gemini API
      final Uri url = Uri.parse(
          "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent?key=$geminiApiKey"
      );

      // Construct the request body
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
        ],
        "generationConfig": {
          "temperature": 0.2,
          "topK": 32,
          "topP": 0.95,
          "maxOutputTokens": 8192
        }
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
        _dailyWindPrediction = predictionData;
        _windPrediction = predictionData; // Set _windPrediction too
        isWindPredicting = false;
      });

      // Cache the prediction in SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('wind_prediction_${formattedDate}_$location', jsonString);

      print("Successfully received wind prediction from Gemini API!");

    } catch (e) {
      print("Error getting wind predictions from Gemini: $e");
      setState(() {
        _windPredictionError = "Failed to get AI predictions: ${e.toString()}";
        isWindPredicting = false;
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

  // Load wind turbine data from Firestore (if logged in) or SharedPreferences
  Future<void> _loadWindTurbineData() async {
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

        // Load wind turbine parameters
        if (userDoc.data() != null && userDoc.data() is Map) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

          if (userData.containsKey('windEfficiency')) {
            _turbineEfficiencyController.text = userData['windEfficiency'].toString();
          }

          if (userData.containsKey('bladeLength')) {
            _bladeLengthController.text = userData['bladeLength'].toString();
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

      // Load wind turbine parameters with default values if not found
      double? windEfficiency = prefs.getDouble('wind_efficiency');
      if (windEfficiency != null) {
        _turbineEfficiencyController.text = windEfficiency.toString();
      }

      double? bladeLength = prefs.getDouble('blade_length');
      if (bladeLength != null) {
        _bladeLengthController.text = bladeLength.toString();
      }

      print("Loaded wind turbine data from local storage");
    } catch (e) {
      print("Error loading data from SharedPreferences: $e");
    }
  }

  // Save all parameters to both Firestore (if logged in) and SharedPreferences
  Future<void> _saveWindTurbineData() async {
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
        'windEfficiency': double.tryParse(_turbineEfficiencyController.text) ?? 35.0,
        'bladeLength': double.tryParse(_bladeLengthController.text) ?? 5.0,
        'lastUpdated': DateTime.now(),
      };

      FirebaseFirestore.instance.collection('users')
          .doc(userId)
          .update(dataToUpdate);
      print("Wind turbine data saved to Firestore");
    } catch (e) {
      print('Error saving wind turbine data to Firestore: $e');
    }
  }

  // Save to SharedPreferences
  Future<void> _saveDataToLocalStorage() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Save core parameters used across pages
      double? windEfficiency = double.tryParse(_turbineEfficiencyController.text);
      if (windEfficiency != null) {
        await prefs.setDouble('wind_efficiency', windEfficiency);
      }

      double? bladeLength = double.tryParse(_bladeLengthController.text);
      if (bladeLength != null) {
        await prefs.setDouble('blade_length', bladeLength);
      }

      // Save timestamp of last update
      await prefs.setInt('last_updated', DateTime.now().millisecondsSinceEpoch);

      print("Wind turbine data saved to local storage");
    } catch (e) {
      print("Error saving data to SharedPreferences: $e");
    }
  }

  // Calculate theoretical wind power potential using real weather data
  String _calculateWindPowerPotential(Map<String, dynamic>? weatherData) {
    if (weatherData == null) return "N/A";

    try {
      // Extract wind speed from weather data (in m/s)
      // Fix: Ensure the wind speed is converted to double
      double windSpeed = (weatherData['wind']['speed'] is int)
          ? (weatherData['wind']['speed'] as int).toDouble()
          : weatherData['wind']['speed'].toDouble();

      // Get efficiency and blade length from user inputs
      double efficiency = double.tryParse(_turbineEfficiencyController.text) ?? 35.0; // %
      double bladeLength = double.tryParse(_bladeLengthController.text) ?? 5.0; // meters

      // Calculate swept area (A = πr²)
      double sweptArea = 3.14159 * (bladeLength * bladeLength);

      // Air density at sea level (kg/m³)
      double airDensity = 1.225;

      // Wind power formula: P = 0.5 * ρ * A * v³ * Cp
      // Where:
      // ρ = air density
      // A = swept area
      // v = wind speed
      // Cp = power coefficient (efficiency/100)

      double power = 0.5 * airDensity * sweptArea * (windSpeed * windSpeed * windSpeed) * (efficiency / 100.0);

      // Convert to kilowatts
      double powerKW = power / 1000.0;

      return powerKW.toStringAsFixed(2) + " kW";
    } catch (e) {
      print("Error calculating wind power: $e");
      return "Error calculating";
    }
  }

  // Calculate estimated daily wind energy production in kWh
  String _calculateEstimatedDailyOutput(Map<String, dynamic>? weatherData) {
    try {
      double efficiency = double.tryParse(_turbineEfficiencyController.text) ?? 35.0; // %
      double bladeLength = double.tryParse(_bladeLengthController.text) ?? 5.0; // meters

      // Calculate swept area
      double sweptArea = 3.14159 * (bladeLength * bladeLength);

      // Air density
      double airDensity = 1.225;

      // Get average wind speed from weather data if available
      double avgWindSpeed = 5.0; // Default average wind speed in m/s
      if (weatherData != null && weatherData.containsKey('wind') && weatherData['wind'].containsKey('speed')) {
        // Fix: Ensure the current wind speed is converted to double
        double currentWindSpeed = (weatherData['wind']['speed'] is int)
            ? (weatherData['wind']['speed'] as int).toDouble()
            : weatherData['wind']['speed'].toDouble();
        avgWindSpeed = currentWindSpeed * 0.85; // Adjust for daily average being lower than current
      }

      // Calculate power using the average wind speed
      double avgPower = 0.5 * airDensity * sweptArea * (avgWindSpeed * avgWindSpeed * avgWindSpeed) * (efficiency / 100.0);

      // Convert to kW and multiply by estimated hours of good wind per day
      // Assume around 14 hours of effective wind generation
      double dailyOutput = (avgPower / 1000.0) * 14.0;

      return dailyOutput.toStringAsFixed(2) + " kWh";
    } catch (e) {
      print("Error calculating daily output: $e");
      return "Error calculating";
    }
  }

  @override
  void dispose() {
    _turbineEfficiencyController.dispose();
    _bladeLengthController.dispose();
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
        title: const Text('Wind Turbine Setup'),
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

            // Core wind turbine parameters card
            _buildCoreWindTurbineParametersCard(),
            const SizedBox(height: 16),

            // Wind power potential card
            _buildWindPotentialCard(colorScheme, weatherData),
            const SizedBox(height: 16),

            //AI prediction
            if (weatherData != null)
              _buildWindPredictionCard(colorScheme, weatherData),
            if (weatherData != null)
              const SizedBox(height: 16),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: colorScheme.secondaryContainer),
                onPressed: () {
                  _saveWindTurbineData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Wind turbine settings saved')),
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

  // Weather info card
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
                'Wind turbine estimates will use default values',
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
    // Fix: Ensure temperature is converted to double
    final temperature = (weatherData['main']['temp'] is int)
        ? (weatherData['main']['temp'] as int).toDouble()
        : weatherData['main']['temp'].toDouble();
    final weatherCondition = weatherData['weather'][0]['main'];
    final weatherDescription = weatherData['weather'][0]['description'];
    // Fix: Ensure wind speed is converted to double
    final windSpeed = (weatherData['wind']['speed'] is int)
        ? (weatherData['wind']['speed'] as int).toDouble()
        : weatherData['wind']['speed'].toDouble();
    // Fix: Ensure wind direction is converted to double
    final windDirection = (weatherData['wind']['deg'] is int)
        ? (weatherData['wind']['deg'] as int).toDouble()
        : weatherData['wind']['deg'].toDouble();

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
                      'Wind Speed: ${windSpeed.toStringAsFixed(1)} m/s',
                      style: TextStyle(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.bold, // Highlight wind speed for wind turbine
                      ),
                    ),
                    Text(
                      'Wind Direction: ${_getWindDirectionText(windDirection)}',
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

  // Helper to convert wind direction in degrees to cardinal direction
  String _getWindDirectionText(double degrees) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    int index = ((degrees + 22.5) % 360 / 45).floor();
    return directions[index];
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
                            'Wind turbine settings will be saved locally',
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

  // Core wind turbine parameters card
  Widget _buildCoreWindTurbineParametersCard() {
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
                  Icons.air, // Wind icon
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Wind Turbine Parameters',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildParameterInputField(
              'Turbine Efficiency (%)',
              _turbineEfficiencyController,
              '0-100',
                  (value) {
                double? parsed = double.tryParse(value!);
                if (parsed != null && parsed >= 0 && parsed <= 100) {
                  return null;
                }
                return 'Enter a valid percentage';
              },
              tooltip: 'The percentage of wind energy that your turbine can convert to electricity',
            ),
            const SizedBox(height: 12),
            _buildParameterInputField(
              'Blade Length (meters)',
              _bladeLengthController,
              '1-50',
                  (value) {
                double? parsed = double.tryParse(value!);
                if (parsed != null && parsed > 0 && parsed <= 50) {
                  return null;
                }
                return 'Enter a valid blade length';
              },
              tooltip: 'The length of each blade from center to tip',
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // Wind power potential card
  Widget _buildWindPotentialCard(ColorScheme colorScheme, Map<String, dynamic>? weatherData) {
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
                  'Wind Production Estimates',
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
                  _calculateWindPowerPotential(weatherData),
                  colorScheme,
                ),
                _buildEstimateInfoColumn(
                  Icons.air,
                  'Daily Output',
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
                'Note: Wind energy estimates are based on current wind conditions and may vary significantly throughout the day. Actual production depends on consistent wind speeds and proper turbine placement.',
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

  Widget _buildWindPredictionCard(ColorScheme colorScheme, Map<String, dynamic>? weatherData) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: colorScheme.tertiaryContainer,
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
                      Icons.electric_bolt,
                      color: colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AI Wind Power Forecast',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ],
                ),
                if (!isWindPredicting && _windPrediction == null && _windPredictionError == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: ElevatedButton(
                      onPressed: () => _getWindPredictionFromModel(weatherData),
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
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
                if (_windPrediction != null)
                  IconButton(
                    icon: Icon(Icons.refresh),
                    onPressed: () => _getWindPredictionFromModel(weatherData),
                    tooltip: 'Refresh forecast',
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Show loading, error, or prediction results
            if (isWindPredicting)
              Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      color: colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Generating wind power prediction...',
                      style: TextStyle(
                        color: colorScheme.onTertiaryContainer,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              )
            else if (_windPredictionError != null)
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
                      'Error: $_windPredictionError',
                      style: TextStyle(
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _getWindPredictionFromModel(weatherData),
                      child: Text('Try Again'),
                    ),
                  ],
                ),
              )
            else if (_windPrediction != null)
                _buildWindForecastResults(colorScheme)
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
                      'Get a prediction of your wind turbine power production throughout the day',
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

  Widget _buildPredictionInfoItem(String label, String value, ColorScheme colorScheme) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: colorScheme.onTertiaryContainer,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white38,
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