// ignore_for_file: use_build_context_synchronously
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pravah/components/custom_appbar.dart';
import 'package:pravah/components/custom_navbar.dart';
import 'package:pravah/components/custom_snackbar.dart';
import 'dart:math';

class SuggestionsPage extends StatefulWidget {
  const SuggestionsPage({super.key});
  @override
  State<SuggestionsPage> createState() => _SuggestionsPageState();
}

class _SuggestionsPageState extends State<SuggestionsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Random _random = Random();

  // Lists of suggestions by category
  final List<Map<String, dynamic>> _solarSuggestions = [
    {
      'title': 'Install Solar Panels on Your Roof',
      'description': 'Installing solar panels can reduce your electricity bill by up to 70% and decrease your carbon footprint significantly. The average ROI is reached within 5-7 years.',
      'iconData': Icons.wb_sunny,
      'color': Colors.amber,
      'type': 'Solar Energy'
    },
    {
      'title': 'Use Solar-Powered Outdoor Lighting',
      'description': 'Solar garden lights charge during the day and provide illumination at night without any electricity costs. Theyre easy to install and require minimal maintenance.',
      'iconData': Icons.lightbulb_outline,
      'color': Colors.amber,
      'type': 'Solar Energy'
    },
    {
      'title': 'Solar Water Heating Systems',
      'description': 'A solar water heater can provide up to 80% of your hot water needs, significantly reducing energy consumption and utility bills.',
      'iconData': Icons.water,
      'color': Colors.amber,
      'type': 'Solar Energy'
    },
  ];

  final List<Map<String, dynamic>> _windSuggestions = [
    {
      'title': 'Consider Small-Scale Wind Turbines',
      'description': 'If you live in a windy area, a small residential wind turbine can generate enough electricity to supplement your homes power needs and reduce reliance on the grid.',
      'iconData': Icons.air,
      'color': Colors.blue,
      'type': 'Wind Energy'
    },
    {
      'title': 'Support Community Wind Projects',
      'description': 'Participate in community-owned wind farm initiatives that allow residents to invest in and benefit from local renewable energy generation.',
      'iconData': Icons.people_outline,
      'color': Colors.blue,
      'type': 'Wind Energy'
    },
    {
      'title': 'Wind-Solar Hybrid Systems',
      'description': 'Combining wind and solar power in a hybrid system provides more consistent energy production throughout the day and different seasons.',
      'iconData': Icons.wb_sunny,
      'color': Colors.blue,
      'type': 'Wind Energy'
    },
  ];

  final List<Map<String, dynamic>> _geothermalSuggestions = [
    {
      'title': 'Install a Geothermal Heat Pump',
      'description': 'Geothermal heat pumps use the earths constant underground temperature to efficiently heat and cool your home, reducing energy costs by 30-70% compared to conventional systems.',
      'iconData': Icons.terrain,
      'color': Colors.teal,
      'type': 'Geothermal Energy'
    },
    {
      'title': 'Explore Geothermal for Hot Water',
      'description': 'Geothermal systems can provide hot water for your home in addition to heating and cooling, further reducing your energy consumption.',
      'iconData': Icons.hot_tub,
      'color': Colors.teal,
      'type': 'Geothermal Energy'
    },
    {
      'title': 'Geothermal for Pools and Spas',
      'description': 'Using geothermal energy to heat swimming pools and spas can extend your swimming season while minimizing energy costs and environmental impact.',
      'iconData': Icons.pool,
      'color': Colors.teal,
      'type': 'Geothermal Energy'
    },
  ];

  final List<Map<String, dynamic>> _biomassSuggestions = [
    {
      'title': 'Start Composting at Home',
      'description': 'Composting kitchen scraps and yard waste reduces landfill waste and produces nutrient-rich soil for your garden. Its an easy way to participate in biomass recycling.',
      'iconData': Icons.eco,
      'color': Colors.brown,
      'type': 'Biomass'
    },
    {
      'title': 'Consider Pellet Stoves for Heating',
      'description': 'Modern pellet stoves burn compressed wood or biomass pellets to create heat with very little air pollution, offering a renewable alternative to fossil fuels.',
      'iconData': Icons.fireplace,
      'color': Colors.brown,
      'type': 'Biomass'
    },
    {
      'title': 'Explore Biogas for Cooking',
      'description': 'Small-scale biogas digesters can convert kitchen waste and animal manure into cooking gas, providing a renewable energy source while reducing methane emissions.',
      'iconData': Icons.local_fire_department,
      'color': Colors.brown,
      'type': 'Biomass'
    },
  ];

  final List<Map<String, dynamic>> _rainwaterSuggestions = [
    {
      'title': 'Install Rain Barrels',
      'description': 'Collecting rainwater in barrels can provide free water for gardens and lawns. A single 55-gallon barrel can save up to 1,300 gallons of water during peak summer months.',
      'iconData': Icons.opacity,
      'color': Colors.lightBlue,
      'type': 'Rainwater Harvesting'
    },
    {
      'title': 'Create a Rain Garden',
      'description': 'Rain gardens capture runoff from roofs and driveways, preventing erosion and filtering pollutants while providing habitat for beneficial insects and birds.',
      'iconData': Icons.local_florist,
      'color': Colors.lightBlue,
      'type': 'Rainwater Harvesting'
    },
    {
      'title': 'Implement Permeable Paving',
      'description': 'Replace concrete driveways and pathways with permeable materials that allow rainwater to soak into the ground, reducing runoff and replenishing groundwater.',
      'iconData': Icons.grid_4x4,
      'color': Colors.lightBlue,
      'type': 'Rainwater Harvesting'
    },
  ];

  // Combined list for easy random selection
  late List<Map<String, dynamic>> _allSuggestions;

  // Randomly selected suggestions (one from each category)
  late List<Map<String, dynamic>> _selectedSuggestions;

  @override
  void initState() {
    super.initState();
    _allSuggestions = [
      ..._solarSuggestions,
      ..._windSuggestions,
      ..._geothermalSuggestions,
      ..._biomassSuggestions,
      ..._rainwaterSuggestions,
    ];
    _generateRandomSuggestions();
  }

  // Generate random suggestions from each category
  void _generateRandomSuggestions() {
    _selectedSuggestions = [
      _solarSuggestions[_random.nextInt(_solarSuggestions.length)],
      _windSuggestions[_random.nextInt(_windSuggestions.length)],
      _geothermalSuggestions[_random.nextInt(_geothermalSuggestions.length)],
      _biomassSuggestions[_random.nextInt(_biomassSuggestions.length)]
    ];
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
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showCustomSnackbar(
          context,
          "No user signed in!",
          backgroundColor: const Color.fromARGB(255, 57, 2, 2),
        );
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B2732),
      appBar: CustomAppBar(title: Icon(Icons.lightbulb,color:Color(0xFF0B2732))),
      drawer: CustomDrawer(),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _generateRandomSuggestions();
          });
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                    'Sustainable Suggestions',
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

              // Suggestion Cards
              ..._selectedSuggestions.map((suggestion) =>
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: _buildSuggestionCard(suggestion),
                  )
              ).toList(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavBar(selectedIndex: 3),
    );
  }

  // Build a suggestion card - Fixed version
  Widget _buildSuggestionCard(Map<String, dynamic> suggestion) {
    // Safe access to map values
    final String title = suggestion['title'] as String? ?? 'Suggestion';
    final String description = suggestion['description'] as String? ?? 'No description available';
    final String type = suggestion['type'] as String? ?? 'General';
    final Color color = suggestion['color'] as Color? ?? Colors.green;

    // Safe access to IconData
    IconData iconData;
    try {
      iconData = suggestion['iconData'] as IconData? ?? Icons.eco;
    } catch (e) {
      // Fallback icon if there's an error
      iconData = Icons.eco;
    }

    return Card(
      elevation: 2,
      color: const Color(0xFFF5F5DC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row with icon
            Row(
              children: [
                Icon(
                  iconData,
                  color: color,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0B2732),
                    ),
                  ),
                ),
              ],
            ),

            // Type label
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  type,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Description
            Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF0B2732),
              ),
            ),
          ],
        ),
      ),
    );
  }
}