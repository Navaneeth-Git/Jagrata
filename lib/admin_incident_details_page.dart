import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';

class AdminIncidentDetailsPage extends StatefulWidget {
  final String incidentId;
  final String currentStatus;

  const AdminIncidentDetailsPage({
    Key? key,
    required this.incidentId,
    required this.currentStatus,
  }) : super(key: key);

  @override
  _AdminIncidentDetailsPageState createState() => _AdminIncidentDetailsPageState();
}

class _AdminIncidentDetailsPageState extends State<AdminIncidentDetailsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedStatus = '';
  bool _isUpdating = false;

  final List<String> statusOptions = [
    'Pending',
    'Under Investigation',
    'In Progress',
    'Resolved',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.currentStatus;
  }

  Future<void> _updateIncidentStatus() async {
    setState(() => _isUpdating = true);
    try {
      await _firestore
          .collection('incidents')
          .doc(widget.incidentId)
          .update({'status': _selectedStatus});
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final darkGreenColor = Color(0xFF1B5E20);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Incident Details',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: darkGreenColor,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore
            .collection('incidents')
            .doc(widget.incidentId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};

          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Update Section
                Card(
                  elevation: 2,
                  color: darkGreenColor,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Update Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedStatus,
                          dropdownColor: darkGreenColor,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.7)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white),
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                          items: statusOptions.map((String status) {
                            return DropdownMenuItem(
                              value: status,
                              child: Text(
                                status,
                                style: TextStyle(color: Colors.white),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() => _selectedStatus = newValue!);
                          },
                        ),
                        SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isUpdating ? null : _updateIncidentStatus,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: darkGreenColor,
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: _isUpdating
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(darkGreenColor),
                                    ),
                                  )
                                : Text(
                                    'Update Status',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Incident Information Section
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Incident Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),
                        _buildDetailRow('Title', data['title'] ?? 'N/A'),
                        _buildDetailRow('Type', data['title'] ?? 'N/A', isHighlighted: true),
                        _buildDetailRow('Description', data['description'] ?? 'N/A', isMultiLine: true),
                        _buildDetailRow('AI Summary', data['aiSummary'] ?? 'N/A', isMultiLine: true),
                        _buildSeverityRow('Severity', data['severity'] ?? 'N/A'),
                        _buildInfoRow(
                          'Officers Involved',
                          data['officerName'] ?? 'Not specified',
                          severity: data['severity']?.toLowerCase() ?? '',
                        ),
                        _buildDetailRow('Department', data['department'] ?? 'N/A'),
                        if (data['state'] != null)
                          _buildDetailRow('State', data['state']),
                        _buildDetailRow('Location', data['location'] ?? 'N/A'),
                        _buildDetailRow('Witnesses', data['witnesses'] ?? 'N/A'),
                        _buildDetailRow('Reported By', data['userEmail'] ?? 'Anonymous'),
                        _buildDetailRow('Reported On', _formatTimestamp(data['timestamp'])),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Attachments Section with Download
                if (data['attachments'] != null && (data['attachments'] as List).isNotEmpty)
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Attachments',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: (data['attachments'] as List).length,
                            itemBuilder: (context, index) {
                              final url = data['attachments'][index];
                              final fileName = url.split('/').last;
                              final extension = fileName.split('.').last.toLowerCase();
                              
                              return ListTile(
                                leading: _getFileTypeIcon(extension),
                                title: Text(fileName),
                                subtitle: Text('Click to download file'),
                                trailing: IconButton(
                                  icon: Icon(Icons.download, color: darkGreenColor),
                                  onPressed: () => _downloadFile(url, fileName),
                                  tooltip: 'Download file',
                                ),
                                onTap: () => _downloadFile(url, fileName),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _getFileTypeIcon(String extension) {
    switch (extension) {
      case 'pdf':
        return Icon(Icons.picture_as_pdf, color: Colors.red);
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icon(Icons.image, color: Colors.blue);
      case 'mp4':
      case 'mov':
        return Icon(Icons.video_library, color: Colors.purple);
      default:
        return Icon(Icons.insert_drive_file, color: Colors.grey);
    }
  }

  Future<void> _downloadFile(String url, String fileName) async {
    try {
      // Get the download URL from Firebase Storage
      String downloadUrl = url;
      try {
        final storageRef = FirebaseStorage.instance.refFromURL(url);
        downloadUrl = await storageRef.getDownloadURL();
      } catch (e) {
        print('Error getting download URL: $e');
        // Use original URL if getting download URL fails
      }

      // Launch URL in new window/tab for download
      final Uri uri = Uri.parse(downloadUrl);
      await launchUrl(
        uri,
        mode: LaunchMode.platformDefault, // Changed to platformDefault for better download handling
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloading $fileName...'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Download error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed. Please try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildDetailRow(String label, String value, {bool isMultiLine = false, bool isHighlighted = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: isHighlighted ? Colors.blue[700] : Colors.black87,
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
            ),
            maxLines: isMultiLine ? null : 1,
            overflow: isMultiLine ? null : TextOverflow.ellipsis,
          ),
          Divider(height: 16),
        ],
      ),
    );
  }

  Widget _buildSeverityRow(String label, String value) {
    Color severityColor;
    switch (value.toLowerCase()) {
      case 'high':
        severityColor = Colors.red;
        break;
      case 'medium':
        severityColor = Colors.orange;
        break;
      case 'low':
        severityColor = Colors.green;
        break;
      default:
        severityColor = Colors.grey;
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: severityColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: severityColor.withOpacity(0.3)),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: severityColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Divider(height: 16),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {String severity = ''}) {
    Color severityColor = Colors.grey;
    switch (severity.toLowerCase()) {
      case 'critical':
        severityColor = Colors.red[900]!;
        break;
      case 'high':
        severityColor = Colors.red;
        break;
      case 'medium':
        severityColor = Colors.orange;
        break;
      case 'low':
        severityColor = Colors.green;
        break;
      default:
        severityColor = Colors.grey;
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: label == 'Officers Involved' 
                  ? Colors.grey[100] 
                  : severityColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: label == 'Officers Involved' 
                    ? Colors.grey[300]! 
                    : severityColor.withOpacity(0.3)
              ),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: label == 'Officers Involved' 
                    ? Colors.grey[800] 
                    : severityColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Divider(height: 16),
        ],
      ),
    );
  }
}

class _VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;

  const _VideoPlayerScreen({required this.videoUrl});

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {
          _isInitialized = true;
        });
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: _isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : CircularProgressIndicator(),
      ),
      floatingActionButton: _isInitialized
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                });
              },
              child: Icon(
                _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
            )
          : null,
    );
  }
} 