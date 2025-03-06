import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'welcome_page.dart'; // Import the WelcomePage

class ProfilePage extends StatefulWidget {
  final VoidCallback onProfileUpdated;

  const ProfilePage({Key? key, required this.onProfileUpdated}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _govtIdController = TextEditingController();
  String? _selectedCountry;
  String? _selectedGender;
  bool _isIndian = false;
  bool _isProfileComplete = false;
  bool _isLoading = true;
  String? _userName;
  String? _userEmail;
  String? _userPhone;
  int _retryCount = 0;
  static const int maxRetries = 3;

  final List<String> countries = [
    'Afghanistan', 'Albania', 'Algeria', 'Andorra', 'Angola', 'Antigua and Barbuda',
    'Argentina', 'Armenia', 'Australia', 'Austria', 'Azerbaijan', 'Bahamas',
    'Bahrain', 'Bangladesh', 'Barbados', 'Belarus', 'Belgium', 'Belize',
    'Benin', 'Bhutan', 'Bolivia', 'Bosnia and Herzegovina', 'Botswana', 'Brazil',
    'Brunei', 'Bulgaria', 'Burkina Faso', 'Burundi', 'Cabo Verde', 'Cambodia',
    'Cameroon', 'Canada', 'Central African Republic', 'Chad', 'Chile', 'China',
    'Colombia', 'Comoros', 'Congo', 'Costa Rica', 'Croatia', 'Cuba',
    'Cyprus', 'Czech Republic', 'Democratic Republic of the Congo', 'Denmark', 'Djibouti',
    'Dominica', 'Dominican Republic', 'Ecuador', 'Egypt', 'El Salvador', 'Equatorial Guinea',
    'Eritrea', 'Estonia', 'Eswatini', 'Ethiopia', 'Fiji', 'Finland',
    'France', 'Gabon', 'Gambia', 'Georgia', 'Germany', 'Ghana',
    'Greece', 'Grenada', 'Guatemala', 'Guinea', 'Guinea-Bissau', 'Guyana',
    'Haiti', 'Honduras', 'Hungary', 'Iceland', 'India', 'Indonesia',
    'Iran', 'Iraq', 'Ireland', 'Israel', 'Italy', 'Jamaica',
    'Japan', 'Jordan', 'Kazakhstan', 'Kenya', 'Kiribati', 'Kuwait',
    'Kyrgyzstan', 'Laos', 'Latvia', 'Lebanon', 'Lesotho', 'Liberia',
    'Libya', 'Liechtenstein', 'Lithuania', 'Luxembourg', 'Madagascar', 'Malawi',
    'Malaysia', 'Maldives', 'Mali', 'Malta', 'Marshall Islands', 'Mauritania',
    'Mauritius', 'Mexico', 'Micronesia', 'Moldova', 'Monaco', 'Mongolia',
    'Montenegro', 'Morocco', 'Mozambique', 'Myanmar', 'Namibia', 'Nauru',
    'Nepal', 'Netherlands', 'New Zealand', 'Nicaragua', 'Niger', 'Nigeria',
    'North Macedonia', 'Norway', 'Oman', 'Pakistan', 'Palau', 'Palestine',
    'Panama', 'Papua New Guinea', 'Paraguay', 'Peru', 'Philippines', 'Poland',
    'Portugal', 'Qatar', 'Romania', 'Russia', 'Rwanda', 'Saint Kitts and Nevis',
    'Saint Lucia', 'Saint Vincent and the Grenadines', 'Samoa', 'San Marino', 'Sao Tome and Principe',
    'Saudi Arabia', 'Senegal', 'Serbia', 'Seychelles', 'Sierra Leone', 'Singapore',
    'Slovakia', 'Slovenia', 'Solomon Islands', 'Somalia', 'South Africa', 'South Korea',
    'South Sudan', 'Spain', 'Sri Lanka', 'Sudan', 'Suriname', 'Sweden',
    'Switzerland', 'Syria', 'Taiwan', 'Tajikistan', 'Tanzania', 'Thailand',
    'Togo', 'Tonga', 'Trinidad and Tobago', 'Tunisia', 'Turkey', 'Turkmenistan',
    'Tuvalu', 'Uganda', 'Ukraine', 'United Arab Emirates', 'United Kingdom', 'United States',
    'Uruguay', 'Uzbekistan', 'Vanuatu', 'Vatican City', 'Venezuela', 'Vietnam',
    'Yemen', 'Zambia', 'Zimbabwe',
  ];

  final List<String> genders = [
    'Male',
    'Female',
    'Other',
  ];

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Delay the initial fetch slightly to ensure Firebase is ready
    Future.delayed(Duration(milliseconds: 500), () {
      _fetchUserProfile();
    });
  }

  Future<void> _fetchUserProfile() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get current user
      User? user = FirebaseAuth.instance.currentUser;
      
