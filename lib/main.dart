import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'welcome_page.dart';
import 'add_incident_page.dart';
import 'profile_page.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'firebase_options.dart';
import 'home_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'admin_login_page.dart';
import 'admin_department_selection_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Enable high refresh rate
  if (Platform.isAndroid) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIChangeCallback((systemOverlaysAreVisible) async {
      await SystemChannels.platform.invokeMethod('HapticFeedback.vibrate');
    });
  }
  
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      // Enable Firestore persistence
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      // Enable Auth persistence - this is the key change
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    }
  } catch (e) {
    print('Firebase initialization error: $e');
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jagrata',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'GoogleSans', // Set as default font for entire app
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: 'GoogleSans'),
          displayMedium: TextStyle(fontFamily: 'GoogleSans'),
          displaySmall: TextStyle(fontFamily: 'GoogleSans'),
          headlineLarge: TextStyle(fontFamily: 'GoogleSans'),
          headlineMedium: TextStyle(fontFamily: 'GoogleSans'),
          headlineSmall: TextStyle(fontFamily: 'GoogleSans'),
          titleLarge: TextStyle(fontFamily: 'GoogleSans'),
          titleMedium: TextStyle(fontFamily: 'GoogleSans'),
          titleSmall: TextStyle(fontFamily: 'GoogleSans'),
          bodyLarge: TextStyle(fontFamily: 'GoogleSans'),
          bodyMedium: TextStyle(fontFamily: 'GoogleSans'),
          bodySmall: TextStyle(fontFamily: 'GoogleSans'),
          labelLarge: TextStyle(fontFamily: 'GoogleSans'),
          labelMedium: TextStyle(fontFamily: 'GoogleSans'),
          labelSmall: TextStyle(fontFamily: 'GoogleSans'),
        ),
        pageTransitionsTheme: PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CustomPageTransitionBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        platform: TargetPlatform.android,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => AuthWrapper(),
        '/admin_login': (context) => AdminDepartmentSelectionPage(),
        '/main': (context) => MainScreen(),
      },
      onGenerateRoute: (settings) {
        // Handle any routes that aren't defined in the routes map
        return MaterialPageRoute(
          builder: (context) => AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasData) {
          return MainScreen();
        }
        
        return WelcomePage();
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = <Widget>[
    HomePage(),
    AddIncidentPage(),
    ProfilePage(onProfileUpdated: () {}),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
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
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue.shade300,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _checkProfileCompletion();
  }

  Future<void> _checkProfileCompletion() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      
      if (!userDoc.exists) {
        _redirectToProfile();
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      bool isProfileComplete = userData['name'] != null && 
                             userData['phone'] != null && 
                             userData['govtId'] != null &&
                             userData['country'] != null && 
                             userData['gender'] != null;

      if (!isProfileComplete) {
        _redirectToProfile();
      }
    }
  }

  void _redirectToProfile() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ProfilePage(
          onProfileUpdated: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => MainScreen()),
            );
          },
        ),
      ),
    );
  }
}

// Add this custom page transition builder
class CustomPageTransitionBuilder extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        ),
      ),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }
}
