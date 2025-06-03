import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pravah/pages/home_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import '../providers/weather_provider.dart';


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

// Original function kept for backward compatibility
Future<void> _saveSelectedLocation(double lat, double lng, String name) async {
  _saveUserPreferencesLocally(lat: lat, lng: lng, name: name);
}

class ProfilePage extends StatefulWidget {
  final Map<String, dynamic>? locationData;

  const ProfilePage({super.key, this.locationData});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String username = "Guest User";
  String email = "Not logged in";
  String selectedLocation = "Delhi"; // Default location
  LatLng? coordinates; // Add coordinates field
  bool isUserLoggedIn = false;  // Track login status

  // Controllers for user parameters
  final TextEditingController _windEfficiencyController = TextEditingController(
      text: "85.0");
  final TextEditingController _bladeLengthController = TextEditingController(
      text: "5.0");
  final TextEditingController _solarPanelEfficiencyController = TextEditingController(
      text: "90.0");
  final TextEditingController _solarPanelAreaController = TextEditingController(
      text: "10.0");

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _loadAllUserData();
    _restoreSelectedLocation();
  }

  // Check if user is logged in
  void _checkLoginStatus() {
    User? user = FirebaseAuth.instance.currentUser;
    setState(() {
      isUserLoggedIn = user != null;
      if (!isUserLoggedIn) {
        username = "Guest User";
        email = "Not logged in";
      }
    });
  }

  // Restore location from SharedPreferences
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

      // Fetch weather data using the saved coordinates
      Provider.of<WeatherProvider>(context, listen: false)
          .fetchWeatherDataByCoordinates(lat, lng);
    } else {
      // Default to the last known location or manually set location
      Provider.of<WeatherProvider>(context, listen: false)
          .fetchWeatherDataByCity(selectedLocation);
    }
  }

  // Load all user data (from Firestore if logged in, otherwise from SharedPreferences)
  Future<void> _loadAllUserData() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // User is logged in, load from Firestore
      _loadUserDataFromFirestore(user);
    } else {
      // User is not logged in, load from SharedPreferences
      _loadUserDataFromLocalStorage();
    }
  }

  // Load user data from Firestore
  Future<void> _loadUserDataFromFirestore(User user) async {
    setState(() {
      email = user.email ?? "Email not available";
    });

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        setState(() {
          username = userDoc.get('username') ?? "Username not set";
        });

        // Load power prediction parameters
        if (userDoc.data() != null && userDoc.data() is Map) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

          if (userData.containsKey('windEfficiency')) {
            _windEfficiencyController.text = userData['windEfficiency'].toString();
          }

          if (userData.containsKey('bladeLength')) {
            _bladeLengthController.text = userData['bladeLength'].toString();
          }

          if (userData.containsKey('solarPanelEfficiency')) {
            _solarPanelEfficiencyController.text = userData['solarPanelEfficiency'].toString();
          }

          if (userData.containsKey('solarPanelArea')) {
            _solarPanelAreaController.text = userData['solarPanelArea'].toString();
          }
        }
      }
    } catch (e) {
      setState(() {
        username = "Failed to load username";
      });
      print("Error loading user data: $e");
    }
  }

  // Load user data from SharedPreferences
  Future<void> _loadUserDataFromLocalStorage() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Load power parameters with default values if not found
      double? windEfficiency = prefs.getDouble('wind_efficiency');
      if (windEfficiency != null) {
        _windEfficiencyController.text = windEfficiency.toString();
      }

      double? bladeLength = prefs.getDouble('blade_length');
      if (bladeLength != null) {
        _bladeLengthController.text = bladeLength.toString();
      }

      double? solarEfficiency = prefs.getDouble('solar_panel_efficiency');
      if (solarEfficiency != null) {
        _solarPanelEfficiencyController.text = solarEfficiency.toString();
      }

      double? solarArea = prefs.getDouble('solar_panel_area');
      if (solarArea != null) {
        _solarPanelAreaController.text = solarArea.toString();
      }

      print("Loaded user preferences from local storage");
    } catch (e) {
      print("Error loading data from SharedPreferences: $e");
    }
  }

  @override
  void dispose() {
    _windEfficiencyController.dispose();
    _bladeLengthController.dispose();
    _solarPanelEfficiencyController.dispose();
    _solarPanelAreaController.dispose();
    super.dispose();
  }

  // Get weather for a specific city by name
  Future<void> _getWeatherForCity(String city) async {
    if (city.isEmpty) return;

    setState(() {
      selectedLocation = city;
    });

    final weatherProvider = Provider.of<WeatherProvider>(context, listen: false);
    await weatherProvider.fetchWeatherDataByCity(city);

    if (weatherProvider.weatherData != null) {
      final data = weatherProvider.weatherData!;
      setState(() {
        // Update coordinates from the weather API response
        if (data.containsKey('coord')) {
          coordinates = LatLng(
              data['coord']['lat'].toDouble(),
              data['coord']['lon'].toDouble()
          );
        }
      });

      // Save the location data
      _saveLocationData();
    }
  }

  // Get weather using coordinates
  Future<void> _getWeatherByCoordinates(LatLng coords) async {
    final weatherProvider = Provider.of<WeatherProvider>(context, listen: false);
    await weatherProvider.fetchWeatherDataByCoordinates(coords.latitude, coords.longitude);

    if (weatherProvider.weatherData != null) {
      setState(() {
        selectedLocation = weatherProvider.weatherData!['name']; // Update location name from API
      });

      // Save the location data
      _saveLocationData();
    }
  }

  // Save location and power parameters (to Firestore if logged in, and SharedPreferences for all users)
  void _saveLocationData() {
    // Save to Firestore if user is logged in
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _saveLocationToFirestore(user.uid);
    }

    // Always save to SharedPreferences (for all users, including guests)
    _saveParametersToLocalStorage();
  }

  // Save parameters to SharedPreferences (for both logged in and non-logged in users)
  void _saveParametersToLocalStorage() {
    try {
      double? windEfficiency = double.tryParse(_windEfficiencyController.text);
      double? bladeLength = double.tryParse(_bladeLengthController.text);
      double? solarEfficiency = double.tryParse(_solarPanelEfficiencyController.text);
      double? solarArea = double.tryParse(_solarPanelAreaController.text);

      _saveUserPreferencesLocally(
        lat: coordinates?.latitude,
        lng: coordinates?.longitude,
        name: selectedLocation,
        windEfficiency: windEfficiency,
        bladeLength: bladeLength,
        solarPanelEfficiency: solarEfficiency,
        solarPanelArea: solarArea,
      );

      print("User preferences saved locally");
    } catch (e) {
      print("Error saving parameters to SharedPreferences: $e");
    }
  }

  // Save the current location and power parameters to Firestore
  void _saveLocationToFirestore(String userId) {
    try {
      Map<String, dynamic> dataToUpdate = {
        'selectedLocation': selectedLocation,
        'windEfficiency': double.tryParse(_windEfficiencyController.text) ?? 85.0,
        'bladeLength': double.tryParse(_bladeLengthController.text) ?? 50.0,
        'solarPanelEfficiency': double.tryParse(_solarPanelEfficiencyController.text) ?? 20.0,
        'solarPanelArea': double.tryParse(_solarPanelAreaController.text) ?? 100.0,
        'lastUpdated': DateTime.now(),
      };

      // Save coordinates if available
      if (coordinates != null) {
        dataToUpdate['coordinates'] = GeoPoint(coordinates!.latitude, coordinates!.longitude);
      }

      FirebaseFirestore.instance.collection('users')
          .doc(userId)
          .update(dataToUpdate);
      print("Location and parameters saved to Firestore");
    } catch (e) {
      print('Error saving location to Firestore: $e');
    }
  }

  // Get weather icon based on condition
  IconData _getWeatherIcon(String? condition) {
    if (condition == null) return Icons.cloud_queue;

    switch (condition.toLowerCase()) {
      case 'clear':
        return Icons.wb_sunny;
      case 'clouds':
        return Icons.cloud;
      case 'rain':
      case 'drizzle':
        return Icons.grain;
      case 'thunderstorm':
        return Icons.flash_on;
      case 'snow':
        return Icons.ac_unit;
      case 'mist':
      case 'fog':
      case 'haze':
      case 'smoke':
      case 'dust':
      case 'sand':
        return Icons.cloud_queue;
      default:
        return Icons.cloud_queue;
    }
  }

  // Format timestamp to readable date/time
  String _formatTimestamp(int timestamp) {
    DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return DateFormat('MMM dd, yyyy - HH:mm').format(dateTime);
  }

  // Format wind direction in degrees to cardinal direction
  String _getWindDirection(int degrees) {
    List<String> directions = [
      'N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
      'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'
    ];
    int index = ((degrees / 22.5) + 0.5).floor() % 16;
    return directions[index];
  }

  // Calculate potential wind power based on wind speed and user parameters
  String _calculateWindPowerPotential(Map<String, dynamic>? weather) {
    if (weather == null || !weather.containsKey('wind')) return "N/A";

    try {
      double windSpeed = weather['wind']['speed'].toDouble(); // m/s
      double efficiency = double.tryParse(_windEfficiencyController.text) ?? 85.0; // %
      double bladeLength = double.tryParse(_bladeLengthController.text) ?? 50.0; // meters

      // Wind power formula: P = 0.5 * ρ * A * v³ * Cp
      // ρ (air density) ~= 1.225 kg/m³
      // A (swept area) = π * r²
      // Cp (power coefficient) = efficiency / 100

      double airDensity = 1.225; // kg/m³
      double area = 3.14159 * (bladeLength * bladeLength); // m²
      double powerCoefficient = efficiency / 100.0;

      // Calculate power in watts
      double power = 0.5 * airDensity * area * (windSpeed * windSpeed * windSpeed) * powerCoefficient;

      // Convert to kilowatts
      double powerKW = power / 1000.0;

      return powerKW.toStringAsFixed(2) + " kW";
    } catch (e) {
      return "Error calculating";
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

  String _calculateTotalPowerPotential(Map<String, dynamic>? weather) {
    try {
      double windPower = double.tryParse(_calculateWindPowerPotential(weather).replaceAll(" kW", "")) ?? 0.0;
      double solarPower = double.tryParse(_calculateSolarPowerPotential(weather).replaceAll(" kW", "")) ?? 0.0;
      return (windPower + solarPower).toStringAsFixed(2) + " kW";
    } catch (e) {
      return "Error";
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final weatherProvider = Provider.of<WeatherProvider>(context);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('My Profile'),
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
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (coordinates != null) {
                _getWeatherByCoordinates(coordinates!);
              } else {
                _getWeatherForCity(selectedLocation);
              }
            },
          ),
        ],
      ),
      body: weatherProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Information
            Card(
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
                          radius: 30,
                          child: Text(
                            username.isNotEmpty
                                ? username[0].toUpperCase()
                                : "?",
                            style: TextStyle(
                              fontSize: 24,
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
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (!isUserLoggedIn)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    'Your settings will be saved locally',
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
                    const SizedBox(height: 16),
                    Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'Selected Location: $selectedLocation',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (coordinates != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          'Coordinates: ${coordinates!.latitude.toStringAsFixed(4)}, ${coordinates!.longitude.toStringAsFixed(4)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Weather Information
            if (weatherProvider.weatherData != null) _buildWeatherCard(weatherProvider.weatherData!),
            if (weatherProvider.errorMessage != null) _buildErrorCard(weatherProvider.errorMessage!),
            const SizedBox(height: 16),

            // Wind Power Prediction Parameters
            _buildWindPowerParametersCard(),
            const SizedBox(height: 16),

            // Solar Power Prediction Parameters
            _buildSolarPowerParametersCard(),
            const SizedBox(height: 16),

            // Power Potential Summary
            _buildPowerPotentialCard(weatherProvider.weatherData),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Weather info card
  Widget _buildWeatherCard(Map<String, dynamic> weather) {
    final main = weather['main'];
    final cityName = weather['name'];
    final country = weather['sys']['country'];
    final weatherInfo = weather['weather'][0];
    final weatherMain = weatherInfo['main'];
    final weatherDescription = weatherInfo['description'];
    final temperature = main['temp'];
    final tempBgColor = Colors.amber;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: tempBgColor, // Set background color based on temperature
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weather in $cityName, $country',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _formatTimestamp(weather['dt']),

                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${temperature.toStringAsFixed(1)}°C',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      weatherDescription.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Feels like ${main['feels_like'].toStringAsFixed(1)}°C',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Row(
                      children: [
                        Text('↓${main['temp_min'].toStringAsFixed(1)}°C'),
                        const SizedBox(width: 8),
                        Text('↑${main['temp_max'].toStringAsFixed(1)}°C'),
                      ],
                    ),
                  ],
                ),
                Icon(
                  _getWeatherIcon(weatherMain),
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(),
            const SizedBox(height: 8),
            // Key weather details for power prediction
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildWeatherDetailColumn(
                  Icons.air,
                  'Wind',
                  '${weather['wind']['speed'].toStringAsFixed(1)} m/s',
                ),
                _buildWeatherDetailColumn(
                  Icons.water_drop,
                  'Humidity',
                  '${main['humidity']}%',
                ),
                _buildWeatherDetailColumn(
                  Icons.cloud,
                  'Clouds',
                  '${weather['clouds']['all']}%',
                ),
                _buildWeatherDetailColumn(
                  Icons.compress,
                  'Pressure',
                  '${main['pressure']} hPa',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherDetailColumn(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // Error card
  Widget _buildErrorCard(String error) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  'Weather Error',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                if (coordinates != null) {
                  _getWeatherByCoordinates(coordinates!);
                } else {
                  _getWeatherForCity(selectedLocation);
                }
              },
              child: Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  // Wind power parameters card
  Widget _buildWindPowerParametersCard() {
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
        Icons.wind_power,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          'Wind Power Parameters',
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
              _windEfficiencyController,
              '0-100',
                  (value) {
                double? parsed = double.tryParse(value!);
                if (parsed != null && parsed >= 0 && parsed <= 100) {
                  _saveLocationData();
                  return null;
                }
                return 'Enter a valid percentage';
              },
            ),
            const SizedBox(height: 8),
            _buildParameterInputField(
              'Blade Length (m)',
              _bladeLengthController,
              '1-100',
                  (value) {
                double? parsed = double.tryParse(value!);
                if (parsed != null && parsed > 0 && parsed <= 100) {
                  _saveLocationData();
                  return null;
                }
                return 'Enter a valid length';
              },
            ),
          ],
        ),
      ),
    );
  }

