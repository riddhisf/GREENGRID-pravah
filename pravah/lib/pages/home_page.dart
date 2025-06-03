// ignore_for_file: prefer_const_constructors_in_immutables, library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:location/location.dart';
import 'package:pravah/components/custom_appbar.dart';
import 'package:pravah/components/custom_navbar.dart';
import 'package:pravah/components/custom_snackbar.dart';
import 'package:pravah/components/loader.dart';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Import for LatLng
import 'package:pravah/pages/location_page.dart'; // Import your LocationPage
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'package:pravah/pages/solar_panel_setup_page.dart';
import 'package:pravah/pages/windmill_setup_page.dart';
import 'package:pravah/main.dart';
import 'track_page.dart';
import 'biomass_setup_page.dart';
import 'geothermal_setup_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  final Map<String, dynamic>? selectedLocation; // Updated to accept more location details

  HomePage({super.key, this.selectedLocation});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? user;
  String? username;
  bool isLoading = true; // Loader state
  Map<String, double>? currentLocation; // For raw coordinates
  String city = "Ghaziabad"; // Default city
  double temperature = 25.0; // Default temperature
  Widget? recommendationWidget;

  // Selected location details
  String? selectedLocationName;
  String? nearestLocationName;
  LatLng? selectedCoordinates;
  bool isLoadingLocation = false;
  bool isLoadingWeather = false;
  String weatherCondition = "Sunny";
  final geminiApiKey=dotenv.env['AI_API_KEY'];

  @override
  void initState() {
    super.initState();
    fetchUserData();
    _restoreSelectedLocation();
    Future.delayed(Duration.zero, () {
      if (_auth.currentUser != null) {
        loadUserRecommendation(context, _auth.currentUser!.uid);
      }
    });
  }

  Future<String> generateEnergyRecommendation(Map<String, dynamic> userData) async {
    final Uri url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent?key=$geminiApiKey"
    );

    // Extract relevant data from user data (whether from Firebase or local storage)
    final String location = userData['selectedLocation'] ?? "Unknown Location";

    // Handle coordinates which could be a GeoPoint or a Map
    double latitude = 0.0;
    double longitude = 0.0;
    if (userData['coordinates'] != null) {
      if (userData['coordinates'] is GeoPoint) {
        final GeoPoint geoPoint = userData['coordinates'];
        latitude = geoPoint.latitude;
        longitude = geoPoint.longitude;
      } else if (userData['coordinates'] is Map) {
        latitude = userData['coordinates']['latitude'] ?? 0.0;
        longitude = userData['coordinates']['longitude'] ?? 0.0;
      } else if (userData['coordinates'] is String) {
        // Parse from string if saved that way in preferences
        final coordStr = userData['coordinates'] as String;
        final regex = RegExp(r'(\d+\.\d+)° N, (\d+\.\d+)° E');
        final match = regex.firstMatch(coordStr);
        if (match != null) {
          latitude = double.tryParse(match.group(1) ?? '0') ?? 0.0;
          longitude = double.tryParse(match.group(2) ?? '0') ?? 0.0;
        }
      }
    }

    final double bladeLength = userData['bladeLength50']?.toDouble() ?? 0.0;
    final double solarPanelArea = userData['solarPanelArea']?.toDouble() ?? 0.0;
    final double solarEfficiency = userData['solarPanelEfficiency']?.toDouble() ?? 0.0;
    final double windEfficiency = userData['windEfficiency']?.toDouble() ?? 0.0;

    // Create prompt with the available data
    final String prompt = """
  Based on the following data, determine whether "solarpanels" or "smallwindturbine" would be the better renewable energy option.
  
  Location: $location
  Coordinates: $latitude° N, $longitude° E
  Available blade length for wind turbine: $bladeLength
  Available area for solar panels: $solarPanelArea
  Solar panel efficiency rating: $solarEfficiency
  Wind turbine efficiency rating: $windEfficiency
  
  Respond with ONLY ONE of these exact words (no additional text):
  - solarpanels
  - smallwindturbine
  """;

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

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        String recommendation = jsonResponse["candidates"]?[0]["content"]?["parts"]?[0]["text"] ?? "solarpanels";

        // Clean up any extra spaces, line breaks or capitalization
        recommendation = recommendation.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');

        // Validate it's one of our allowed values
        if (recommendation != "solarpanels" && recommendation != "smallwindturbine") {
          recommendation = "solarpanels"; // Default if model returns unexpected response
        }

        return recommendation;
      } else {
        return "solarpanels"; // Default on error
      }
    } catch (e) {
      return "solarpanels"; // Default on exception
    }
  }

  // Function to load user data either from Firebase or local storage
  Future<Map<String, dynamic>> getUserData(String userId) async {
    // Try loading from shared preferences first
    final prefs = await SharedPreferences.getInstance();
    final String? userData = prefs.getString('user_energy_data');

    if (userData != null) {
      // User data exists in local storage
      return jsonDecode(userData) as Map<String, dynamic>;
    } else {
      // Try loading from Firebase if local data doesn't exist
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();

        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          // Save to local storage for future use
          await prefs.setString('user_energy_data', jsonEncode(data));
          return data;
        } else {
          throw Exception("User data not found");
        }
      } catch (e) {
        // Return default values if both options fail
        return {
          'selectedLocation': 'Unknown Location',
          'coordinates': {'latitude': 0.0, 'longitude': 0.0},
          'bladeLength50': 0.0,
          'solarPanelArea': 0.0,
          'solarPanelEfficiency': 0.0,
          'windEfficiency': 0.0,
        };
      }
    }
  }


