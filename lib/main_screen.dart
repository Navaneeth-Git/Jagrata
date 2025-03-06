import 'package:flutter/material.dart';
import 'home_page.dart';
import 'add_incident_page.dart';
import 'profile_page.dart';
import 'admin_department_selection_page.dart';

class MainScreen extends StatefulWidget {
  @override
  MainScreenState createState() => MainScreenState();
}

// Make the state class public by removing the underscore
class MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  void setIndex(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void navigateToAdminSection(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AdminDepartmentSelectionPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomePage(),
          AddIncidentPage(),
          ProfilePage(onProfileUpdated: () {}),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: setIndex,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Report',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
} 