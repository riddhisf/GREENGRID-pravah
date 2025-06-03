// ignore_for_file: use_build_context_synchronously
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pravah/components/custom_appbar.dart';
import 'package:pravah/components/custom_navbar.dart';
import 'package:pravah/components/custom_snackbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:pravah/main.dart';

void updateCarbonFootprint(String value) {
  globalCarbonFootprint = value;
}


class FootprintPage extends StatefulWidget {
  const FootprintPage({super.key});

  @override
  State<FootprintPage> createState() => _FootprintPageState();
}

class _FootprintPageState extends State<FootprintPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;

  // CO2 reduction data
  Map<String, double> _monthlyCO2Savings = {
    'solar': 0.0,
    'wind': 0.0,
    'geothermal': 0.0,
    'biomass': 0.0,
  };

  // For daily bar chart
  List<double> _dailyValues = [];
  List<String> _dailyLabels = [];

  // CO2 reduction factors (kg CO2 saved per kWh)
  final Map<String, double> _co2Factors = {
    'solar': 0.5, // 0.5 kg CO2 saved per kWh
    'wind': 0.48, // 0.48 kg CO2 saved per kWh
    'geothermal': 0.12, // 0.12 kg CO2 saved per kWh
    'biomass': 0.23, // 0.23 kg CO2 saved per kWh
  };

  // Colors for each energy source
  final Map<String, Color> _sourceColors = {
    'geothermal': Colors.teal,
    'solar': Colors.amber,
    'wind': Colors.blue,
    'biomass': Colors.brown,
  };

  // For chart display
  double _totalMonthlySavings = 0.0;
  int _selectedPieChartIndex = -1;
  String _timeRange = 'Daily'; // Options: 'Daily', 'Weekly', 'Monthly'
  double _maxDailyValue = 10.0; // Default max value for the bar chart

  @override
  void initState() {
    super.initState();
    _loadData();
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

    _calculateTotalSavings();

    setState(() {
      _isLoading = false;
    });
  }

  // Calculate total CO2 savings
  void _calculateTotalSavings() {
    _totalMonthlySavings = _monthlyCO2Savings.values.fold(0, (sum, value) => sum + value);
    updateCarbonFootprint(_totalMonthlySavings.toStringAsFixed(2));

    // Calculate max daily value for the bar chart
    if (_dailyValues.isNotEmpty) {
      _maxDailyValue = _dailyValues.reduce((max, value) => value > max ? value : max) * 1.2;
      _maxDailyValue = _maxDailyValue < 5 ? 5.0 : _maxDailyValue; // Set a minimum for better visualization
    } else {
      _maxDailyValue = 10.0; // Default if no data
    }
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

          // Reset values
          _monthlyCO2Savings = {
            'solar': 0.0,
            'wind': 0.0,
            'geothermal': 0.0,
            'biomass': 0.0,
          };
          _dailyValues = [];
          _dailyLabels = [];

          // Get current month
          DateTime now = DateTime.now();
          String currentMonth = DateFormat('yyyy-MM').format(now);

          // Filter records for current month
          List<dynamic> monthlyRecords = records.where((record) {
            String recordDate = record['date'].toString();
            return recordDate.startsWith(currentMonth);
          }).toList();

          // Sort records by date
          monthlyRecords.sort((a, b) {
            return DateTime.parse(a['date']).compareTo(DateTime.parse(b['date']));
          });

          // Process monthly data for pie chart and daily data for bar chart
          for (var record in monthlyRecords) {
            double solarValue = (record['solar'] as num).toDouble();
            double windValue = (record['wind'] as num).toDouble();
            double geothermalValue = (record['geothermal'] as num).toDouble();
            double biomassValue = (record['biomass'] as num).toDouble();

            // Update monthly totals
            _monthlyCO2Savings['solar'] = _monthlyCO2Savings['solar']! + (solarValue * _co2Factors['solar']!);
            _monthlyCO2Savings['wind'] = _monthlyCO2Savings['wind']! + (windValue * _co2Factors['wind']!);
            _monthlyCO2Savings['geothermal'] = _monthlyCO2Savings['geothermal']! + (geothermalValue * _co2Factors['geothermal']!);
            _monthlyCO2Savings['biomass'] = _monthlyCO2Savings['biomass']! + (biomassValue * _co2Factors['biomass']!);

            // Process daily data for bar chart
            DateTime recordDate = DateTime.parse(record['date']);
            double totalDailySavings = (solarValue * _co2Factors['solar']!) +
                (windValue * _co2Factors['wind']!) +
                (geothermalValue * _co2Factors['geothermal']!) +
                (biomassValue * _co2Factors['biomass']!);

            _dailyValues.add(totalDailySavings);
            _dailyLabels.add(DateFormat('d').format(recordDate)); // Just the day number
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

        // Reset values
        _monthlyCO2Savings = {
          'solar': 0.0,
          'wind': 0.0,
          'geothermal': 0.0,
          'biomass': 0.0,
        };
        _dailyValues = [];
        _dailyLabels = [];

        // Get current month
        DateTime now = DateTime.now();
        String currentMonth = DateFormat('yyyy-MM').format(now);

        // Filter records for current month
        List<dynamic> monthlyRecords = records.where((record) {
          String recordDate = record['date'].toString();
          return recordDate.startsWith(currentMonth);
        }).toList();

        // Sort records by date
        monthlyRecords.sort((a, b) {
          return DateTime.parse(a['date']).compareTo(DateTime.parse(b['date']));
        });

        // Process monthly data for pie chart and daily data for bar chart
        for (var record in monthlyRecords) {
          double solarValue = (record['solar'] as num).toDouble();
          double windValue = (record['wind'] as num).toDouble();
          double geothermalValue = (record['geothermal'] as num).toDouble();
          double biomassValue = (record['biomass'] as num).toDouble();

          // Update monthly totals
          _monthlyCO2Savings['solar'] = _monthlyCO2Savings['solar']! + (solarValue * _co2Factors['solar']!);
          _monthlyCO2Savings['wind'] = _monthlyCO2Savings['wind']! + (windValue * _co2Factors['wind']!);
          _monthlyCO2Savings['geothermal'] = _monthlyCO2Savings['geothermal']! + (geothermalValue * _co2Factors['geothermal']!);
          _monthlyCO2Savings['biomass'] = _monthlyCO2Savings['biomass']! + (biomassValue * _co2Factors['biomass']!);

          // Process daily data for bar chart
          DateTime recordDate = DateTime.parse(record['date']);
          double totalDailySavings = (solarValue * _co2Factors['solar']!) +
              (windValue * _co2Factors['wind']!) +
              (geothermalValue * _co2Factors['geothermal']!) +
              (biomassValue * _co2Factors['biomass']!);

          _dailyValues.add(totalDailySavings);
          _dailyLabels.add(DateFormat('d').format(recordDate)); // Just the day number
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
      appBar: CustomAppBar(title: Icon(Icons.factory,color: Color(0xFF0B2732),)),
      drawer: CustomDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          physics: const AlwaysScrollableScrollPhysics(),
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
                    'Carbon Footprint Tracker',
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

              Card(child:const Padding(
                padding: EdgeInsets.symmetric(vertical: 1.0),
                child: Text(
                  '% Contribution by your generation',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFF5F5DC),
                  ),
                ),
              )),

              // Pie Chart Card
              Card(
                elevation: 2,
                color: const Color(0xFFF5F5DC),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Chart with Legend
                      Row(
                        children: [
                          // Main Pie Chart Area
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 200,
                              child: _totalMonthlySavings <= 0
                                  ? Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.grey.shade300,
                                ),
                                child: const Center(
                                  child: Text(
                                    'No Data\nAvailable',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFF0B2732),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              )
                                  : Stack(
                                children: [

                                  PieChart(
                                    PieChartData(
                                      pieTouchData: PieTouchData(
                                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                          setState(() {
                                            if (!event.isInterestedForInteractions ||
                                                pieTouchResponse == null ||
                                                pieTouchResponse.touchedSection == null) {
                                              _selectedPieChartIndex = -1;
                                              return;
                                            }
                                            _selectedPieChartIndex =
                                                pieTouchResponse.touchedSection!.touchedSectionIndex;
                                          });
                                        },
                                      ),
                                      borderData: FlBorderData(show: false),
                                      sectionsSpace: 0,
                                      centerSpaceRadius: 40,
                                      sections: _buildPieChartSections(),
                                    ),
                                  ),
                                  Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '${_totalMonthlySavings.toStringAsFixed(1)}',
                                          style: const TextStyle(
                                            color: Color(0xFF0B2732),
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const Text(
                                          'kg CO₂',
                                          style: TextStyle(
                                            color: Color(0xFF0B2732),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                ],
                              ),
                            ),
                          ),

                          // Legend
                          Expanded(
                            flex: 1,
                            child: Container(
                              padding: const EdgeInsets.all(2.2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0B2732),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _legendItem('Geothermal', _sourceColors['geothermal']!),
                                  const SizedBox(height: 4),
                                  _legendItem('Solar', _sourceColors['solar']!),
                                  const SizedBox(height: 4),
                                  _legendItem('Wind', _sourceColors['wind']!),
                                  const SizedBox(height: 4),
                                  _legendItem('Biomass', _sourceColors['biomass']!),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Card(child:const Padding(
                padding: EdgeInsets.symmetric(vertical: 1.0),
                child: Text(
                  'Daily kg CO2 reduced',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFF5F5DC),
                  ),
                ),
              )),

              // Simple Bar Chart Card
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
                      // Time Range Selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF0B2732),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: Text(
                              _timeRange,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Bar Chart with Manual Implementation
                      SizedBox(
                        height: 150,
                        child: _dailyValues.isEmpty
                            ? const Center(
                          child: Text(
                            'No daily data available',
                            style: TextStyle(
                              color: Color(0xFF0B2732),
                            ),
                          ),
                        )
                            : _buildSimpleBarChart(),
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
      ),
      bottomNavigationBar: BottomNavBar(selectedIndex: 2),
    );
  }

  // Build a simple manual bar chart to avoid tooltip errors
  Widget _buildSimpleBarChart() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Y-axis line
        Container(
          width: 1,
          height: 130,
          color: const Color(0xFF0B2732),
        ),

        // Bars
        Expanded(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // X-axis line
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 1,
                  color: const Color(0xFF0B2732),
                ),
              ),

              // Bars
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_dailyValues.length, (index) {
                  // Calculate height based on value (0-100% of available height)
                  double percentage = _dailyValues[index] / _maxDailyValue;
                  double height = 130 * percentage;

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Bar
                      Container(
                        width: 12,
                        height: height,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(3),
                            topRight: Radius.circular(3),
                          ),
                        ),
                      ),

                      // Label
                      const SizedBox(height: 4),
                      Text(
                        _dailyLabels[index],
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF0B2732),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Build pie chart sections
  List<PieChartSectionData> _buildPieChartSections() {
    List<PieChartSectionData> sections = [];
    int i = 0;

    // Sort entries for consistent ordering
    List<MapEntry<String, double>> sortedEntries = _monthlyCO2Savings.entries.toList();
    sortedEntries.sort((a, b) => a.key.compareTo(b.key));

    for (var entry in sortedEntries) {
      String source = entry.key;
      double value = entry.value;

      final isTouched = i == _selectedPieChartIndex;
      final double fontSize = isTouched ? 20.0 : 14.0;
      final double radius = isTouched ? 60.0 : 50.0;
      final Color color = _sourceColors[source] ?? Colors.grey;

      if (value > 0 && _totalMonthlySavings > 0) {
        sections.add(
          PieChartSectionData(
            color: color,
            value: value,
            title: value > _totalMonthlySavings * 0.1 ? '${(value / _totalMonthlySavings * 100).toStringAsFixed(0)}%' : '',
            radius: radius,
            titleStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      }

      i++;
    }

    // If no sections, add a placeholder
    if (sections.isEmpty) {
      sections.add(
        PieChartSectionData(
          color: Colors.grey.shade300,
          value: 1,
          title: '',
          radius: 50,
          titleStyle: const TextStyle(
            color: Colors.transparent,
          ),
        ),
      );
    }

    return sections;
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
}