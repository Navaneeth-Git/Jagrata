import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'admin_login_page.dart';
import 'package:flutter/rendering.dart';

class AdminDepartmentSelectionPage extends StatefulWidget {
  @override
  _AdminDepartmentSelectionPageState createState() => _AdminDepartmentSelectionPageState();
}

class _AdminDepartmentSelectionPageState extends State<AdminDepartmentSelectionPage> {
  String? _selectedDepartment;
  String? _selectedState;
  final _formKey = GlobalKey<FormState>();
  
  // List of departments
  final List<String> departments = [
    'Central Vigilance Commission',
    'State Vigilance & Anti-Corruption Bureau',
    'Urban Local Bodies (ULB) / Municipal Corporations',
    'Chief Vigilance Officers (CVO)'
  ];
  
  // List of Indian states
  final List<String> indianStates = [
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
    'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka',
    'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya', 'Mizoram',
    'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu',
    'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
    'Andaman and Nicobar Islands', 'Chandigarh', 'Dadra and Nagar Haveli and Daman and Diu',
    'Delhi', 'Jammu and Kashmir', 'Ladakh', 'Lakshadweep', 'Puducherry'
  ];
  
  @override
  Widget build(BuildContext context) {
    final darkGreenColor = Color(0xFF1B5E20);
    final screenWidth = MediaQuery.of(context).size.width;
    final contentWidth = screenWidth > 600 ? 600.0 : screenWidth * 0.9;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Admin Department Selection',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: darkGreenColor,
        iconTheme: IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: contentWidth,
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Container(
                    margin: EdgeInsets.only(bottom: 40),
                    child: Column(
                      children: [
                        Icon(
                          Icons.admin_panel_settings,
                          size: 48,
                          color: darkGreenColor,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Select Your Department',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: darkGreenColor,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Choose your department to proceed with admin login',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // Department Dropdown
                  Container(
                    margin: EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Department',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedDepartment,
                          isExpanded: true,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            prefixIcon: Icon(Icons.business, color: darkGreenColor),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: darkGreenColor, width: 2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          items: departments.map((String department) {
                            return DropdownMenuItem<String>(
                              value: department,
                              child: Text(
                                department,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey[800],
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedDepartment = newValue;
                              _selectedState = null; // Reset state when department changes
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select your department';
                            }
                            return null;
                          },
                          icon: Icon(Icons.arrow_drop_down_circle, color: darkGreenColor),
                        ),
                      ],
                    ),
                  ),

                  // State Dropdown (Conditional)
                  if (_selectedDepartment == 'State Vigilance & Anti-Corruption Bureau' || 
                      _selectedDepartment == 'Urban Local Bodies (ULB) / Municipal Corporations')
                    Container(
                      margin: EdgeInsets.only(bottom: 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'State',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _selectedState,
                            isExpanded: true,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              prefixIcon: Icon(Icons.location_city, color: darkGreenColor),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: darkGreenColor, width: 2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            items: indianStates.map((String state) {
                              return DropdownMenuItem<String>(
                                value: state,
                                child: Text(
                                  state,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedState = newValue;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select your state';
                              }
                              return null;
                            },
                            icon: Icon(Icons.arrow_drop_down_circle, color: darkGreenColor),
                          ),
                        ],
                      ),
                    ),

                  // Buttons
                  Container(
                    margin: EdgeInsets.only(top: 16),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                // Check if state is required but not selected
                                if ((_selectedDepartment == 'State Vigilance & Anti-Corruption Bureau' || 
                                    _selectedDepartment == 'Urban Local Bodies (ULB) / Municipal Corporations') && 
                                    (_selectedState == null || _selectedState!.isEmpty)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Please select your state')),
                                  );
                                  return;
                                }
                                
                                // Navigate to login page with department and state info
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AdminLoginPage(
                                      department: _selectedDepartment!,
                                      state: _selectedState,
                                    ),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: darkGreenColor,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Continue to Login',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: darkGreenColor,
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            'Back to Home',
                            style: TextStyle(fontSize: 16),
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
      ),
    );
  }
} 