// Restore location from SharedPreferences
  Future<void> _restoreSelectedLocation() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    double? lat = prefs.getDouble('selected_lat');
    double? lng = prefs.getDouble('selected_lng');
    String? name = prefs.getString('selected_name');

    if (lat != null && lng != null && name != null) {
      setState(() {
        selectedCoordinates = LatLng(lat, lng);
        selectedLocationName = name;
      });

      await _getNearestLocation(lat, lng);
      await _getWeatherForLocation(lat, lng);
    } else {
      _requestLocationPermission(); // Get current location only if no stored location
    }
  }



  // Process location data passed from LocationPage
  Future<void> _processSelectedLocation(Map<String, dynamic> locationData) async {
    setState(() {
      isLoadingLocation = true;
    });

    if (locationData.containsKey('coordinates') && locationData['coordinates'] != null) {
      final coordinates = locationData['coordinates'] as LatLng;

      setState(() {
        selectedCoordinates = coordinates;
        selectedLocationName = locationData['name'] ?? "Selected Location";
      });

      // Save to SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('selected_lat', coordinates.latitude);
      await prefs.setDouble('selected_lng', coordinates.longitude);
      await prefs.setString('selected_name', selectedLocationName!);

      // Get nearest location and weather
      await _getNearestLocation(coordinates.latitude, coordinates.longitude);
      await _getWeatherForLocation(coordinates.latitude, coordinates.longitude);

      setState(() {
        isLoadingLocation = false;
      });
    }
  }



  // Get nearest named location using Google's Reverse Geocoding API
  Future<void> _getNearestLocation(double latitude, double longitude) async {
    String API_KEY = dotenv.env['GOOGLE_MAP_API_KEY'] ?? ''; // Replace with your API key
    String baseURL = 'https://maps.googleapis.com/maps/api/geocode/json';
    String request = '$baseURL?latlng=$latitude,$longitude&key=$API_KEY';

    try {
      var response = await http.get(Uri.parse(request));
      var data = json.decode(response.body);

      if (response.statusCode == 200 && data['results'] != null && data['results'].isNotEmpty) {
        // Get the most detailed result which is usually the first one
        var result = data['results'][0];
        String formattedAddress = result['formatted_address'];

        // Extract city and locality information from address components
        String locality = "";
        String subLocality = "";
        String administrativeArea = "";

        for (var component in result['address_components']) {
          List<String> types = List<String>.from(component['types']);

          if (types.contains('locality')) {
            locality = component['long_name'];
          } else if (types.contains('sublocality') || types.contains('sublocality_level_1')) {
            subLocality = component['long_name'];
          } else if (types.contains('administrative_area_level_1')) {
            administrativeArea = component['long_name'];
          }
        }

        // Choose the most appropriate name for the location
        String locationName = "";
        if (subLocality.isNotEmpty) {
          locationName = subLocality;
          if (locality.isNotEmpty) {
            locationName += ", $locality";
          }
        } else if (locality.isNotEmpty) {
          locationName = locality;
        } else {
          locationName = formattedAddress;
        }

        setState(() {
          nearestLocationName = locationName;
          city = locality.isNotEmpty ? locality : (administrativeArea.isNotEmpty ? administrativeArea : "Unknown");
        });
      }
    } catch (e) {
      print('Error getting nearest location: $e');
    }
  }

  // Get weather for the given location coordinates
  Future<void> _getWeatherForLocation(double latitude, double longitude) async {
    setState(() {
      isLoadingWeather = true;
    });

    String WEATHER_API_KEY = dotenv.env['WEATHER_API_KEY'] ?? ''; // Replace with your OpenWeatherMap API key
    String baseURL = 'https://api.openweathermap.org/data/2.5/weather';
    String request = '$baseURL?lat=$latitude&lon=$longitude&units=metric&appid=$WEATHER_API_KEY';

    try {
      var response = await http.get(Uri.parse(request));
      var data = json.decode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          temperature = data['main']['temp'];
          weatherCondition = data['weather'][0]['main']; // e.g., "Clear", "Clouds", "Rain"
          isLoadingWeather = false;
        });
      } else {
        setState(() {
          isLoadingWeather = false;
        });
        print('Error fetching weather: ${response.body}');
      }
    } catch (e) {
      setState(() {
        isLoadingWeather = false;
      });
      print('Error getting weather: $e');
    }
  }

  void fetchUserData() async {
    setState(() {
      isLoading = true; // Show loader
    });

    user = _auth.currentUser;

    if (user != null) {
      try {
        // Fetch username from Firestore
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .get();

        setState(() {
          username = userDoc.get('username');
          isLoading = false; // Stop loader after data is fetched
        });
      } catch (e) {
        setState(() {
          isLoading = false; // Stop loader on error
        });
        showCustomSnackbar(
          context,
          "Failed to fetch username.",
          backgroundColor: const Color.fromARGB(255, 57, 2, 2),
        );
      }
    } else {
      setState(() {
        isLoading = false; // Stop loader if no user
      });
    }
  }

  void _requestLocationPermission() async {
    Location location = Location();
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Location services are disabled')));
        return;
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        _showPermissionDialog();
        return;
      }
    }

    // Location permissions granted, now you can get the location
    _getCurrentLocation();
  }

  void _getCurrentLocation() async {
    if (selectedCoordinates != null) {
      print("User has already selected a location. Skipping auto-location fetch.");
      return; // Exit if user already selected a location
    }

    try {
      setState(() {
        isLoadingLocation = true;
      });

      LocationData locationData = await Location().getLocation();
      LatLng coords = LatLng(locationData.latitude!, locationData.longitude!);

      setState(() {
        currentLocation = {
          'latitude': locationData.latitude ?? 0.0,
          'longitude': locationData.longitude ?? 0.0,
        };
        selectedCoordinates = coords;
      });

      // Get nearest location and weather
      await _getNearestLocation(coords.latitude, coords.longitude);
      await _getWeatherForLocation(coords.latitude, coords.longitude);

      setState(() {
        isLoadingLocation = false;
      });
    } catch (e) {
      setState(() {
        isLoadingLocation = false;
      });
      print('Error getting location: $e');
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Location Permission Required'),
        content: Text(
            'This app needs access to your location to function properly.'),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await Location().requestPermission();
              _requestLocationPermission();
            },
            child: Text('Grant'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Location permission denied')));
            },
            child: Text('Deny'),
          ),
        ],
      ),
    );
  }

  // Navigate to location selection page
  Future<void> _navigateToLocationPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPage(),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      _processSelectedLocation(result);
    }
  }


  // Determine if it's currently daytime
  bool _isDaytime() {
    final now = DateTime.now();
    // Consider daytime between 6 AM and 6 PM
    return now.hour >= 6 && now.hour < 18;
  }

  // Return appropriate weather icon based on weather condition and time of day
  IconData _getWeatherIcon() {
    bool isDaytime = _isDaytime();

    switch (weatherCondition.toLowerCase()) {
      case 'clear':
        return isDaytime ? Icons.wb_sunny : Icons.nightlight_round;
      case 'clouds':
        return isDaytime ? Icons.cloud : FontAwesomeIcons.cloudMoon;
      case 'rain':
        return isDaytime ? FontAwesomeIcons.cloudRain : FontAwesomeIcons.cloudMoonRain;
      case 'thunderstorm':
        return isDaytime ? FontAwesomeIcons.boltLightning : FontAwesomeIcons.cloudBolt;
      case 'snow':
        return isDaytime ? FontAwesomeIcons.snowflake : FontAwesomeIcons.snowflake;
      case 'mist':
      case 'fog':
      case 'haze':
        return isDaytime ? FontAwesomeIcons.smog : FontAwesomeIcons.smog;
      default:
        return isDaytime ? Icons.wb_sunny : Icons.nightlight_round;
    }
  }

  // Get appropriate color for weather icon based on weather and time
  Color _getWeatherIconColor() {
    bool isDaytime = _isDaytime();

    switch (weatherCondition.toLowerCase()) {
      case 'clear':
        return isDaytime ? Colors.amber : Colors.indigo;
      case 'clouds':
        return isDaytime ? Colors.grey : Colors.blueGrey.shade700;
      case 'rain':
        return Colors.blue;
      case 'thunderstorm':
        return Colors.deepPurple;
      case 'snow':
        return Colors.lightBlue;
      case 'mist':
      case 'fog':
      case 'haze':
        return Colors.blueGrey;
      default:
        return isDaytime ? Colors.amber : Colors.indigo;
    }
  }

  void signUserOut(BuildContext context) async {
    await _auth.signOut();
    showCustomSnackbar(
      context,
      "Signed out successfully!",
      backgroundColor: const Color.fromARGB(255, 2, 57, 24),
    );
  }

  Future<void> loadUserRecommendation(BuildContext context, String userId) async {
    try {
      // Get user data from either local storage or Firebase
      final userData = await getUserData(userId);

      // Generate recommendation based on user data
      final recommendation = await generateEnergyRecommendation(userData);

      // Update UI with recommendation
      setState(() {
        recommendationWidget = buildEnergyRecommendationText(recommendation);
      });
    } catch (e) {
      // Handle errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not generate recommendation: $e")),
      );
    }
  }

  Widget buildEnergyRecommendationText(String recommendation) {
    String displayText = recommendation == "solarpanels" ? "Solar Panels" : "Small Wind Turbine";
    Color highlightColor = recommendation == "solarpanels" ? Colors.amber : Colors.blue;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Recommended for Your Location",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0B2732),
            ),
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(color: Color(0xFF0B2732), fontSize: 16),
                    children: [
                      TextSpan(
                        text: "Based on your location and energy profile, ",
                      ),
                      TextSpan(
                        text: displayText,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: highlightColor,
                        ),
                      ),
                      TextSpan(
                        text: " is your best option! ",
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 5),
          GestureDetector(
            onTap: () {
              // Navigate to explanation page or show dialog with more info
              if (recommendation == "solarpanels") {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SolarPanelSetupPage()),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const WindMillSetupPage()),
                );
              }
            },
            child: Text(
              "Click to learn more about renewable options",
              style: TextStyle(
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0B2732),
              ),
            ),
          ),
        ],
      ),
    );
  }
  // Energy saving item widget
  Widget _buildEnergySavingItem(IconData icon, String value, Color iconColor) {
    return Column(
      children: [
        IconTheme(
          data: IconThemeData(color: iconColor, size: 50), // Explicitly setting color
          child: Icon(icon),
        ),
        SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF0B2732),
          ),
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    // Get current date and time
    DateTime now = DateTime.now();
    String formattedDate = DateFormat('EEEE dd MMMM yyyy').format(now);
    String formattedTime = DateFormat('hh:mm a').format(now);

    return Scaffold(
      backgroundColor: Color(0xFF0B2732),
      appBar: CustomAppBar(title: Text('Home',style:TextStyle(color:Color(0xFF0B2732)),)),
      drawer: CustomDrawer(),
      body: isLoading
          ? const LoaderPage() // Display loader while loading
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Date, Time, and Weather Card
              Card(
                color: Color(0xFFF5F5DC), // Beige background
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B2732),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        formattedTime,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B2732),
                        ),
                      ),
                      SizedBox(height: 16),
                      isLoadingWeather
                          ? CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0B2732)),
                      )
                          : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          PulsatingIcon(
                            icon: _getWeatherIcon(),
                            color: _getWeatherIconColor(),
                            size: 40,
                          ),
                          SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${temperature.toStringAsFixed(1)}°C",
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0B2732),
                                ),
                              ),
                              Text(
                                "$weatherCondition | $city",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF0B2732),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 16),

              // Location Display Card
              Card(
                color: Color(0xFFF5F5DC), // Beige background
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Your Location",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0B2732),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.edit_location_alt, color: Color(0xFF0B2732)),
                            onPressed: _navigateToLocationPage,
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      isLoadingLocation
                          ? Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0B2732)),
                        ),
                      )
                          : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.location_on, color: Colors.red),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  nearestLocationName ?? "Location not available",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF0B2732),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                            ],
                          ),
                          if (selectedCoordinates != null) ...[
                            SizedBox(height: 8),
                            Text(
                              "Latitude: ${selectedCoordinates!.latitude.toStringAsFixed(6)}",
                              style: TextStyle(fontSize: 14, color: Color(0xFF0B2732)),
                            ),
                            Text(
                              "Longitude: ${selectedCoordinates!.longitude.toStringAsFixed(6)}",
                              style: TextStyle(fontSize: 14, color: Color(0xFF0B2732)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 16),

              // Today's Savings Card
              Card(
                color: Color(0xFFF5F5DC), // Beige background
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Today's Savings",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B2732),
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          // Solar Icon
                          _buildEnergySavingItem(
                            Icons.solar_power,
                            globaldailySolar,
                            Colors.amber,

                          ),
                          // Wind Icon
                          _buildEnergySavingItem(
                            Icons.wind_power,
                            globaldailyWind,
                            Colors.blue,
                          ),
                          // Biofuel Icon
                          _buildEnergySavingItem(
                            Icons.eco,
                            globaldailyBiomass,
                            Colors.green,
                          ),
                          // Energy Efficiency Icon
                          _buildEnergySavingItem(
                            Icons.thermostat,
                            globaldailyGeothermal,
                            Colors.orange,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 16),

              // Energy Recommendation Card
              Card(
                color: Color(0xFFF5F5DC), // Beige background
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: recommendationWidget ?? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF0B2732),
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 16),

              // Energy Options Grid
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  InkWell(
                    onTap: () {
                      // Navigate to Solar Panel Setup page
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SolarPanelSetupPage()),
                      );
                    },
                    child: Container(
                      width: 70,
                      height: 90, // Increased height to accommodate text
                      decoration: BoxDecoration(
                        color: Color(0xFF0B2732),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.solar_power,
                            color: Colors.amber,
                            size: 40,
                          ),
                          const SizedBox(height: 5), // Space between icon and text
                          const Text(
                            'Solar',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      // Handle wind turbine option
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context)=>const WindMillSetupPage()),
                      );
                    },
                    child: Container(
                      width: 70,
                      height: 90, // Increased height to accommodate text
                      decoration: BoxDecoration(
                        color: Color(0xFF0B2732),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.wind_power,
                            color: Colors.blue,
                            size: 40,
                          ),
                          const SizedBox(height: 5), // Space between icon and text
                          const Text(
                            'Wind',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context)=>const BioMassSetupPage()));
                      // Handle biofuel option
                    },
                    child: Container(
                      width: 70,
                      height: 90, // Increased height to accommodate text
                      decoration: BoxDecoration(
                        color: Color(0xFF0B2732),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.eco,
                            color: Colors.green,
                            size: 40,
                          ),
                          const SizedBox(height: 5), // Space between icon and text
                          const Text(
                            'Biomass',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context)=>const GeomerthalSetupPage()));
                      // Handle hybrid energy option
                    },
                    child: Container(
                      width: 70,
                      height: 90, // Increased height to accommodate text
                      decoration: BoxDecoration(
                        color: Color(0xFF0B2732),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.thermostat,
                            color: Colors.orange,
                            size: 40,
                          ),
                          const SizedBox(height: 5), // Space between icon and text
                          const Text(
                            'Geothermal',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16),

              // Carbon Footprint Card
              Card(
                color: Color(0xFFF5F5DC), // Beige background
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.eco_outlined,
                        color: Colors.green,
                        size: 30,
                      ),
                      SizedBox(width: 5),
                      RichText(
                        text: TextSpan(
                          style: TextStyle(color: Color(0xFF0B2732), fontSize: 16),
                          children: [
                            TextSpan(
                              text: "Carbon Footprint Reduced: ",
                            ),
                            TextSpan(
                              text: "$globalCarbonFootprint kgCO₂",
                              style: TextStyle(

                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0B2732),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavBar(selectedIndex: 0),
    );
  }
}

// Animated Weather Icon Widget
class PulsatingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;

  const PulsatingIcon({
    Key? key,
    required this.icon,
    required this.color,
    required this.size,
  }) : super(key: key);

  @override
  _PulsatingIconState createState() => _PulsatingIconState();
}

class _PulsatingIconState extends State<PulsatingIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: widget.icon == Icons.wb_sunny ? _controller.value * math.pi / 12 : 0,
          child: Icon(
            widget.icon,
            color: widget.color,
            size: widget.size * (0.9 + _controller.value * 0.1),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