// Fix for the _buildSolarPowerParametersCard() method
  Widget _buildSolarPowerParametersCard() {
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
                  'Solar Power Parameters',
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
                  _saveLocationData();
                  return null;
                }
                return 'Enter a valid percentage';
              },
            ),
            const SizedBox(height: 8),
            _buildParameterInputField(
              'Panel Area (m²)',
              _solarPanelAreaController,
              '1-1000',
                  (value) {
                double? parsed = double.tryParse(value!);
                if (parsed != null && parsed > 0 && parsed <= 1000) {
                  _saveLocationData();
                  return null;
                }
                return 'Enter a valid area';
              },
            ),
          ],
        ),
      ),
    );
  }
  // Power potential summary card
  // Power potential summary card
  Widget _buildPowerPotentialCard(Map<String, dynamic>? weatherData) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bolt,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  'Current Generation Potential',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPotentialInfoColumn(
                  Icons.wind_power,
                  'Wind',
                  weatherData != null ? _calculateWindPowerPotential(weatherData) : "N/A",
                ),
                _buildPotentialInfoColumn(
                  Icons.solar_power,
                  'Solar',
                  weatherData != null ? _calculateSolarPowerPotential(weatherData) : "N/A",
                ),
                _buildPotentialInfoColumn(
                  Icons.bolt,
                  'Total',
                  weatherData != null
                      ? _calculateTotalPowerPotential(weatherData)
                      : "N/A",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPotentialInfoColumn(IconData icon, String label, String value) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: Theme
              .of(context)
              .colorScheme
              .secondary,
          child: Icon(
            icon,
            color: Theme
                .of(context)
                .colorScheme
                .onSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Theme
                .of(context)
                .colorScheme
                .onSecondaryContainer,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Theme
                .of(context)
                .colorScheme
                .onSecondaryContainer,
          ),
        ),
      ],
    );
  }

  Widget _buildParameterInputField(
      String label,
      TextEditingController controller,
      String hint,
      String? Function(String?)? validator,
      ) {
    return TextFormField(
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
        // Only save if the value is valid
        if (validator != null && validator(value) == null) {
          _saveLocationData(); // Call the method that handles both local storage and Firestore
        }
      },
    );
  }}