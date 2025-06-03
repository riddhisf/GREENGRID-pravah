// ignore_for_file: use_super_parameters, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:pravah/pages/footprint_page.dart';
import 'package:pravah/pages/home_page.dart';
import 'package:pravah/pages/suggesstions_page.dart';
import 'package:pravah/pages/track_page.dart';

import '../pages/suggesstions_page.dart';

class BottomNavBar extends StatefulWidget {
  final int selectedIndex;
  const BottomNavBar({Key? key, required this.selectedIndex}) : super(key: key);

  @override
  _BottomNavBarState createState() => _BottomNavBarState(); // Fixed asterisk syntax
}

class _BottomNavBarState extends State<BottomNavBar> {
  void _onItemTapped(int index) {
    if (index == widget.selectedIndex) return;
    switch (index) {
      case 0:
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => HomePage()));
        break;
      case 1:
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => TrackPage()));
        break;
      case 2:
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => FootprintPage()));
        break;
      case 3:
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) => SuggestionsPage())); // Fixed class name if needed
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: widget.selectedIndex,
      onTap: _onItemTapped,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Theme.of(context).colorScheme.primary,
      selectedItemColor: Theme.of(context).colorScheme.onPrimary,
      unselectedItemColor: Theme.of(context).colorScheme.surface,
      items: const [
        BottomNavigationBarItem(
            icon: Center(child: Icon(Icons.home)), label: ''),
        BottomNavigationBarItem(
            icon: Center(child: Icon(Icons.track_changes)), label: ''),
        BottomNavigationBarItem(
            icon: Center(
              child: Icon(Icons.eco),
            ),
            label: ''),
        BottomNavigationBarItem(
            icon: Center(child: Icon(Icons.lightbulb)), label: ''),
      ],
    );
  }
}