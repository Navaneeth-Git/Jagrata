import 'package:flutter/material.dart';
import 'login_page.dart';
import 'admin_login_page.dart'; // Ensure this is imported if you have an admin login page
import 'admin_department_selection_page.dart'; // Ensure this is imported if you have an admin department selection page

class WelcomePage extends StatelessWidget {
  const WelcomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Jagrata',
              style: TextStyle(
                fontSize: 48, // Large font size for the title
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40), // Space between title and buttons
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                );
              },
              child: const Text('Login as User'),
            ),
            const SizedBox(height: 20), // Space between buttons
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AdminDepartmentSelectionPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[200],
                foregroundColor: Colors.black87,
              ),
              child: Text('Login as Administrator'),
            ),
          ],
        ),
      ),
    );
  }
} 