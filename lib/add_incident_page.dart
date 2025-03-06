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


class AddIncidentPage extends StatefulWidget {
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
    'Central Vigilance Commission (CVC)',
    'State Vigilance & Anti-Corruption Bureau',
    'Urban Local Bodies (ULB) / Municipal Corporations',
    'Chief Vigilance Officers (CVO) of Respective PSUs',
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

  @override
  void initState() {
    super.initState();
    // Initialize the Vertex AI model with the correct model name
    _model = FirebaseVertexAI.instance.generativeModel(model: 'gemini-1.5-flash');
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
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
          '''Generate a formal and structured summary of this incident report. Use markdown formatting:
          - Use # for main headings
          - Use ** for bold important points
          - Use proper paragraphs with line breaks

          Include the following sections:
          1. # Introduction
             - Type of corruption and when it occurred
          2. # Detailed Analysis
             - Comprehensive explanation with **key points highlighted**
          3. # Impact Assessment
             - Severity analysis and potential consequences
          4. # Contextual Information
             - Relevant details about department/officials

          Incident Description:
          ${_descriptionController.text}'''
        )
      ];

      final analysisResponse = await _model.generateContent(analysisPrompt);
      
      // Second prompt specifically for severity classification
      final severityPrompt = [
        Content.text(
          '''Based on the following incident description, classify the severity as either "Low", "Moderate", "High", or "Critical". Consider these factors:
          - Financial impact
          - Number of people affected
          - Level of officials involved
          - Systemic nature of corruption
          - Potential damage to public trust
          - Impact on government services
          
          Respond with ONLY ONE of these four severity levels.
          
          Incident Description:
          ${_descriptionController.text}'''
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
        Padding(
          padding: EdgeInsets.only(top: 4, left: 8),
          child: Text(
            'Supports markdown formatting',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
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
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Report Incident',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
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
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'Location',
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
                              content: Text('Location of incident.'),
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
                        icon: Icon(Icons.my_location),
                        onPressed: _getCurrentLocation,
                      ),
                    ],
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the location';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              Container(
                margin: EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Type of Incident',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: ButtonTheme(
                                alignedDropdown: true,
                                child: DropdownButton<String>(
                                  value: _selectedIncidentType,
                                  hint: Text('Select incident type'),
                                  isExpanded: true,
                                  icon: Icon(Icons.arrow_drop_down_circle, color: Colors.blue),
                                  iconSize: 24,
                                  elevation: 16,
                                  style: TextStyle(color: Colors.black, fontSize: 16),
                                  items: [
                                    ...incidentTypes.map((String type) {
                                      return DropdownMenuItem<String>(
                                        value: type,
                                        child: Text(type),
                                      );
                                    }).toList(),
                                  ],
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      _selectedIncidentType = newValue;
                                      if (newValue != 'Other') {
                                        _otherIncidentTypeController.clear();
                                      }
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(color: Colors.blue),
                              ),
                            ),
                            child: IconButton(
                              icon: Icon(Icons.info_outline, color: Colors.blue),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: Text('Types of Corruption'),
                                      content: SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _buildIncidentTypeInfo(
                                              'Bribery',
                                              'Offering, giving, receiving, or soliciting something of value to influence an official action.',
                                            ),
                                            _buildIncidentTypeInfo(
                                              'Embezzlement',
                                              'Theft or misappropriation of funds placed in one\'s trust or belonging to one\'s employer.',
                                            ),
                                            _buildIncidentTypeInfo(
                                              'Fraud',
                                              'Deception for personal gain or to damage another individual/organization.',
                                            ),
                                            _buildIncidentTypeInfo(
                                              'Abuse of Power',
                                              'Using one\'s position of authority for personal gain or to unfairly advantage/disadvantage others.',
                                            ),
                                            _buildIncidentTypeInfo(
                                              'Nepotism',
                                              'Favoritism shown to relatives or close friends by those in power.',
                                            ),
                                          ],
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: Text('Close'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedIncidentType == 'Other') ...[
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _otherIncidentTypeController,
                        decoration: InputDecoration(
                          labelText: 'Specify Other Incident Type',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (_selectedIncidentType == 'Other' && (value == null || value.isEmpty)) {
                            return 'Please specify the incident type';
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16.0),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Date of Incident',
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          _incidentDate == null
                              ? 'Select Date'
                              : DateFormat.yMd().format(_incidentDate!),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(context),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Time of Incident',
                          suffixIcon: Icon(Icons.access_time),
                        ),
                        child: Text(
                          _incidentTime == null
                              ? 'Select Time'
                              : _incidentTime!.format(context),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description of Incident',
                  border: OutlineInputBorder(),
                  helperText: 'Provide detailed description of the incident',
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please describe the incident';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12.0),
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: _buildGenerateButton(),
                ),
              ),
              const SizedBox(height: 16.0),
              _buildAISummaryField(),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _severityController,
                decoration: InputDecoration(
                  labelText: 'Severity',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  suffixIcon: Icon(Icons.auto_awesome, color: Colors.blue),
                ),
                maxLines: 1,
                readOnly: true,
                enabled: false,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _getSeverityColor(_severityController.text),
                ),
              ),
              SizedBox(height: 16.0),
              _buildDepartmentField(),
              SizedBox(height: 16.0),
              TextFormField(
                controller: _witnessesController,
                decoration: InputDecoration(
                  labelText: 'Witnesses (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16.0),
              _buildAttachmentSection(),
              const SizedBox(height: 16.0),
              Center(
                child: SizedBox(
                  width: 120,
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
                      minimumSize: Size(120, 45),
                    ),
                    child: Container(
                      width: 120,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.send,
                            size: 16,
                            color: Colors.white,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Submit',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
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

      // Create incident document
      await _firestore.collection('incidents').add({
        'userId': currentUser.uid,
        'userEmail': currentUser.email,
        'incidentType': _selectedIncidentType,
        'otherIncidentType': _selectedIncidentType == 'Other' ? _otherIncidentTypeController.text : null,
        'date': _incidentDate?.toIso8601String(),
        'time': _incidentTime != null ? '${_incidentTime!.hour}:${_incidentTime!.minute}' : null,
        'location': _locationController.text,
        'description': _descriptionController.text,
        'aiSummary': _aiSummaryController.text,
        'severity': _severityController.text,
        'witnesses': _witnessesController.text,
        'attachments': fileUrls,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'Reviewing',
        'department': _departmentController.text,
      });

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incident reported successfully'),
            duration: Duration(seconds: 2),
          ),
        );

        // Clear the form
        _formKey.currentState?.reset();
        _selectedIncidentType = null;
        _incidentDate = null;
        _incidentTime = null;
        _attachedFiles.clear();
        _otherIncidentTypeController.clear();
        _descriptionController.clear();
        _aiSummaryController.text = '';
        _severityController.text = '';
        _witnessesController.clear();
        _locationController.clear();
        _departmentController.clear();

        // Navigate to home using MainScreenState
        final mainScreenState = context.findAncestorStateOfType<MainScreenState>();
        if (mainScreenState != null) {
          mainScreenState.setIndex(0); // Switch to home page
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving incident: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      print('Error saving incident: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _generateAISummary() async {
    // Check if name is provided
    if (_nameControllers.any((controller) => controller.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide all name fields first')),
      );
      return;
    }
    
    // Check if date is provided
    if (_incidentDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide the incident date first')),
      );
      return;
    }
    
    // Check if description is provided
    if (_descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide incident description first')),
      );
      return;
    }

    setState(() {
      _isGeneratingAI = true;
    });

    try {
      // Initialize Firebase Vertex AI
      final model = FirebaseVertexAI.instance.generativeModel(model: 'gemini-2.0-flash');
      
      // Create a more comprehensive prompt that includes name and date
      final prompt = [
        Content.text(
          "Analyze the following corruption incident report:\n\n" +
          "Reporter's Name: ${_nameControllers.map((controller) => controller.text).join(', ')}\n" +
          "Incident Date: ${_incidentDate!.toIso8601String()}\n" +
          "Description: ${_descriptionController.text}\n\n" +
          "Please provide:\n" +
          "1. A concise summary of the incident (2-3 sentences)\n" +
          "2. Assess the severity level (Low, Moderate, High, or Critical)\n" +
          "Format your response as:\n" +
          "SUMMARY: [your summary here]\n" +
          "SEVERITY: [severity level]"
        )
      ];
      
      // Generate content with the enhanced prompt
      final response = await model.generateContent(prompt);
      final responseText = response.text ?? '';
      
      // Parse the response to extract summary and severity
      String summary = '';
      String severity = '';
      
      if (responseText.contains('SUMMARY:') && responseText.contains('SEVERITY:')) {
        final summaryMatch = RegExp(r'SUMMARY:(.*?)(?=SEVERITY:|$)', dotAll: true).firstMatch(responseText);
        final severityMatch = RegExp(r'SEVERITY:(.*?)(?=$)', dotAll: true).firstMatch(responseText);
        
        if (summaryMatch != null) {
          summary = summaryMatch.group(1)?.trim() ?? '';
        }
        
        if (severityMatch != null) {
          severity = severityMatch.group(1)?.trim().toLowerCase() ?? '';
          // Normalize severity to one of the expected values
          if (severity.contains('low')) {
            severity = 'low';
          } else if (severity.contains('moderate')) {
            severity = 'moderate';
          } else if (severity.contains('high')) {
            severity = 'high';
          } else if (severity.contains('critical')) {
            severity = 'critical';
          } else {
            severity = 'low'; // Default to low if unclear
          }
        }
      } else {
        // Fallback if the AI doesn't follow the format
        summary = responseText.trim();
        severity = 'low'; // Default to low
      }

      setState(() {
        _aiSummaryController.text = summary;
        _severityController.text = severity;
        
        // Update the departments list based on the new severity
        _departmentsBasedOnSeverity = _getDepartmentsForSeverity(severity);
        
        // Reset the department selection when severity changes
        _departmentController.text = '';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating AI summary: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isGeneratingAI = false;
      });
    }
  }

  List<String> _getDepartmentsForSeverity(String severity) {
    // Base departments that should be available for all severity levels
    List<String> departments = [
      'State Vigilance & Anti-Corruption Bureau',
      'Urban Local Bodies (ULB) / Municipal Corporations',
      'Chief Vigilance Officers (CVO) of Respective PSUs'
    ];
    
    // Only add Central Government option for high and critical severity
    if (severity.toLowerCase() == 'high' || severity.toLowerCase() == 'critical') {
      departments.insert(0, 'Central Vigilance Commission (CVC)');
    }
    
    return departments;
  }

  Widget _buildDepartmentField() {
    // Update the departments list when severity changes
    _departmentsBasedOnSeverity = _getDepartmentsForSeverity(_severityController.text);
    
    // If severity is empty, show a disabled field with a message
    if (_severityController.text.isEmpty) {
      return Container(
        margin: EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Department',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 15),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
                color: Colors.grey[200],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Generate summary first to see departments',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // If severity is not empty, show a selectable dropdown
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Department',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButtonHideUnderline(
              child: ButtonTheme(
                alignedDropdown: true,
                child: DropdownButton<String>(
                  value: _departmentController.text.isNotEmpty && _departmentsBasedOnSeverity.contains(_departmentController.text) 
                      ? _departmentController.text 
                      : null,
                  hint: Text('Select a department'),
                  isExpanded: true,
                  icon: Icon(Icons.arrow_drop_down_circle, color: Colors.blue),
                  iconSize: 24,
                  elevation: 16,
                  style: TextStyle(color: Colors.black, fontSize: 16),
                  dropdownColor: Colors.white,
                  items: _departmentsBasedOnSeverity.map((String department) {
                    return DropdownMenuItem<String>(
                      value: department,
                      child: Text(department),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _departmentController.text = newValue ?? '';
                    });
                  },
                ),
              ),
            ),
          ),
          SizedBox(height: 4),
          Text(
            _severityController.text.toLowerCase() == 'high' || _severityController.text.toLowerCase() == 'critical'
                ? 'All departments available for ${_severityController.text.toLowerCase()} severity'
                : 'Central departments not available for ${_severityController.text.toLowerCase()} severity',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
} 