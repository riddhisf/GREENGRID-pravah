import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class LocationPage extends StatefulWidget {
  static const String routeName = 'SelectVenue_page';
  const LocationPage({Key? key}) : super(key: key);

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  final _locationController = TextEditingController();
  var uuid = const Uuid();
  String? _sessionToken;
  List<dynamic> _placeList = [];
  String? _previousInput;

  Completer<GoogleMapController> mapController = Completer();
  static const CameraPosition _kGoogle = CameraPosition(
    target: LatLng(20.42796133580664, 80.885749655962),
    zoom: 14.4746,
  );
  final Set<Marker> _markers = <Marker>{};
  LatLng? coordinates;
  String? selectedLocationName;
  bool _isUserSelectedLocation = false; // Tracks if the user has manually selected a location

  // Theme colors
  final Color _backgroundColor = const Color(0xFF0B2732);
  final Color _cardColor = const Color(0xFFF5F5DC);
  final Color _accentColor = const Color(0xFF61A6AB);
  final Color _textColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _locationController.addListener(_onChanged);
    _requestLocationPermission();
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  void _onLocationSelected(double lat, double lng, String name) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('selected_lat', lat);
    await prefs.setDouble('selected_lng', lng);
    await prefs.setString('selected_name', name);

    Navigator.pop(context, {
      'coordinates': LatLng(lat, lng),
      'name': name,
    });
  }


  void _onChanged() {
    if (_isUserSelectedLocation) return; // Ignore changes after user selects a location

    String currentInput = _locationController.text;
    if (currentInput.isEmpty) {
      setState(() {
        _placeList = [];
      });
      return;
    }

    if (_sessionToken == null) {
      _sessionToken = uuid.v4();
    }

    if (_previousInput != currentInput) {
      _previousInput = currentInput;
      getSuggestion(currentInput);
    }
  }

  Future<void> getSuggestion(String input) async {
    String PLACES_API_KEY = dotenv.env['GOOGLE_MAP_API_KEY'] ?? '';
    String baseURL = 'https://maps.googleapis.com/maps/api/place/autocomplete/json';
    String request = '$baseURL?input=$input&key=$PLACES_API_KEY&sessiontoken=$_sessionToken';

    try {
      var response = await http.get(Uri.parse(request));
      var data = json.decode(response.body);
      if (response.statusCode == 200) {
        setState(() {
          _placeList = data['predictions'];
        });
      } else {
        print('Error: ${response.body}');
      }
    } catch (e) {
      print('Error fetching suggestions: $e');
    }
  }

  void _requestLocationPermission() async {
    Location location = Location();
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;
    _serviceEnabled = await location.serviceEnabled();

    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) return;
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) return;
    }

    // Fetch current location only if user has NOT selected a location
    if (!_isUserSelectedLocation) {
      _getCurrentLocation();
    }
  }

  void _getCurrentLocation() async {
    try {
      LocationData locationData = await Location().getLocation();
      LatLng selectedCoordinates = LatLng(locationData.latitude!, locationData.longitude!);

      // Only update if user hasn't selected a location
      if (!_isUserSelectedLocation) {
        setState(() {
          coordinates = selectedCoordinates;
          selectedLocationName = "Current Location";
          _locationController.text = selectedLocationName!;
          _previousInput = selectedLocationName;
        });

        _moveCameraToPosition(selectedCoordinates);
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  void _moveCameraToPosition(LatLng position) async {
    final GoogleMapController controller = await mapController.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(position, 14));

    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('selected_location'),
          position: position,
          infoWindow: InfoWindow(title: selectedLocationName ?? "Selected Location"),
        ),
      );

      coordinates = position;
    });

    _showLocationConfirmation();
  }

  void _showLocationConfirmation() {
    if (coordinates != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Location selected: ${selectedLocationName ?? "Selected Location"}',
            style: TextStyle(color: _textColor),
          ),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'CONFIRM',
            textColor: Colors.white,
            onPressed: _confirmLocationSelection,
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _confirmLocationSelection() {
    if (coordinates != null) {
      _isUserSelectedLocation = true; // Mark that user has selected a location
      Navigator.pop(context, {
        "coordinates": coordinates,
        "name": selectedLocationName ?? "Selected Location"
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a location first', style: TextStyle(color: _textColor)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text("Location"),
        backgroundColor: _backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: _textColor),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _kGoogle,
            markers: _markers,
            myLocationEnabled: true,
            compassEnabled: true,
            onTap: (LatLng tappedPoint) {
              setState(() {
                coordinates = tappedPoint;
                selectedLocationName = "Selected on Map";
                _locationController.text = selectedLocationName!;
                _isUserSelectedLocation = true; // Mark user selection
              });
              _moveCameraToPosition(tappedPoint);
            },
            onMapCreated: (controller) {
              mapController.complete(controller);
              controller.setMapStyle('''
                [
                  {
                    "elementType": "geometry",
                    "stylers": [
                      {
                        "color": "#0f2d39"
                      }
                    ]
                  },
                  {
                    "elementType": "labels.text.fill",
                    "stylers": [
                      {
                        "color": "#746855"
                      }
                    ]
                  },
                  {
                    "elementType": "labels.text.stroke",
                    "stylers": [
                      {
                        "color": "#242f3e"
                      }
                    ]
                  }
                ]
              ''');
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _confirmLocationSelection,
        icon: const Icon(Icons.check),
        label: const Text("Confirm"),
        backgroundColor: Colors.green,
        foregroundColor: _textColor,
      ),
    );
  }
}
