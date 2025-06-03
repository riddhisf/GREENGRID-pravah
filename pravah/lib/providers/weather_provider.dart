import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';

class WeatherProvider with ChangeNotifier {
  Map<String, dynamic>? _weatherData;
  bool _isLoading = false;
  String? _errorMessage;

  Map<String, dynamic>? get weatherData => _weatherData;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchWeatherDataByCity(String city) async {
    if (city.isEmpty) return;

    _isLoading = true;
    _errorMessage = null;
    _weatherData = null;
    notifyListeners();

    String WEATHER_API_KEY = dotenv.env['WEATHER_API_KEY'] ?? '';
    String baseURL = 'https://api.openweathermap.org/data/2.5/weather';
    String request = '$baseURL?q=$city&units=metric&appid=$WEATHER_API_KEY';

    try {
      var response = await http.get(Uri.parse(request));
      var data = json.decode(response.body);

      if (response.statusCode == 200) {
        _weatherData = data;
        _isLoading = false;
        notifyListeners();
      } else {
        _errorMessage = 'Error fetching weather: ${data['message'] ?? 'City not found'}';
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Error getting weather: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchWeatherDataByCoordinates(double lat, double lng) async {
    _isLoading = true;
    _errorMessage = null;
    _weatherData = null;
    notifyListeners();

    String WEATHER_API_KEY = dotenv.env['WEATHER_API_KEY'] ?? '';
    String baseURL = 'https://api.openweathermap.org/data/2.5/weather';
    String request = '$baseURL?lat=$lat&lon=$lng&units=metric&appid=$WEATHER_API_KEY';

    try {
      var response = await http.get(Uri.parse(request));
      var data = json.decode(response.body);

      if (response.statusCode == 200) {
        _weatherData = data;
        _isLoading = false;
        notifyListeners();
      } else {
        _errorMessage = 'Error fetching weather: ${data['message'] ?? 'Location not found'}';
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Error getting weather: $e';
      _isLoading = false;
      notifyListeners();
    }
  }
}