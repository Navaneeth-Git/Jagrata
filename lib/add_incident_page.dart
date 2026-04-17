import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'main_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart' as app;


class AddIncidentPage extends StatefulWidget {
  final bool isProfileComplete; // New parameter for profile completion status
  final Function? onRequestProfileTab; // Add callback to request profile tab
  
  const AddIncidentPage({Key? key, this.isProfileComplete = false, this.onRequestProfileTab}) : super(key: key);
  
  @override
  _AddIncidentPageState createState() => _AddIncidentPageState();
}

class _AddIncidentPageState extends State<AddIncidentPage> {
  final _formKey = GlobalKey<FormState>();
  final List<TextEditingController> _nameControllers = [TextEditingController()];
  final TextEditingController _locationController = TextEditingController();

  final TextEditingController _otherIncidentTypeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _aiSummaryController = TextEditingController();
  final TextEditingController _severityController = TextEditingController();
  final TextEditingController _witnessesController = TextEditingController();

  String? _selectedIncidentType;
  DateTime? _incidentDate;
  TimeOfDay? _incidentTime;

  final List<String> incidentTypes = [
    'Bribery',
    'Embezzlement',
    'Fraud',
    'Abuse of Power',
    'Nepotism',
    'Other',
  ];

  final List<String> predefinedDepartments = [
    'ULB',
    'Central Vigilance Commission',
    'State Vigilance & Anti-Corruption Bureau', 
    'Chief Vigilance Officers'
  ];

  late final GenerativeModel _model;
  bool _isGeneratingAI = false;
  bool _isGeneratingSummary = false;

  List<PlatformFile> _attachedFiles = [];
  bool _isUploadingFiles = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Map<String, double> _uploadProgress = {};

  bool _isUploading = false;

  final ValueNotifier<Map<String, double>> _uploadProgressNotifier = ValueNotifier({});

  // Store dialog context at a class level
  BuildContext? _uploadDialogContext;

  // Add a new controller for the department field
  TextEditingController _departmentController = TextEditingController();

  // Add a new variable to store the list of departments based on severity
  List<String> _departmentsBasedOnSeverity = [];

  // Add this to your state variables
  String? _selectedDepartment = 'ULB';
  String? _selectedState;

  // Add this list of Indian states
  final List<String> indianStates = [
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chhattisgarh',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
    'Andaman and Nicobar Islands',
    'Chandigarh',
    'Dadra and Nagar Haveli and Daman and Diu',
    'Delhi',
    'Jammu and Kashmir',
    'Ladakh',
    'Lakshadweep',
    'Puducherry'
  ];

  // Add this variable to track the real-time profile status
  bool _isProfileComplete = false;

  // Add these missing variables in the _AddIncidentPageState class
  String? _selectedDistrict;
  TextEditingController _titleController = TextEditingController();

  // Modify the witnesses section to allow multiple witnesses like the officers section
  final List<TextEditingController> _witnessControllers = [TextEditingController()];

  @override
  void initState() {
    super.initState();
    // Start with the provided value
    _isProfileComplete = widget.isProfileComplete;
    // Then check the latest status from shared preferences
    _checkLatestProfileStatus();
    
    // Initialize Firebase VertexAI model
    _model = FirebaseVertexAI.instance.generativeModel(model: 'gemini-3-flash');
  }

