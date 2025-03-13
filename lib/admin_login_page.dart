import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'admin_dashboard.dart';

class AdminLoginPage extends StatefulWidget {
  final String department;
  final String? state;
  
  const AdminLoginPage({
    Key? key, 
    required this.department, 
    this.state,
  }) : super(key: key);

  @override
  _AdminLoginPageState createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createInitialAdminIfNeeded(String uid, String email) async {
    try {
      // Check if any admin exists
      QuerySnapshot adminQuery = await FirebaseFirestore.instance
          .collection('admins')
          .limit(1)
          .get();

      // If no admins exist, create the first admin
      if (adminQuery.docs.isEmpty) {
        await FirebaseFirestore.instance
            .collection('admins')
            .doc(uid)
            .set({
              'email': email,
              'departments': [widget.department],
              'currentDepartment': widget.department,
              'currentState': widget.state,
              'createdAt': FieldValue.serverTimestamp(),
              'isRootAdmin': true,
              'type': 'admin',
            });
        return;
      }

      // If admins exist, check if this email is in allowed admins
      QuerySnapshot adminDoc = await FirebaseFirestore.instance
          .collection('admins')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (adminDoc.docs.isEmpty) {
        // Create admin document if email exists but document doesn't
        await FirebaseFirestore.instance
            .collection('admins')
            .doc(uid)
            .set({
              'email': email,
              'departments': [widget.department],
              'currentDepartment': widget.department,
              'currentState': widget.state,
              'createdAt': FieldValue.serverTimestamp(),
              'type': 'admin',
            });
      }
    } catch (e) {
      print('Error creating admin: $e');
    }
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Attempt to sign in with Firebase
        UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        
        // Create admin document if needed
        await _createInitialAdminIfNeeded(
          userCredential.user!.uid,
          _emailController.text.trim(),
        );
        
        // Check if user exists in admins collection
        DocumentSnapshot adminDoc = await FirebaseFirestore.instance
            .collection('admins')
            .doc(userCredential.user!.uid)
            .get();
            
        if (adminDoc.exists) {
          Map<String, dynamic> adminData = adminDoc.data() as Map<String, dynamic>;
          List<String> allowedDepartments = List<String>.from(adminData['departments'] ?? []);
          String? assignedState = adminData['currentState'];
          
          // Check if admin has access to the selected department
          if (allowedDepartments.contains(widget.department)) {
            // Check if state matches for state-specific departments
            bool isStateSpecificDepartment = widget.department == 'State Vigilance & Anti-Corruption Bureau' || 
                                           widget.department == 'Urban Local Bodies (ULB) / Municipal Corporations';
            
            if (isStateSpecificDepartment) {
              // Verify state matches
              if (assignedState != widget.state) {
                await FirebaseAuth.instance.signOut();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('You do not have access to this state. Please select your assigned state.'),
                    backgroundColor: Colors.red,
                  ),
                );
                setState(() => _isLoading = false);
                return;
              }
            }

            // Update admin's current department and state
            await FirebaseFirestore.instance
                .collection('admins')
                .doc(userCredential.user!.uid)
                .update({
                  'currentDepartment': widget.department,
                  'currentState': widget.state,
                  'lastLogin': FieldValue.serverTimestamp(),
                });
                
            // Navigate to admin dashboard
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => AdminDashboard(
                  department: widget.department,
                  state: widget.state,
                ),
              ),
            );
          } else {
            // Admin exists but doesn't have access to this department
            await FirebaseAuth.instance.signOut();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('You do not have access to this department'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          // User exists but is not an admin
          await FirebaseAuth.instance.signOut();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You do not have administrator privileges'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } on FirebaseAuthException catch (e) {
        String message = 'An error occurred. Please try again.';
        if (e.code == 'user-not-found') {
          message = 'No user found with this email.';
        } else if (e.code == 'wrong-password') {
          message = 'Incorrect password.';
        } else if (e.code == 'invalid-email') {
          message = 'Please enter a valid email address.';
        } else if (e.code == 'user-disabled') {
          message = 'This account has been disabled.';
        } else if (e.code == 'too-many-requests') {
          message = 'Too many attempts. Please try again later.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final darkGreenColor = Color(0xFF1B5E20);
    final screenWidth = MediaQuery.of(context).size.width;
    final contentWidth = screenWidth > 600 ? 600.0 : screenWidth * 0.9;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Admin Login',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: darkGreenColor,
        iconTheme: IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: contentWidth,
            padding: EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Department and State Info Card
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(bottom: 24),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.business, color: darkGreenColor, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Department',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: EdgeInsets.only(left: 28, top: 4),
                        child: Text(
                          widget.department,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      if (widget.state != null) ...[
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(Icons.location_on, color: darkGreenColor, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'State',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: EdgeInsets.only(left: 28, top: 4),
                          child: Text(
                            widget.state!,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Login Form
                Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Email field
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email, color: darkGreenColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: darkGreenColor, width: 2),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@') || !value.contains('.')) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),

                      // Password field
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock, color: darkGreenColor),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility : Icons.visibility_off,
                              color: darkGreenColor,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: darkGreenColor, width: 2),
                          ),
                        ),
                        obscureText: _obscurePassword,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 24),

                      // Login button
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: darkGreenColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Login',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 