      // If no user, retry a few times before giving up
      if (user == null) {
        if (_retryCount < maxRetries) {
          _retryCount++;
          await Future.delayed(Duration(seconds: 1));
          _fetchUserProfile();
          return;
        } else {
          throw Exception('No authenticated user found');
        }
      }

      // Reset retry count if we have a user
      _retryCount = 0;

      // Get user document
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      if (userDoc.exists) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _userName = data['name'];
          _userEmail = data['email'] ?? user.email;
          _userPhone = data['phone'];
          _isProfileComplete = data['name'] != null && 
                             data['phone'] != null && 
                             data['govtId'] != null &&
                             data['country'] != null && 
                             data['gender'] != null;
        });
      } else {
        // If document doesn't exist but we have a user
        setState(() {
          _userEmail = user.email;
          _isProfileComplete = false;
        });
      }
    } catch (e) {
      print('Error fetching profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile. Please try again.'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _fetchUserProfile,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteAccount() async {
    setState(() {
      _isLoading = true;
    });
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Delete user data from Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
        
        // Delete user account
        await user.delete();

        // Navigate to WelcomePage
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => WelcomePage()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting account: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (!_isProfileComplete) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please complete your profile before proceeding.'),
              duration: Duration(seconds: 2),
            ),
          );
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            'Profile',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          backgroundColor: Theme.of(context).primaryColor,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _isProfileComplete
                    ? Container(
                        height: MediaQuery.of(context).size.height - 100,
                        child: Column(
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 50,
                                    backgroundColor: Colors.blue.shade100,
                                    child: Text(
                                      (_userName ?? '')[0].toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 40,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 20),
                                  Text(
                                    _userName ?? '',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    _userEmail ?? '',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    _userPhone ?? '',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton(
                                  onPressed: () async {
                                    await FirebaseAuth.instance.signOut();
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(builder: (context) => WelcomePage()),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade300,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    elevation: 2,
                                  ),
                                  child: Text(
                                    'Log Out',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 20),
                                ElevatedButton(
                                  onPressed: () => _deleteAccount(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade300,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    elevation: 2,
                                  ),
                                  child: Text(
                                    'Delete Account',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 20),
                          ],
                        ),
                      )
                    : Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: <Widget>[
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Name',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16.0),
                            TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Phone Number',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your phone number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16.0),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _govtIdController,
                                    decoration: const InputDecoration(
                                      labelText: 'Govt. ID Number',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your Govt. ID number';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.info_outline),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        content: const Text('Aadhar, Driving License, Passport, PAN Number'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16.0),
                            Row(
                              children: [
                                Checkbox(
                                  value: _isIndian,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      _isIndian = value!;
                                      if (_isIndian) {
                                        _selectedCountry = 'India'; // Automatically set to India if checked
                                      } else {
                                        _selectedCountry = null; // Reset if unchecked
                                      }
                                    });
                                  },
                                ),
                                const Text('Indian'),
                              ],
                            ),
                            const SizedBox(height: 16.0),
                            DropdownButtonFormField<String>(
                              value: _isIndian ? 'India' : _selectedCountry,
                              hint: const Text('Select Country'),
                              items: countries.map((String country) {
                                return DropdownMenuItem<String>(
                                  value: country,
                                  child: Text(country),
                                );
                              }).toList(),
                              onChanged: _isIndian
                                  ? null // Disable dropdown if marked as Indian
                                  : (String? newValue) {
                                      setState(() {
                                        _selectedCountry = newValue;
                                      });
                                    },
                              validator: (value) {
                                if (!_isIndian && (value == null || value.isEmpty)) {
                                  return 'Please select your country';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16.0),
                            DropdownButtonFormField<String>(
                              value: _selectedGender,
                              hint: const Text('Select Gender'),
                              items: genders.map((String gender) {
                                return DropdownMenuItem<String>(
                                  value: gender,
                                  child: Text(gender),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedGender = newValue;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select your gender';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () async {
                                if (_formKey.currentState!.validate()) {
                                  setState(() {
                                    _isLoading = true;
                                  });
                                  try {
                                    // Save the data to Firestore
                                    User? user = FirebaseAuth.instance.currentUser;
                                    if (user != null) {
                                      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                                        'name': _nameController.text,
                                        'phone': _phoneController.text,
                                        'govtId': _govtIdController.text,
                                        'country': _selectedCountry,
                                        'gender': _selectedGender,
                                        'isIndian': _isIndian,
                                        'email': user.email, // Include email in the database
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Profile updated successfully!')),
                                      );
                                      widget.onProfileUpdated(); // Notify HomePage of profile update
                                      _fetchUserProfile(); // Refresh profile data
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error saving profile: ${e.toString()}')),
                                    );
                                  } finally {
                                    setState(() {
                                      _isLoading = false;
                                    });
                                  }
                                }
                              },
                              child: const Text('Save Profile'),
                            ),
                          ],
                        ),
                      ),
          ),
        ),
      ),
    );
  }
}