  // Add this method to check the latest profile status
  Future<void> _checkLatestProfileStatus() async {
    try {
      // Get the latest status from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final isComplete = prefs.getBool('profile_complete') ?? false;
      
      print('AddIncidentPage - Latest profile status from prefs: $isComplete');
      
      // Also check the global variable
      final globalStatus = app.globalProfileComplete;
      print('AddIncidentPage - Global profile status: $globalStatus');
      
      // Use either source (prefer global for consistency)
      final finalStatus = globalStatus || isComplete;
      
      // Only update state if different from current
      if (finalStatus != _isProfileComplete) {
        setState(() {
          _isProfileComplete = finalStatus;
          print('AddIncidentPage - Updated profile status: $_isProfileComplete');
        });
      }
    } catch (e) {
      print('Error checking latest profile status: $e');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _incidentDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _incidentDate) {
      setState(() {
        _incidentDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null && picked != _incidentTime) {
      setState(() {
        _incidentTime = picked;
      });
    }
  }

  void _addNameField() {
    if (_nameControllers.length < 6) {
      setState(() {
        _nameControllers.add(TextEditingController());
      });
    }
  }

  void _removeNameField(int index) {
    if (_nameControllers.length > 1) {
      setState(() {
        _nameControllers.removeAt(index);
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled, don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    Position position = await Geolocator.getCurrentPosition();
    _locationController.text = '${position.latitude}, ${position.longitude}';
  }

  Future<void> _generateSummary() async {
    if (_descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a description first')),
      );
      return;
    }

    setState(() {
      _isGeneratingSummary = true;
    });

    try {
      // First prompt for structured analysis
    final analysisPrompt = [
  Content.text(
    '''Generate a formal and structured summary of the following incident report. 
    DO NOT use markdown formatting like **, ##, or any other special formatting characters.
    Don't use ## for headings as well. 
    The output should be in plaintext only with regular paragraph formatting and line breaks.
    Don't use any special characters like * or # for headings.
    
    Ensure that the summary is concise and clearly presents the key details in plain text. 
    If the report is in a non-English language, translate it into English before summarizing. 
    
    Include the following sections with plain text headings:

    Introduction:
    (Type of corruption involved and the time it occurred)

    Contextual Information:
    (Relevant details about the department, officials, or individuals involved)

    Impact Assessment:
    (Analysis of the severity and potential consequences)

    Detailed Explanation:
    (A brief yet comprehensive description of the incident, summarizing key points clearly)

    Incident Description:
    ${_descriptionController.text}
    '''
  )
];

final analysisResponse = await _model.generateContent(analysisPrompt);
final extractedSeverity = extractSeverityFromResponse(analysisResponse.text); // Function to extract severity from analysis

// Second prompt for severity classification, ensuring it matches the analysis response
final severityPrompt = [
  Content.text(
    '''Based on the following incident description, classify the severity as either "Low", "Moderate", "High", or "Critical".  
    Respond with ONLY ONE of these four severity levels.

    Incident Description:
    ${_descriptionController.text}
    '''
  )
];


      final severityResponse = await _model.generateContent(severityPrompt);
      
      setState(() {
        _aiSummaryController.text = analysisResponse.text ?? 'Unable to generate summary';
        // Clean and set the severity
        String severity = (severityResponse.text ?? 'Moderate')
            .trim()
            .split('\n')[0] // Take first line only
            .replaceAll(RegExp(r'[^a-zA-Z]'), ''); // Remove any special characters
        
        // Ensure the severity is one of the expected values
        final validSeverities = ['Low', 'Moderate', 'High', 'Critical'];
        if (validSeverities.contains(severity)) {
          _severityController.text = severity;
        } else {
          _severityController.text = 'Moderate'; // Default fallback
        }
      });
    } catch (e) {
      print('Error generating summary: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating AI summary: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isGeneratingSummary = false;
      });
    }
  }

  Widget _buildAISummaryField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'AI Structured Analysis',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    if (_isGeneratingSummary)
                      Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5B86E5)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                height: 300,
                padding: EdgeInsets.all(16),
                child: TextField(
                  controller: _aiSummaryController,
                  maxLines: null,
                  readOnly: true,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'AI summary will appear here',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenerateButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: [
            Color(0xFF7EB6FF), // Light blue
            Color(0xFF5B86E5), // Medium blue
            Color(0xFF36D1DC), // Cyan
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _isGeneratingSummary ? null : _generateSummary,
        icon: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.hexagon_outlined,
              size: 28,
              color: Colors.white,
            ),
            Icon(
              Icons.auto_awesome,
              size: 16,
              color: Colors.white,
            ),
          ],
        ),
        label: Text(
          'Generate Summary using AI',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Text(
          'Attachments',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // Attachment list
              if (_attachedFiles.isNotEmpty) ...[
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: _attachedFiles.length,
                  itemBuilder: (context, index) {
                    final file = _attachedFiles[index];
                    return ListTile(
                      leading: _getFileIcon(file.extension ?? ''),
                      title: Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        _formatFileSize(file.size),
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _attachedFiles.removeAt(index);
                          });
                        },
                      ),
                    );
                  },
                ),
                Divider(height: 1),
              ],
              // Add attachment button
              InkWell(
                onTap: _pickFiles,
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.attach_file,
                        color: Colors.blue.shade400,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Attach Files (Documents, Images, or Videos)',
                          style: TextStyle(
                            color: Colors.blue.shade400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (_attachedFiles.isNotEmpty) ...[
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_attachedFiles.length} file(s)',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_attachedFiles.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Total size: ${_formatFileSize(_attachedFiles.fold(0, (sum, file) => sum + file.size))}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx',
          'mp4', 'mov', 'avi', 'mkv'
        ],
        allowMultiple: true,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _attachedFiles = result.files;
        });

        // Debug information
        for (var file in result.files) {
          print('File picked:');
          print('Name: ${file.name}');
          print('Size: ${file.size}');
          print('Path: ${file.path}');
          print('Bytes available: ${file.bytes != null}');
        }
      }
    } catch (e) {
      print('Error picking files: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking files: ${e.toString()}')),
      );
    }
  }

  Widget _getFileIcon(String extension) {
    IconData iconData;
    Color iconColor;

    switch (extension.toLowerCase()) {
      case 'pdf':
        iconData = Icons.picture_as_pdf;
        iconColor = Colors.red;
        break;
      case 'doc':
      case 'docx':
        iconData = Icons.description;
        iconColor = Colors.blue;
        break;
      case 'jpg':
      case 'jpeg':
      case 'png':
        iconData = Icons.image;
        iconColor = Colors.green;
        break;
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
        iconData = Icons.video_file;
        iconColor = Colors.purple;
        break;
      default:
        iconData = Icons.insert_drive_file;
        iconColor = Colors.grey;
    }

    return Icon(iconData, color: iconColor);
  }

  String _formatFileSize(int size) {
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double dSize = size.toDouble();
    while (dSize > 1024 && i < suffixes.length - 1) {
      dSize /= 1024;
      i++;
    }
    return '${dSize.toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Just return without special handling
        return true;
      },
      child: Scaffold(
      appBar: AppBar(
          title: Text('Report Incident'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        body: _isProfileComplete ? _buildReportForm() : _buildProfileIncompleteMessage(),
      ),
    );
  }

  Widget _buildReportForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: AnimatedSize(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.shade500,
                        Colors.blue.shade700,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child: Icon(
                          Icons.report_problem_outlined,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Report Corruption Incident',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Your report helps us fight corruption. All information is kept confidential.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),
              
              // Names section
              _buildNamesSection(),
              SizedBox(height: 24),
              
              // State & District
              _buildStateDistrictSection(),
              SizedBox(height: 24),
              
              // Incident details
              _buildInputSection(),
              
              // Location
              SizedBox(height: 24),
              _buildLocationSection(),
              
              // Date & Time
              SizedBox(height: 24),
              _buildDateTimeSection(),
              
              // Witnesses section
              SizedBox(height: 24),
              _buildWitnessesSection(),
              
              // Evidence section
              SizedBox(height: 24),
              _buildAttachmentSection(),
              
              // Add padding before the submit button
              SizedBox(height: 40),
              
              // Submit button
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildNamesSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(
              'Officer Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            SizedBox(height: 16),
            
            // Names input
              ..._nameControllers.asMap().entries.map((entry) {
                int index = entry.key;
                TextEditingController controller = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: TextFormField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.info_outline),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  content: Text('Enter the name of the officer involved.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: Icon(index == 0 ? Icons.add : Icons.remove),
                            onPressed: index == 0
                                ? (_nameControllers.length < 6 ? _addNameField : null)
                                : () => _removeNameField(index),
                            color: index == 0 && _nameControllers.length >= 6
                                ? Colors.grey
                                : null,
                          ),
                        ],
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a name';
                      }
                      return null;
                    },
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStateDistrictSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Location Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            SizedBox(height: 16),
            
            // State dropdown
            _buildSmoothDropdown(
              label: 'State',
              value: _selectedState,
              items: indianStates,
              onChanged: (newValue) {
                setState(() {
                  _selectedState = newValue;
                  // Reset district when state changes
                  _selectedDistrict = null;
                });
              },
              prefixIcon: Icons.location_city,
            ),
            
            // District dropdown, only if state is selected
            if (_selectedState != null)
              AnimatedSize(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _buildSmoothDropdown(
                  label: 'District',
                  value: _selectedDistrict,
                  items: _getDistrictsForState(_selectedState!),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedDistrict = newValue;
                    });
                  },
                  prefixIcon: Icons.location_on,
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  // Helper method to get districts for a selected state
  List<String> _getDistrictsForState(String state) {
    // Default empty list to avoid null issues
    List<String> districts = [];
    
    // More comprehensive list of districts for each state
    switch (state) {
      case 'Andhra Pradesh':
        districts = ['Anantapur', 'Chittoor', 'East Godavari', 'Guntur', 'Krishna', 'Kurnool', 'Nellore', 'Prakasam', 'Srikakulam', 'Visakhapatnam', 'Vizianagaram', 'West Godavari', 'YSR Kadapa'];
        break;
      case 'Arunachal Pradesh':
        districts = ['Anjaw', 'Changlang', 'Dibang Valley', 'East Kameng', 'East Siang', 'Kamle', 'Kra Daadi', 'Kurung Kumey', 'Lepa Rada', 'Lohit', 'Longding', 'Lower Dibang Valley', 'Lower Siang', 'Lower Subansiri', 'Namsai', 'Pakke Kessang', 'Papum Pare', 'Shi Yomi', 'Siang', 'Tawang', 'Tirap', 'Upper Siang', 'Upper Subansiri', 'West Kameng', 'West Siang'];
        break;
      case 'Assam':
        districts = ['Baksa', 'Barpeta', 'Biswanath', 'Bongaigaon', 'Cachar', 'Charaideo', 'Chirang', 'Darrang', 'Dhemaji', 'Dhubri', 'Dibrugarh', 'Dima Hasao', 'Goalpara', 'Golaghat', 'Hailakandi', 'Hojai', 'Jorhat', 'Kamrup', 'Kamrup Metropolitan', 'Karbi Anglong', 'Karimganj', 'Kokrajhar', 'Lakhimpur', 'Majuli', 'Morigaon', 'Nagaon', 'Nalbari', 'Sivasagar', 'Sonitpur', 'South Salmara-Mankachar', 'Tinsukia', 'Udalguri', 'West Karbi Anglong'];
        break;
      case 'Bihar':
        districts = ['Araria', 'Arwal', 'Aurangabad', 'Banka', 'Begusarai', 'Bhagalpur', 'Bhojpur', 'Buxar', 'Darbhanga', 'East Champaran', 'Gaya', 'Gopalganj', 'Jamui', 'Jehanabad', 'Kaimur', 'Katihar', 'Khagaria', 'Kishanganj', 'Lakhisarai', 'Madhepura', 'Madhubani', 'Munger', 'Muzaffarpur', 'Nalanda', 'Nawada', 'Patna', 'Purnia', 'Rohtas', 'Saharsa', 'Samastipur', 'Saran', 'Sheikhpura', 'Sheohar', 'Sitamarhi', 'Siwan', 'Supaul', 'Vaishali', 'West Champaran'];
        break;
      case 'Chhattisgarh':
        districts = ['Balod', 'Baloda Bazar', 'Balrampur', 'Bastar', 'Bemetara', 'Bijapur', 'Bilaspur', 'Dantewada', 'Dhamtari', 'Durg', 'Gariaband', 'Janjgir-Champa', 'Jashpur', 'Kabirdham', 'Kanker', 'Kondagaon', 'Korba', 'Koriya', 'Mahasamund', 'Mungeli', 'Narayanpur', 'Raigarh', 'Raipur', 'Rajnandgaon', 'Sukma', 'Surajpur', 'Surguja'];
        break;
      case 'Goa':
        districts = ['North Goa', 'South Goa'];
        break;
      case 'Gujarat':
        districts = ['Ahmedabad', 'Amreli', 'Anand', 'Aravalli', 'Banaskantha', 'Bharuch', 'Bhavnagar', 'Botad', 'Chhota Udaipur', 'Dahod', 'Dang', 'Devbhoomi Dwarka', 'Gandhinagar', 'Gir Somnath', 'Jamnagar', 'Junagadh', 'Kheda', 'Kutch', 'Mahisagar', 'Mehsana', 'Morbi', 'Narmada', 'Navsari', 'Panchmahal', 'Patan', 'Porbandar', 'Rajkot', 'Sabarkantha', 'Surat', 'Surendranagar', 'Tapi', 'Vadodara', 'Valsad'];
        break;
      case 'Haryana':
        districts = ['Ambala', 'Bhiwani', 'Charkhi Dadri', 'Faridabad', 'Fatehabad', 'Gurugram', 'Hisar', 'Jhajjar', 'Jind', 'Kaithal', 'Karnal', 'Kurukshetra', 'Mahendragarh', 'Nuh', 'Palwal', 'Panchkula', 'Panipat', 'Rewari', 'Rohtak', 'Sirsa', 'Sonipat', 'Yamunanagar'];
        break;
      case 'Himachal Pradesh':
        districts = ['Bilaspur', 'Chamba', 'Hamirpur', 'Kangra', 'Kinnaur', 'Kullu', 'Lahaul and Spiti', 'Mandi', 'Shimla', 'Sirmaur', 'Solan', 'Una'];
        break;
      case 'Jharkhand':
        districts = ['Bokaro', 'Chatra', 'Deoghar', 'Dhanbad', 'Dumka', 'East Singhbhum', 'Garhwa', 'Giridih', 'Godda', 'Gumla', 'Hazaribagh', 'Jamtara', 'Khunti', 'Koderma', 'Latehar', 'Lohardaga', 'Pakur', 'Palamu', 'Ramgarh', 'Ranchi', 'Sahebganj', 'Seraikela-Kharsawan', 'Simdega', 'West Singhbhum'];
        break;
      case 'Karnataka':
        districts = ['Bagalkot', 'Ballari', 'Belagavi', 'Bengaluru Rural', 'Bengaluru Urban', 'Bidar', 'Chamarajanagar', 'Chikballapur', 'Chikkamagaluru', 'Chitradurga', 'Dakshina Kannada', 'Davanagere', 'Dharwad', 'Gadag', 'Hassan', 'Haveri', 'Kalaburagi', 'Kodagu', 'Kolar', 'Koppal', 'Mandya', 'Mysuru', 'Raichur', 'Ramanagara', 'Shivamogga', 'Tumakuru', 'Udupi', 'Uttara Kannada', 'Vijayapura', 'Yadgir'];
        break;
      case 'Kerala':
        districts = ['Alappuzha', 'Ernakulam', 'Idukki', 'Kannur', 'Kasaragod', 'Kollam', 'Kottayam', 'Kozhikode', 'Malappuram', 'Palakkad', 'Pathanamthitta', 'Thiruvananthapuram', 'Thrissur', 'Wayanad'];
        break;
      case 'Madhya Pradesh':
        districts = ['Agar Malwa', 'Alirajpur', 'Anuppur', 'Ashoknagar', 'Balaghat', 'Barwani', 'Betul', 'Bhind', 'Bhopal', 'Burhanpur', 'Chhatarpur', 'Chhindwara', 'Damoh', 'Datia', 'Dewas', 'Dhar', 'Dindori', 'Guna', 'Gwalior', 'Harda', 'Hoshangabad', 'Indore', 'Jabalpur', 'Jhabua', 'Katni', 'Khandwa', 'Khargone', 'Mandla', 'Mandsaur', 'Morena', 'Narsinghpur', 'Neemuch', 'Panna', 'Raisen', 'Rajgarh', 'Ratlam', 'Rewa', 'Sagar', 'Satna', 'Sehore', 'Seoni', 'Shahdol', 'Shajapur', 'Sheopur', 'Shivpuri', 'Sidhi', 'Singrauli', 'Tikamgarh', 'Ujjain', 'Umaria', 'Vidisha'];
        break;
      case 'Maharashtra':
        districts = ['Ahmednagar', 'Akola', 'Amravati', 'Aurangabad', 'Beed', 'Bhandara', 'Buldhana', 'Chandrapur', 'Dhule', 'Gadchiroli', 'Gondia', 'Hingoli', 'Jalgaon', 'Jalna', 'Kolhapur', 'Latur', 'Mumbai City', 'Mumbai Suburban', 'Nagpur', 'Nanded', 'Nandurbar', 'Nashik', 'Osmanabad', 'Palghar', 'Parbhani', 'Pune', 'Raigad', 'Ratnagiri', 'Sangli', 'Satara', 'Sindhudurg', 'Solapur', 'Thane', 'Wardha', 'Washim', 'Yavatmal'];
        break;
      case 'Manipur':
        districts = ['Bishnupur', 'Chandel', 'Churachandpur', 'Imphal East', 'Imphal West', 'Jiribam', 'Kakching', 'Kamjong', 'Kangpokpi', 'Noney', 'Pherzawl', 'Senapati', 'Tamenglong', 'Tengnoupal', 'Thoubal', 'Ukhrul'];
        break;
      case 'Meghalaya':
        districts = ['East Garo Hills', 'East Jaintia Hills', 'East Khasi Hills', 'North Garo Hills', 'Ri Bhoi', 'South Garo Hills', 'South West Garo Hills', 'South West Khasi Hills', 'West Garo Hills', 'West Jaintia Hills', 'West Khasi Hills'];
        break;
      case 'Mizoram':
        districts = ['Aizawl', 'Champhai', 'Hnahthial', 'Khawzawl', 'Kolasib', 'Lawngtlai', 'Lunglei', 'Mamit', 'Saiha', 'Saitual', 'Serchhip'];
        break;
      case 'Nagaland':
        districts = ['Dimapur', 'Kiphire', 'Kohima', 'Longleng', 'Mokokchung', 'Mon', 'Peren', 'Phek', 'Tuensang', 'Wokha', 'Zunheboto'];
        break;
      case 'Odisha':
        districts = ['Angul', 'Balangir', 'Balasore', 'Bargarh', 'Bhadrak', 'Boudh', 'Cuttack', 'Deogarh', 'Dhenkanal', 'Gajapati', 'Ganjam', 'Jagatsinghpur', 'Jajpur', 'Jharsuguda', 'Kalahandi', 'Kandhamal', 'Kendrapara', 'Kendujhar', 'Khordha', 'Koraput', 'Malkangiri', 'Mayurbhanj', 'Nabarangpur', 'Nayagarh', 'Nuapada', 'Puri', 'Rayagada', 'Sambalpur', 'Subarnapur', 'Sundargarh'];
        break;
      case 'Punjab':
        districts = ['Amritsar', 'Barnala', 'Bathinda', 'Faridkot', 'Fatehgarh Sahib', 'Fazilka', 'Ferozepur', 'Gurdaspur', 'Hoshiarpur', 'Jalandhar', 'Kapurthala', 'Ludhiana', 'Mansa', 'Moga', 'Muktsar', 'Pathankot', 'Patiala', 'Rupnagar', 'Sahibzada Ajit Singh Nagar', 'Sangrur', 'Shaheed Bhagat Singh Nagar', 'Tarn Taran'];
        break;
      case 'Rajasthan':
        districts = ['Ajmer', 'Alwar', 'Banswara', 'Baran', 'Barmer', 'Bharatpur', 'Bhilwara', 'Bikaner', 'Bundi', 'Chittorgarh', 'Churu', 'Dausa', 'Dholpur', 'Dungarpur', 'Hanumangarh', 'Jaipur', 'Jaisalmer', 'Jalore', 'Jhalawar', 'Jhunjhunu', 'Jodhpur', 'Karauli', 'Kota', 'Nagaur', 'Pali', 'Pratapgarh', 'Rajsamand', 'Sawai Madhopur', 'Sikar', 'Sirohi', 'Sri Ganganagar', 'Tonk', 'Udaipur'];
        break;
      case 'Sikkim':
        districts = ['East Sikkim', 'North Sikkim', 'South Sikkim', 'West Sikkim'];
        break;
      case 'Tamil Nadu':
        districts = ['Ariyalur', 'Chengalpattu', 'Chennai', 'Coimbatore', 'Cuddalore', 'Dharmapuri', 'Dindigul', 'Erode', 'Kallakurichi', 'Kanchipuram', 'Kanyakumari', 'Karur', 'Krishnagiri', 'Madurai', 'Mayiladuthurai', 'Nagapattinam', 'Namakkal', 'Nilgiris', 'Perambalur', 'Pudukkottai', 'Ramanathapuram', 'Ranipet', 'Salem', 'Sivaganga', 'Tenkasi', 'Thanjavur', 'Theni', 'Thoothukudi', 'Tiruchirappalli', 'Tirunelveli', 'Tirupattur', 'Tiruppur', 'Tiruvallur', 'Tiruvannamalai', 'Tiruvarur', 'Vellore', 'Viluppuram', 'Virudhunagar'];
        break;
      case 'Telangana':
        districts = ['Adilabad', 'Bhadradri Kothagudem', 'Hyderabad', 'Jagtial', 'Jangaon', 'Jayashankar Bhupalpally', 'Jogulamba Gadwal', 'Kamareddy', 'Karimnagar', 'Khammam', 'Kumuram Bheem Asifabad', 'Mahabubabad', 'Mahabubnagar', 'Mancherial', 'Medak', 'Medchal–Malkajgiri', 'Mulugu', 'Nagarkurnool', 'Nalgonda', 'Narayanpet', 'Nirmal', 'Nizamabad', 'Peddapalli', 'Rajanna Sircilla', 'Rangareddy', 'Sangareddy', 'Siddipet', 'Suryapet', 'Vikarabad', 'Wanaparthy', 'Warangal Rural', 'Warangal Urban', 'Yadadri Bhuvanagiri'];
        break;
      case 'Tripura':
        districts = ['Dhalai', 'Gomati', 'Khowai', 'North Tripura', 'Sepahijala', 'South Tripura', 'Unakoti', 'West Tripura'];
        break;
      case 'Uttar Pradesh':
        districts = ['Agra', 'Aligarh', 'Ambedkar Nagar', 'Amethi', 'Amroha', 'Auraiya', 'Ayodhya', 'Azamgarh', 'Baghpat', 'Bahraich', 'Ballia', 'Balrampur', 'Banda', 'Barabanki', 'Bareilly', 'Basti', 'Bhadohi', 'Bijnor', 'Budaun', 'Bulandshahr', 'Chandauli', 'Chitrakoot', 'Deoria', 'Etah', 'Etawah', 'Farrukhabad', 'Fatehpur', 'Firozabad', 'Gautam Buddha Nagar', 'Ghaziabad', 'Ghazipur', 'Gonda', 'Gorakhpur', 'Hamirpur', 'Hapur', 'Hardoi', 'Hathras', 'Jalaun', 'Jaunpur', 'Jhansi', 'Kannauj', 'Kanpur Dehat', 'Kanpur Nagar', 'Kasganj', 'Kaushambi', 'Kheri', 'Kushinagar', 'Lalitpur', 'Lucknow', 'Maharajganj', 'Mahoba', 'Mainpuri', 'Mathura', 'Mau', 'Meerut', 'Mirzapur', 'Moradabad', 'Muzaffarnagar', 'Pilibhit', 'Pratapgarh', 'Prayagraj', 'Raebareli', 'Rampur', 'Saharanpur', 'Sambhal', 'Sant Kabir Nagar', 'Shahjahanpur', 'Shamli', 'Shravasti', 'Siddharthnagar', 'Sitapur', 'Sonbhadra', 'Sultanpur', 'Unnao', 'Varanasi'];
        break;
      case 'Uttarakhand':
        districts = ['Almora', 'Bageshwar', 'Chamoli', 'Champawat', 'Dehradun', 'Haridwar', 'Nainital', 'Pauri Garhwal', 'Pithoragarh', 'Rudraprayag', 'Tehri Garhwal', 'Udham Singh Nagar', 'Uttarkashi'];
        break;
      case 'West Bengal':
        districts = ['Alipurduar', 'Bankura', 'Birbhum', 'Cooch Behar', 'Dakshin Dinajpur', 'Darjeeling', 'Hooghly', 'Howrah', 'Jalpaiguri', 'Jhargram', 'Kalimpong', 'Kolkata', 'Malda', 'Murshidabad', 'Nadia', 'North 24 Parganas', 'Paschim Bardhaman', 'Paschim Medinipur', 'Purba Bardhaman', 'Purba Medinipur', 'Purulia', 'South 24 Parganas', 'Uttar Dinajpur'];
        break;
      case 'Andaman and Nicobar Islands':
        districts = ['Nicobar', 'North and Middle Andaman', 'South Andaman'];
        break;
      case 'Chandigarh':
        districts = ['Chandigarh'];
        break;
      case 'Dadra and Nagar Haveli and Daman and Diu':
        districts = ['Dadra and Nagar Haveli', 'Daman', 'Diu'];
        break;
      case 'Delhi':
        districts = ['Central Delhi', 'East Delhi', 'New Delhi', 'North Delhi', 'North East Delhi', 'North West Delhi', 'Shahdara', 'South Delhi', 'South East Delhi', 'South West Delhi', 'West Delhi'];
        break;
      case 'Jammu and Kashmir':
        districts = ['Anantnag', 'Bandipora', 'Baramulla', 'Budgam', 'Doda', 'Ganderbal', 'Jammu', 'Kathua', 'Kishtwar', 'Kulgam', 'Kupwara', 'Poonch', 'Pulwama', 'Rajouri', 'Ramban', 'Reasi', 'Samba', 'Shopian', 'Srinagar', 'Udhampur'];
        break;
      case 'Ladakh':
        districts = ['Kargil', 'Leh'];
        break;
      case 'Lakshadweep':
        districts = ['Lakshadweep'];
        break;
      case 'Puducherry':
        districts = ['Karaikal', 'Mahe', 'Puducherry', 'Yanam'];
        break;
      default:
        districts = ['Select District'];
        break;
    }
    
    return districts;
  }
  
  Widget _buildInputSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Incident Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            SizedBox(height: 16),
            
            // Incident Type dropdown
            _buildSmoothDropdown(
              label: 'Type of Corruption',
              value: _selectedIncidentType,
              items: incidentTypes,
              onChanged: (newValue) {
                setState(() {
                  _selectedIncidentType = newValue;
                });
              },
              prefixIcon: Icons.warning_amber_rounded,
            ),
            
            // Show "Other" text field if 'Other' is selected
            if (_selectedIncidentType == 'Other') 
              AnimatedSize(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _buildSmoothTextField(
                  controller: _otherIncidentTypeController,
                  label: 'Specify Other Type',
                  icon: Icons.edit,
                  validator: (value) {
                    if (_selectedIncidentType == 'Other' && (value == null || value.isEmpty)) {
                      return 'Please specify the type of incident';
                    }
                    return null;
                  },
                ),
              ),
            
            // Department dropdown - replace with new implementation
            _buildSmoothDropdown(
              label: 'Department',
              value: _selectedDepartment,
              items: predefinedDepartments,
              onChanged: (newValue) {
                setState(() {
                  _selectedDepartment = newValue;
                });
              },
              prefixIcon: Icons.business,
            ),
            
            // Title field with smooth animation
            _buildSmoothTextField(
              controller: _titleController,
              label: 'Incident Title',
              icon: Icons.title,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            
            // Description field with smooth animation
            _buildSmoothTextField(
              controller: _descriptionController,
              label: 'Description',
              icon: Icons.description,
              maxLines: 5,
              keyboardType: TextInputType.multiline,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),
            
            // Add multilanguage support text
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.language,
                    size: 14,
                    color: Colors.blue.shade700,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'You can describe the incident in your native language',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            
            // Add the generate summary button
            SizedBox(height: 16),
            _buildGenerateButton(),
            
            // Display AI summary and severity below the generate button
            SizedBox(height: 16),
            if (_aiSummaryController.text.isNotEmpty || _isGeneratingSummary) ...[
              _buildAISummaryField(),
              SizedBox(height: 12),
            ],
            
            // Add the severity field display
            if (_severityController.text.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getSeverityColor(_severityController.text).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _getSeverityColor(_severityController.text).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: _getSeverityColor(_severityController.text),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Severity: ${_severityController.text}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getSeverityColor(_severityController.text),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildLocationSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Location',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            SizedBox(height: 16),
            
            // Location input
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildSmoothTextField(
                    controller: _locationController,
                    label: 'Location',
                    icon: Icons.location_on,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a location';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(width: 10),
                Container(
                  height: 56,
                  margin: EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.my_location, color: Colors.blue.shade700),
                    tooltip: 'Use current location',
                    onPressed: () async {
                      try {
                        // Show loading indicator
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text('Detecting location...'),
                              ],
                            ),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        
                        await _getCurrentLocation();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error getting location: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDateTimeSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            Text(
              'Date and Time',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            SizedBox(height: 16),
            
            // Date picker
            InkWell(
              onTap: () => _selectDate(context),
              child: Container(
                margin: EdgeInsets.only(bottom: 16),
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.blue.shade700),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Date',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                          _incidentDate == null
                              ? 'Select Date'
                                : DateFormat('MMMM d, yyyy').format(_incidentDate!),
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, color: Colors.blue.shade700),
                  ],
                ),
              ),
            ),
            
            // Time picker
            InkWell(
              onTap: () => _selectTime(context),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: Colors.blue.shade700),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Time',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                          _incidentTime == null
                              ? 'Select Time'
                              : _incidentTime!.format(context),
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, color: Colors.blue.shade700),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildWitnessesSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Witnesses',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            SizedBox(height: 16),
            
            // Multiple witness fields
            ..._witnessControllers.asMap().entries.map((entry) {
              int index = entry.key;
              TextEditingController controller = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: TextFormField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: 'Witness Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    prefixIcon: Icon(Icons.person_outline),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(index == 0 ? Icons.add : Icons.remove),
                          onPressed: index == 0
                              ? (_witnessControllers.length < 6 ? _addWitnessField : null)
                              : () => _removeWitnessField(index),
                          color: index == 0 && _witnessControllers.length >= 6
                              ? Colors.grey
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isUploading
            ? null
            : () async {
              if (_formKey.currentState!.validate()) {
                try {
                  final User? currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('You must be logged in to report an incident')),
                    );
                    return;
                  }

                  setState(() => _isUploading = true);

                  // Show upload progress dialog
                  if (_attachedFiles.isNotEmpty) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext dialogContext) {
                        // Store the dialog context
                        _uploadDialogContext = dialogContext;
                        return WillPopScope(
                          onWillPop: () async {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Please wait while files are uploading...'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return false;
                          },
                          child: StatefulBuilder(
                            builder: (dialogContext, setDialogState) {
                              return AlertDialog(
                                title: Text('Uploading Files'),
                                content: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Please wait while your files are being uploaded...',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      SizedBox(height: 12),
                                      ValueListenableBuilder<Map<String, double>>(
                                        valueListenable: _uploadProgressNotifier,
                                        builder: (context, progress, _) {
                                          return Column(
                                            children: progress.entries.map((entry) {
                                              return Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            entry.key,
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: TextStyle(fontSize: 12),
                                                          ),
                                                        ),
                                                        Text(
                                                          '${(entry.value * 100).toStringAsFixed(0)}%',
                                                          style: TextStyle(fontSize: 12),
                                                        ),
                                                      ],
                                                    ),
                                                    SizedBox(height: 4),
                                                    LinearProgressIndicator(
                                                      value: entry.value,
                                                      backgroundColor: Colors.grey.shade200,
                                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade300),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  }

                  // Upload files and save incident
                  List<String> fileUrls = await _uploadFiles();
                  await _saveIncident(fileUrls);

                  // Close the upload progress dialog if it's open
                  if (_uploadDialogContext != null) {
                    Navigator.of(_uploadDialogContext!).pop();
                    _uploadDialogContext = null;  // Clear the stored context
                  }

                  setState(() => _isUploading = false);
                } catch (e) {
                  // Close dialog even on error
                  if (_uploadDialogContext != null) {
                    Navigator.of(_uploadDialogContext!).pop();
                    _uploadDialogContext = null;
                  }
                  
                  setState(() => _isUploading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error submitting incident: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          backgroundColor: Colors.blue.shade400,
          foregroundColor: Colors.white,
          elevation: 2,
          minimumSize: Size(double.infinity, 45),
        ),
        child: Text(
          'Submit',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _aiSummaryController.dispose();
    // ... (dispose other controllers)
    super.dispose();
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'low':
        return Colors.green;
      case 'moderate':
        return Colors.orange;
      case 'high':
        return Colors.deepOrange;
      case 'critical':
        return Colors.red;
      default:
        return Colors.black;
    }
  }

  Widget _buildIncidentTypeInfo(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.blue.shade700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Future<List<String>> _uploadFiles() async {
    List<String> fileUrls = [];
    
    if (_attachedFiles.isEmpty) return fileUrls;

    try {
      setState(() {
        _uploadProgress.clear();
        for (var file in _attachedFiles) {
          _uploadProgress[file.name] = 0;
        }
      });

      for (PlatformFile file in _attachedFiles) {
        if (file.bytes == null) {
          print('No bytes available for file: ${file.name}');
          continue;
        }

        String fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        String filePath = 'incidents/${_auth.currentUser!.uid}/$fileName';

        try {
          // Create reference
          Reference ref = _storage.ref().child(filePath);
          
          // Create upload task using bytes
          UploadTask uploadTask = ref.putData(
            file.bytes!,
            SettableMetadata(
              contentType: 'application/${file.extension}',
              customMetadata: {
                'fileName': file.name,
                'size': file.size.toString(),
              },
            ),
          );

          // Show upload progress
          uploadTask.snapshotEvents.listen(
            (TaskSnapshot snapshot) {
              double progress = snapshot.bytesTransferred / snapshot.totalBytes;
              _uploadProgressNotifier.value = {
                ..._uploadProgressNotifier.value,
                file.name: progress,
              };
              print('Upload progress for ${file.name}: ${(progress * 100).toStringAsFixed(1)}%');
            },
            onError: (error) {
              print('Upload error for ${file.name}: $error');
            },
          );

          // Wait for upload to complete
          await uploadTask;
          
          // Get download URL
          String downloadUrl = await ref.getDownloadURL();
          fileUrls.add(downloadUrl);
          
          print('Successfully uploaded ${file.name}');
        } catch (e) {
          print('Error uploading ${file.name}: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error uploading ${file.name}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('General upload error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading files: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }

    return fileUrls;
  }

  Future<void> _saveIncident(List<String> fileUrls) async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('No authenticated user found');

      // Get all officer names from the controllers and join them
      String officerNames = _nameControllers
          .map((controller) => controller.text.trim())
          .where((name) => name.isNotEmpty)
          .join(', ');
          
      // Get all witness names from the controllers and join them
      String witnessNames = _witnessControllers
          .map((controller) => controller.text.trim())
          .where((name) => name.isNotEmpty)
          .join(', ');

      // Create incident document
      await _firestore.collection('incidents').add({
        'userId': currentUser.uid,
        'userEmail': currentUser.email,
        'title': _titleController.text,
        'description': _descriptionController.text,
        'aiSummary': _aiSummaryController.text,
        'severity': _severityController.text,
        'department': _selectedDepartment,
        'state': _selectedState,
        'district': _selectedDistrict,
        'location': _locationController.text,
        'witnesses': witnessNames,
        'attachments': fileUrls,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'Pending',
        'officerName': officerNames,
        'incidentDate': _incidentDate?.millisecondsSinceEpoch,
        'incidentTime': _incidentTime?.format(context),
      });

      // Clear all form fields after successful submission
      setState(() {
        _titleController.clear();
        _descriptionController.clear();
        _aiSummaryController.clear();
        _severityController.clear();
        _selectedDepartment = 'ULB';
        _selectedState = null;
        _selectedDistrict = null;
        _locationController.clear();
        _incidentDate = null;
        _incidentTime = null;
        _attachedFiles.clear();
        
        // Clear officer name controllers
        for (var controller in _nameControllers) {
          controller.clear();
        }
        
        // Clear witness controllers
        for (var controller in _witnessControllers) {
          controller.clear();
        }
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Incident reported successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back to the home page
        Navigator.pop(context); // This will return to MainScreen
      }
    } catch (e) {
      print('Error saving incident: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reporting incident: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Update the _buildProfileIncompleteMessage method
  Widget _buildProfileIncompleteMessage() {
    // First check if status changed since page load
    _checkLatestProfileStatus();
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline,
              size: 80,
              color: Colors.blue.shade200,
            ),
            SizedBox(height: 24),
            Text(
              'Profile Incomplete',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Please complete your profile before submitting an incident report. This information helps us verify your identity and follow up on your report.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                // Try to refresh status first
                _checkLatestProfileStatus();
                
                // If status changed to complete, rebuild page
                if (_isProfileComplete) {
                  setState(() {});
                  return;
                }

                // Otherwise use the callback if available
                if (widget.onRequestProfileTab != null) {
                  print('Requesting navigation to profile tab');
                  widget.onRequestProfileTab!();
                  Navigator.pop(context);
                } else {
                  // Fallback: just navigate back
                  Navigator.pop(context, {'goToProfile': true});
                }
              },
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Go to Profile',
                style: TextStyle(
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Fix the _buildSmoothDropdown method to handle overflow and null values
  Widget _buildSmoothDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    required IconData prefixIcon,
  }) {
    // Check if value exists in items list
    final valueExists = value == null ? true : items.contains(value);
    
    // If value doesn't exist in items, set to null to avoid assertion error
    final effectiveValue = valueExists ? value : null;
    
    // Check if this is the corruption type dropdown
    final bool isCorruptionType = label == 'Type of Corruption';
    
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Material(
              color: Colors.transparent,
              child: DropdownButtonHideUnderline(
                child: DropdownButtonFormField<String>(
                  value: effectiveValue,
                  icon: Icon(Icons.arrow_drop_down, color: Colors.blue.shade700),
                  decoration: InputDecoration(
                    prefixIcon: Icon(prefixIcon, color: Colors.blue.shade700),
                    labelText: label,
                    labelStyle: TextStyle(color: Colors.grey.shade700),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  menuMaxHeight: 300,
                  isExpanded: true,
                  elevation: 8,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                  ),
                  validator: (value) => value == null ? 'Please select $label' : null,
                  onChanged: onChanged,
                  items: items.map<DropdownMenuItem<String>>((String item) {
                    return DropdownMenuItem<String>(
                      value: item,
                      child: Container(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                item,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            if (isCorruptionType)
                              Container(
                                width: 30,
                                child: IconButton(
                                  icon: Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(),
                                  onPressed: () {
                                    // First call onChanged to make this the selected item
                                    onChanged(item);
                                    // Then show info dialog after a short delay
                                    Future.delayed(Duration(milliseconds: 100), () {
                                      _showCorruptionTypeInfo(item);
                                    });
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          if (isCorruptionType && value != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: TextButton.icon(
                onPressed: () => _showCorruptionTypeInfo(value),
                icon: Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                label: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                  child: Text(
                    'Learn more about ${value}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Add a helper function for smoother text fields
  Widget _buildSmoothTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blue.shade700),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: validator,
      ),
    );
  }

  void _addWitnessField() {
    if (_witnessControllers.length < 6) {
      setState(() {
        _witnessControllers.add(TextEditingController());
      });
    }
  }

  void _removeWitnessField(int index) {
    if (_witnessControllers.length > 1) {
      setState(() {
        _witnessControllers.removeAt(index);
      });
    }
  }

  // Add the missing method to extract severity from AI response
  String extractSeverityFromResponse(String? responseText) {
    if (responseText == null || responseText.isEmpty) {
      return 'Moderate'; // Default fallback
    }
    
    // Try to find severity indicators in the response
    final lowPatterns = ['low severity', 'low impact', 'minor', 'minimal'];
    final moderatePatterns = ['moderate severity', 'moderate impact', 'medium'];
    final highPatterns = ['high severity', 'high impact', 'severe', 'major'];
    final criticalPatterns = ['critical severity', 'critical impact', 'extreme'];
    
    final lowerCaseResponse = responseText.toLowerCase();
    
    if (criticalPatterns.any((pattern) => lowerCaseResponse.contains(pattern))) {
      return 'Critical';
    } else if (highPatterns.any((pattern) => lowerCaseResponse.contains(pattern))) {
      return 'High';
    } else if (moderatePatterns.any((pattern) => lowerCaseResponse.contains(pattern))) {
      return 'Moderate';
    } else if (lowPatterns.any((pattern) => lowerCaseResponse.contains(pattern))) {
      return 'Low';
    }
    
    // Default if no patterns found
    return 'Moderate';
  }

  // Add this method to show corruption type information
  void _showCorruptionTypeInfo(String type) {
    Map<String, Map<String, String>> corruptionInfo = {
      'Bribery': {
        'title': 'Bribery',
        'description': 'The offering, giving, receiving, or soliciting of something of value to influence an official act. This includes payments to government officials, kickbacks in procurement, or payments to obtain services.',
        'examples': '- Paying officials to expedite applications or permits\n- Offering money to avoid legal penalties\n- Demanding unofficial payments for public services'
      },
      'Embezzlement': {
        'title': 'Embezzlement',
        'description': 'The theft or misappropriation of funds placed in one\'s trust. This involves taking government or organizational funds for personal use.',
        'examples': '- Officials diverting public funds to personal accounts\n- Misuse of departmental budgets\n- Creating ghost employees to collect salaries'
      },
      'Fraud': {
        'title': 'Fraud',
        'description': 'Using deception to acquire money, assets, or services from the government or public. This includes false claims, document forgery, or manipulating processes for gain.',
        'examples': '- Submitting false documentation for benefits\n- Manipulating tender processes\n- Falsifying records to show compliance'
      },
      'Abuse of Power': {
        'title': 'Abuse of Power',
        'description': 'When officials use their authority for personal gain or to provide unfair advantages to others. This involves decisions that provide selective benefits.',
        'examples': '- Granting contracts to relatives or associates\n- Using government resources for personal purposes\n- Threatening people to comply with unreasonable demands'
      },
      'Nepotism': {
        'title': 'Nepotism',
        'description': 'Showing favoritism to family members or close associates in matters of employment, contracts, or benefits.',
        'examples': '- Hiring relatives without proper qualification\n- Giving promotions based on relationships not merit\n- Selecting family businesses for government contracts'
      },
      'Other': {
        'title': 'Other Types ',
        'description': 'Other forms may include extortion, trading in influence, conflict of interest, or any other corrupt practice not covered in the main categories.',
        'examples': '- Extortion: Forcing payment through threats\n- Conflict of interest: Officials making decisions where they have personal interest\n- Money laundering: Disguising origins of illicitly obtained money'
      },
    };

    final info = corruptionInfo[type] ?? {
      'title': 'Information Unavailable',
      'description': 'Details about this type of corruption are not available.',
      'examples': 'Please select a recognized type or specify details in your description.'
    };

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700),
              SizedBox(width: 10),
              Text(info['title'] ?? 'Information'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'What is it?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue.shade800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  info['description'] ?? '',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 16),
                Text(
                  'Common Examples:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue.shade800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  info['examples'] ?? '',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
} 
