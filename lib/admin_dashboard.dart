import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AdminDashboard extends StatefulWidget {
  final String department;
  final String? state;

  const AdminDashboard({
    Key? key,
    required this.department,
    this.state,
  }) : super(key: key);

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  @override
  Widget build(BuildContext context) {
    final darkGreenColor = Color(0xFF1B5E20);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Admin Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: darkGreenColor,
        iconTheme: IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              // Sign out and navigate back to welcome page
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Department Information',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Divider(),
                    Text('Department: ${widget.department}'),
                    if (widget.state != null) Text('State: ${widget.state}'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Recent Incidents',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Expanded(
              child: Center(
                child: Text('Incident data will be displayed here'),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 