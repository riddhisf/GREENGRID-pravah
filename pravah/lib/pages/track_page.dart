// ignore_for_file: use_build_context_synchronously
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pravah/components/custom_appbar.dart';
import 'package:pravah/components/custom_navbar.dart';
import 'package:pravah/components/custom_snackbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:pravah/main.dart';

void updatetodaySolar( String value) {
  globaldailySolar = value;
}
void updatetodayWind( String value) {
  globaldailyWind = value;
}
void updatetodayBiomass(String value) {
  globaldailyBiomass = value;
}
void updatetodayGeothermal( String value) {
  globaldailyGeothermal = value;
}


class TrackPage extends StatefulWidget {
  const TrackPage({super.key});
  @override
  State<TrackPage> createState() => _TrackPageState();
}

class _TrackPageState extends State<TrackPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Controllers for text fields
  final TextEditingController _solarController = TextEditingController();
  final TextEditingController _windController = TextEditingController();
  final TextEditingController _geothermalController = TextEditingController();
  final TextEditingController _biomassController = TextEditingController();

  // Energy data
  Map<String, dynamic> _energyData = {
    'date': DateTime.now().toString(),
    'solar': 0.0,
    'wind': 0.0,
    'geothermal': 0.0,
    'biomass': 0.0,
  };

  // For the graph
  List<FlSpot> _solarSpots = [];
  List<FlSpot> _windSpots = [];
  List<FlSpot> _geothermalSpots = [];
  List<FlSpot> _biomassSpots = [];
  double _maxY = 10.0; // Default max Y value
  double _minY = 0.0;  // Default min Y value
  bool _isLoading = true;
  bool _hasData = false; // Track if we have any data

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _solarController.dispose();
    _windController.dispose();
    _geothermalController.dispose();
    _biomassController.dispose();
    super.dispose();
  }

  // Load data from either Firebase or local storage
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final user = _auth.currentUser;
    if (user != null) {
      // User is logged in, load from Firebase
      await _loadFirebaseData(user.uid);
    } else {
      // User is not logged in, load from local storage
      await _loadLocalData();
    }

    setState(() {
      _isLoading = false;
    });
  }

  // Load data from Firebase
  Future<void> _loadFirebaseData(String userId) async {
    try {
      final docRef = _firestore.collection('energy_data').doc(userId);
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        Map<String, dynamic> data = docSnapshot.data() as Map<String, dynamic>;
        if (data.containsKey('records') && data['records'] is List) {
          List<dynamic> records = data['records'];
          _processDataForGraph(records);

          // Set today's data if it exists
          String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
          var todayRecord = records.lastWhere(
                  (record) => record['date'].toString().startsWith(today),
              orElse: () => null
          );

          if (todayRecord != null) {
            setState(() {
              _energyData = Map<String, dynamic>.from(todayRecord);
              _solarController.text = todayRecord['solar'].toString();
              _windController.text = todayRecord['wind'].toString();
              _geothermalController.text = todayRecord['geothermal'].toString();
              _biomassController.text = todayRecord['biomass'].toString();
              updatetodaySolar(_solarController.text);
              updatetodayWind(_windController.text);
              updatetodayBiomass(_biomassController.text);
              updatetodayGeothermal(_geothermalController.text);
            });
          }
        }
      }
    } catch (e) {
      print('Error loading Firebase data: $e');
      showCustomSnackbar(
        context,
        "Failed to load data from Firebase.",
        backgroundColor: const Color.fromARGB(255, 57, 2, 2),
      );
    }
  }

  // Load data from local storage
  Future<void> _loadLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? recordsJson = prefs.getString('energy_records');

      if (recordsJson != null) {
        List<dynamic> records = jsonDecode(recordsJson);
        _processDataForGraph(records);

        // Set today's data if it exists
        String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        var todayRecord = records.lastWhere(
                (record) => record['date'].toString().startsWith(today),
            orElse: () => null
        );

        if (todayRecord != null) {
          setState(() {
            _energyData = Map<String, dynamic>.from(todayRecord);
            _solarController.text = todayRecord['solar'].toString();
            _windController.text = todayRecord['wind'].toString();
            _geothermalController.text = todayRecord['geothermal'].toString();
            _biomassController.text = todayRecord['biomass'].toString();
            updatetodaySolar(_solarController.text);
            updatetodayWind(_windController.text);
            updatetodayBiomass(_biomassController.text);
            updatetodayGeothermal(_geothermalController.text);

          });
        }
      }
    } catch (e) {
      print('Error loading local data: $e');
      showCustomSnackbar(
        context,
        "Failed to load local data.",
        backgroundColor: const Color.fromARGB(255, 57, 2, 2),
      );
    }
  }

  // Process the data for the graph with improved min/max calculation
  void _processDataForGraph(List<dynamic> records) {
    _solarSpots = [];
    _windSpots = [];
    _geothermalSpots = [];
    _biomassSpots = [];

    // Set default values
    double maxValue = 1.0; // Start with small default
    double minValue = 0.0;

    // Check if we have any records
    if (records.isEmpty) {
      setState(() {
        _hasData = false;
        _maxY = 10.0; // Default max for empty chart
        _minY = 0.0;
      });
      return;
    }

    // Only show the last 7 days
    List<dynamic> recentRecords = records.length > 7
        ? records.sublist(records.length - 7)
        : records;

    // Sort records by date to ensure proper ordering
    recentRecords.sort((a, b) {
      return DateTime.parse(a['date']).compareTo(DateTime.parse(b['date']));
    });

    // Process each record for the graph
    List<double> allValues = [];

    for (int i = 0; i < recentRecords.length; i++) {
      var record = recentRecords[i];

      // Extract values with safe conversion
      double solarValue = _safeConvertToDouble(record['solar']);
      double windValue = _safeConvertToDouble(record['wind']);
      double geothermalValue = _safeConvertToDouble(record['geothermal']);
      double biomassValue = _safeConvertToDouble(record['biomass']);

      // Add to spots for chart
      _solarSpots.add(FlSpot(i.toDouble(), solarValue));
      _windSpots.add(FlSpot(i.toDouble(), windValue));
      _geothermalSpots.add(FlSpot(i.toDouble(), geothermalValue));
      _biomassSpots.add(FlSpot(i.toDouble(), biomassValue));

      // Collect all values for min/max calculation
      allValues.addAll([solarValue, windValue, geothermalValue, biomassValue]);
    }

    // Find min and max values
    if (allValues.isNotEmpty) {
      maxValue = allValues.reduce(max);
      minValue = allValues.reduce(min);

      // Ensure we have reasonable values for graph display
      if (maxValue == minValue) {
        // If all values are the same, create a range around that value
        maxValue = maxValue + (maxValue > 0 ? maxValue * 0.2 : 2.0);
        minValue = max(0, minValue - (minValue > 0 ? minValue * 0.2 : 0.5));
      } else {
        // Add some padding to the max and min values
        double range = maxValue - minValue;
        maxValue = maxValue + (range * 0.2);
        minValue = max(0, minValue - (range * 0.1));
      }
    }

    setState(() {
      _hasData = recentRecords.isNotEmpty;
      _maxY = maxValue;
      _minY = minValue;
    });
  }

  // Safely convert to double
  double _safeConvertToDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    } else if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  // Save current data
  Future<void> _saveData() async {
    // Update the energy data with current text field values
    _energyData = {
      'date': DateTime.now().toString(),
      'solar': double.tryParse(_solarController.text) ?? 0.0,
      'wind': double.tryParse(_windController.text) ?? 0.0,
      'geothermal': double.tryParse(_geothermalController.text) ?? 0.0,
      'biomass': double.tryParse(_biomassController.text) ?? 0.0,
    };

    final user = _auth.currentUser;
    if (user != null) {
      // User is logged in, save to Firebase
      await _saveToFirebase(user.uid);
    } else {
      // User is not logged in, save locally
      await _saveLocally();
    }

    // Reload data to update the graph
    await _loadData();

    showCustomSnackbar(
      context,
      "Energy data saved successfully!",
      backgroundColor: const Color.fromARGB(255, 2, 57, 24),
    );
  }

  // Save data to Firebase
  Future<void> _saveToFirebase(String userId) async {
    try {
      final docRef = _firestore.collection('energy_data').doc(userId);
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        Map<String, dynamic> data = docSnapshot.data() as Map<String, dynamic>;
        List<dynamic> records = data.containsKey('records') ? List.from(data['records']) : [];

        // Check if today's record already exists
        String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        int existingIndex = records.indexWhere(
                (record) => record['date'].toString().startsWith(today)
        );

        if (existingIndex >= 0) {
          // Update existing record
          records[existingIndex] = _energyData;
        } else {
          // Add new record
          records.add(_energyData);
        }

        await docRef.update({
          'records': records,
          'updated_at': DateTime.now().toString()
        });
      } else {
        // Create new document
        await docRef.set({
          'user_id': userId,
          'records': [_energyData],
          'created_at': DateTime.now().toString(),
          'updated_at': DateTime.now().toString()
        });
      }
    } catch (e) {
      print('Error saving to Firebase: $e');
      showCustomSnackbar(
        context,
        "Failed to save data to Firebase.",
        backgroundColor: const Color.fromARGB(255, 57, 2, 2),
      );
    }
  }

  // Save data locally
  Future<void> _saveLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? recordsJson = prefs.getString('energy_records');

      List<dynamic> records = [];
      if (recordsJson != null) {
        records = jsonDecode(recordsJson);
      }

      // Check if today's record already exists
      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      int existingIndex = records.indexWhere(
              (record) => record['date'].toString().startsWith(today)
      );

      if (existingIndex >= 0) {
        // Update existing record
        records[existingIndex] = _energyData;
      } else {
        // Add new record
        records.add(_energyData);
      }

      await prefs.setString('energy_records', jsonEncode(records));
    } catch (e) {
      print('Error saving locally: $e');
      showCustomSnackbar(
        context,
        "Failed to save data locally.",
        backgroundColor: const Color.fromARGB(255, 57, 2, 2),
      );
    }
  }

  // Sign user out
  void signUserOut(BuildContext context) async {
    await _auth.signOut();
    showCustomSnackbar(
      context,
      "Signed out successfully!",
      backgroundColor: const Color.fromARGB(255, 2, 57, 24),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0B2732),
      appBar: CustomAppBar(title: Icon(Icons.energy_savings_leaf, color: Color(0xFF0B2732),)
      ),
      drawer: CustomDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Card
            Card(
              elevation: 2,
              color: const Color(0xFFF5F5DC),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Energy Tracking & Insights',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B2732),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Graph Card
            Card(
              elevation: 2,
              color: const Color(0xFFF5F5DC),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10.0),
                      child: Text(
                        'Your Weekly Energy Produced',
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B2732),
                        ),
                      ),
                    ),
                    // Graph with Legend
                    Row(
                      children: [
                        // Main Graph Area
                        Expanded(
                          flex: 3,
                          child: SizedBox(
                            height: 200,
                            child: _hasData
                                ? LineChart(
                              LineChartData(
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: true,
                                  horizontalInterval: (_maxY - _minY) / 5,
                                  verticalInterval: 1,
                                ),
                                titlesData: FlTitlesData(
                                  show: true,
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 40,
                                      getTitlesWidget: (value, meta) {
                                        // Only show a few labels
                                        if (value == _minY ||
                                            value == _maxY ||
                                            value == (_minY + _maxY) / 2) {
                                          return Text(
                                            value.toStringAsFixed(1),
                                            style: const TextStyle(
                                              color: Color(0xFF0B2732),
                                              fontSize: 10,
                                            ),
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                  ),
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: false,
                                    ),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        // Only show first and last day labels
                                        if (value == 0 || value == _solarSpots.length - 1) {
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 8.0),
                                            child: Text(
                                              value == 0 ? "First" : "Last",
                                              style: const TextStyle(
                                                color: Color(0xFF0B2732),
                                                fontSize: 10,
                                              ),
                                            ),
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                      reservedSize: 30,
                                    ),
                                  ),
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: false,
                                    ),
                                  ),
                                ),
                                borderData: FlBorderData(
                                  show: true,
                                  border: Border.all(color: const Color(0xFF0B2732), width: 1),
                                ),
                                minX: 0,
                                maxX: _solarSpots.isNotEmpty ? _solarSpots.length - 1.0 : 6.0,
                                minY: _minY,
                                maxY: _maxY,
                                lineBarsData: [
                                  // Geothermal Line
                                  LineChartBarData(
                                    spots: _geothermalSpots,
                                    isCurved: true,
                                    color: Colors.teal,
                                    barWidth: 3,
                                    isStrokeCapRound: true,
                                    dotData: FlDotData(show: true),
                                    belowBarData: BarAreaData(show: false),
                                  ),
                                  // Solar Line
                                  LineChartBarData(
                                    spots: _solarSpots,
                                    isCurved: true,
                                    color: Colors.orange,
                                    barWidth: 3,
                                    isStrokeCapRound: true,
                                    dotData: FlDotData(show: true),
                                    belowBarData: BarAreaData(show: false),
                                  ),
                                  // Wind Line
                                  LineChartBarData(
                                    spots: _windSpots,
                                    isCurved: true,
                                    color: Colors.lightBlue,
                                    barWidth: 3,
                                    isStrokeCapRound: true,
                                    dotData: FlDotData(show: true),
                                    belowBarData: BarAreaData(show: false),
                                  ),
                                  // Biomass Line
                                  LineChartBarData(
                                    spots: _biomassSpots,
                                    isCurved: true,
                                    color: Colors.brown,
                                    barWidth: 3,
                                    isStrokeCapRound: true,
                                    dotData: FlDotData(show: true),
                                    belowBarData: BarAreaData(show: false),
                                  ),
                                ],
                              ),
                            )
                                : Center(
                              child: Text(
                                "No data available yet.\nAdd energy data below to see your chart.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Legend

                      ],
                    ),
                  ],
                ),
              ),
            ),
            Card(
              elevation: 2,
              color: const Color(0xFFF5F5DC),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                padding: const EdgeInsets.all(2.2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B2732),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _legendItem('Geothermal', Colors.teal),
                    const SizedBox(width: 10),
                    _legendItem('Solar', Colors.orange),
                    const SizedBox(width: 10),
                    _legendItem('Wind', Colors.lightBlue),
                    const SizedBox(width: 10),
                    _legendItem('Biomass', Colors.brown),
                  ],
                ),
              ),

            ),


            const SizedBox(height: 16),

            // Input Form Card
            Card(
              elevation: 2,
              color: const Color(0xFFF5F5DC),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Your energy production for today',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0B2732),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Input fields
                    _energyInputRow('Solar Panels', _solarController),
                    const SizedBox(height: 8),
                    _energyInputRow('Wind Turbine', _windController),
                    const SizedBox(height: 8),
                    _energyInputRow('Geothermal', _geothermalController),
                    const SizedBox(height: 8),
                    _energyInputRow('Biomass', _biomassController),

                    const SizedBox(height: 16),

                    // Submit Button
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: _saveData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0B2732),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Submit'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Info Card
            Card(
              elevation: 2,
              color: const Color(0xFFF5F5DC),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF0B2732),
                    ),
                    children: [
                      const TextSpan(
                        text: 'Data is stored only on your device and will be lost if the app is deleted.\n',
                      ),
                      TextSpan(
                        text: user != null ? 'Logged In' : 'Register Now',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const TextSpan(
                        text: ' to sync and back up your energy records.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(selectedIndex: 1),
    );
  }

  // Helper method for legend items
  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // Helper method for input rows
  Widget _energyInputRow(String label, TextEditingController controller) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF0B2732),
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 32,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Color(0xFF0B2732)),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 8),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'kW',
          style: TextStyle(
            color: Color(0xFF0B2732),
          ),
        ),
      ],
    );
  }
}