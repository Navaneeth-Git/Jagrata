import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_player/video_player.dart';
import 'package:photo_view/photo_view.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:intl/intl.dart';
import 'add_incident_page.dart';
import 'package:firebase_core/firebase_core.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Set<String> _expandedCards = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Incident Reports',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      backgroundColor: Colors.grey.shade100,
      body: StreamBuilder<User?>(
        stream: _auth.authStateChanges(),
        builder: (context, authSnapshot) {
          print('Auth state changed: ${authSnapshot.data?.uid}');

          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final User? currentUser = authSnapshot.data;
          if (currentUser == null) {
            return Center(child: Text('Please log in'));
          }

          print('Current user ID: ${currentUser.uid}');

          return StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('incidents')
                .where('userId', isEqualTo: currentUser.uid)
                .orderBy('timestamp', descending: true)
                .snapshots()
                .handleError((error) {
                  print('Firestore error details: $error');
                  if (error.toString().contains('requires an index')) {
                    // Show a more user-friendly message while index is being built
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Setting up database indexes...\nThis may take a few minutes.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return error;
                }),
            builder: (context, snapshot) {
              print('Firestore snapshot state: ${snapshot.connectionState}');
              print('Firestore error: ${snapshot.error}');
              
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                print('Detailed error: ${snapshot.error}');
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Error loading incidents: ${snapshot.error}',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            print('Retrying connection...');
                          });
                        },
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              final documents = snapshot.data?.docs ?? [];
              print('Number of documents: ${documents.length}');
              
              if (documents.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_rounded,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No incidents reported yet',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: documents.length,
                itemBuilder: (context, index) {
                  final data = documents[index].data() as Map<String, dynamic>;
                  return _buildIncidentCard(data);
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddIncidentPage()),
          );
        },
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildIncidentCard(Map<String, dynamic> data) {
    final timestamp = (data['timestamp'] as Timestamp).toDate();
    final String cardId = data['id'] ?? timestamp.toString();
    final bool isExpanded = _isCardExpanded(cardId);
    final List<String> names = List<String>.from(data['names'] ?? []);
    
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: isExpanded ? 4 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () {
            _toggleCard(cardId);
          },
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(isExpanded ? 0 : 12),
                    bottomRight: Radius.circular(isExpanded ? 0 : 12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(data['status'] ?? 'Pending').withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getStatusColor(data['status'] ?? 'Pending').withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getStatusIcon(data['status'] ?? 'Pending'),
                                size: 14,
                                color: _getStatusColor(data['status'] ?? 'Pending'),
                              ),
                              SizedBox(width: 4),
                              Text(
                                data['status'] ?? 'Pending',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _getStatusColor(data['status'] ?? 'Pending'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildSeverityBadge(data['severity']),
                      ],
                    ),
                    SizedBox(height: 12),
                    
                    Text(
                      data['title'] ?? 'Untitled Incident',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            data['location'] ?? 'Location not specified',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Text(
                          _formatTimestamp(data['timestamp'] as Timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              AnimatedCrossFade(
                firstChild: SizedBox(height: 0),
                secondChild: _buildExpandedContent(data, timestamp),
                crossFadeState: _isCardExpanded(data['id'] ?? timestamp.toString())
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: Duration(milliseconds: 300),
                reverseDuration: Duration(milliseconds: 200),
                sizeCurve: Curves.easeInOut,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedContent(Map<String, dynamic> data, DateTime timestamp) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 1),
          SizedBox(height: 16),
          
          // Description Section
          _buildExpandedSection(
            title: 'Description',
            content: data['description'] ?? 'No description provided',
            icon: Icons.description_outlined,
          ),
          SizedBox(height: 20),

          // AI Analysis Section
          if (data['aiSummary'] != null && data['aiSummary'].toString().isNotEmpty) ...[
            _buildExpandedSection(
              title: 'AI Analysis',
              content: data['aiSummary'],
              icon: Icons.psychology_outlined,
            ),
            SizedBox(height: 20),
          ],

          // Reporter Information
          if (data['userEmail'] != null) ...[
            _buildExpandedSection(
              title: 'Reported By',
              content: data['userEmail'],
              icon: Icons.person_outline,
              isSmallSection: true,
            ),
            SizedBox(height: 20),
          ],

          // Location Information
          if (data['location'] != null && data['location'].toString().isNotEmpty) ...[
            _buildExpandedSection(
              title: 'Location',
              content: data['location'],
              icon: Icons.location_on_outlined,
              isSmallSection: true,
            ),
            SizedBox(height: 20),
          ],

          // Department and State Section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildExpandedSection(
                  title: 'Department',
                  content: data['department'] ?? 'Not specified',
                  icon: Icons.business_outlined,
                  isSmallSection: true,
                ),
              ),
              SizedBox(width: 20),
              if (data['state'] != null)
                Expanded(
                  child: _buildExpandedSection(
                    title: 'State',
                    content: data['state'],
                    icon: Icons.location_city_outlined,
                    isSmallSection: true,
                  ),
                ),
            ],
          ),
          SizedBox(height: 20),

          // Witnesses Section
          if (data['witnesses'] != null && data['witnesses'].toString().isNotEmpty) ...[
            _buildExpandedSection(
              title: 'Witnesses',
              content: data['witnesses'],
              icon: Icons.people_outline,
            ),
            SizedBox(height: 20),
          ],

          // Attachments Section
          if (data['attachments'] != null && (data['attachments'] as List).isNotEmpty) ...[
            _buildExpandedSection(
              title: 'Attachments',
              content: '',
              icon: Icons.attach_file_outlined,
              customContent: ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: (data['attachments'] as List).length,
                itemBuilder: (context, index) {
                  final url = data['attachments'][index];
                  final String fileExtension = url.split('.').last.toLowerCase();
                  
                  // Determine the icon based on file type
                  IconData fileIcon;
                  if (['jpg', 'jpeg', 'png', 'gif'].contains(fileExtension)) {
                    fileIcon = Icons.image_outlined;
                  } else if (['mp4', 'mov', 'avi'].contains(fileExtension)) {
                    fileIcon = Icons.video_library_outlined;
                  } else if (fileExtension == 'pdf') {
                    fileIcon = Icons.picture_as_pdf_outlined;
                  } else {
                    fileIcon = Icons.insert_drive_file_outlined;
                  }

                  return Card(
                    margin: EdgeInsets.only(top: 8),
                    child: ListTile(
                      leading: Icon(fileIcon, color: Colors.grey[700]),
                      title: Text(
                        'Attachment ${index + 1}${fileExtension.isNotEmpty ? '.$fileExtension' : ''}',
                        style: TextStyle(fontSize: 14),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (['jpg', 'jpeg', 'png', 'gif', 'mp4', 'mov', 'avi'].contains(fileExtension))
                            Icon(Icons.preview_outlined, color: Colors.blue)
                          else
                            Icon(Icons.download_outlined, color: Colors.blue),
                        ],
                      ),
                      onTap: () => _handleAttachmentTap(url),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 20),
          ],

          // Expand/Collapse Button
          Center(
            child: TextButton.icon(
              onPressed: () => _toggleCard(data['id'] ?? timestamp.toString()),
              icon: Icon(Icons.expand_less),
              label: Text('Show Less'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build consistent expanded sections
  Widget _buildExpandedSection({
    required String title,
    required String content,
    required IconData icon,
    bool isSmallSection = false,
    Widget? customContent,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey[700]),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: isSmallSection ? 14 : 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        if (customContent != null)
          customContent
        else
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Text(
              content,
              style: TextStyle(
                fontSize: isSmallSection ? 13 : 14,
                height: 1.5,
                color: Colors.grey[800],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        SizedBox(height: 8),
        Text(
          content,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildAISummarySection(String? summary) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, 
                size: 16, 
                color: Colors.blue.shade700
              ),
              SizedBox(width: 8),
              Text(
                'AI Summary',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            summary ?? 'No AI summary available',
            style: TextStyle(
              fontSize: 14,
              color: Colors.blue.shade900,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeverityBadge(String? severity) {
    Color severityColor = _getSeverityColor(severity ?? 'low');
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: severityColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: severityColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getSeverityIcon(severity ?? 'low'),
            size: 16,
            color: severityColor,
          ),
          SizedBox(width: 6),
          Text(
            severity?.toUpperCase() ?? 'NOT SET',
            style: TextStyle(
              color: severityColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentBadge(String? department) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.business,
            size: 16,
            color: Colors.indigo,
          ),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              department ?? 'Not assigned',
              style: TextStyle(
                color: Colors.indigo,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getSeverityIcon(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Icons.warning_rounded;
      case 'high':
        return Icons.error_outline;
      case 'moderate':
        return Icons.info_outline;
      case 'low':
        return Icons.check_circle_outline;
      default:
        return Icons.help_outline;
    }
  }

  Widget _buildAttachmentPreview(List<dynamic> attachments) {
    if (attachments.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            'Attachments',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: attachments.length,
            itemBuilder: (context, index) {
              final String url = attachments[index];
              final String extension = url.split('.').last.toLowerCase();

              // Handle different file types
              if (['jpg', 'jpeg', 'png'].contains(extension)) {
                // Image preview
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => _showImagePreview(url),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        url,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 100,
                            height: 100,
                            color: Colors.grey.shade200,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        },
                      ),
                    ),
                  ),
                );
              } else if (['mp4', 'mov', 'avi', 'mkv'].contains(extension)) {
                // Video preview
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => _showVideoPreview(context, url),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.play_circle_fill, size: 40, color: Colors.blue),
                    ),
                  ),
                );
              } else {
                // Document preview
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => _openDocument(url),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            extension == 'pdf' ? Icons.picture_as_pdf : Icons.insert_drive_file,
                            size: 32,
                            color: Colors.blue,
                          ),
                          SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              extension.toUpperCase(),
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  void _showImagePreview(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            leading: IconButton(
              icon: Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Container(
            color: Colors.black,
            child: PhotoView(
              imageProvider: NetworkImage(imageUrl),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
            ),
          ),
        ),
      ),
    );
  }

  void _showVideoPreview(BuildContext context, String videoUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(videoUrl: videoUrl),
      ),
    );
  }

  void _openDocument(String documentUrl) async {
    try {
      await launchUrlString(documentUrl);
    } catch (e) {
      print('Error opening document: $e');
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'under investigation':
        return Colors.blue;
      case 'in progress':
        return Colors.amber.shade700;
      case 'resolved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Date not available';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _launchURL(String url) async {
    try {
      if (await canLaunchUrlString(url)) {
        await launchUrlString(url);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening file: $e')),
      );
    }
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
        return Colors.grey;
    }
  }

  Widget _buildStatusBadge(String? status) {
    final String displayStatus = status?.toUpperCase() ?? 'REVIEWING';
    final Color statusColor = _getStatusColor(displayStatus);
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(displayStatus),
            size: 16,
            color: statusColor,
          ),
          SizedBox(width: 6),
          Text(
            displayStatus,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'reviewing':
        return Icons.pending_outlined;
      case 'in progress':
        return Icons.sync;
      case 'resolved':
        return Icons.check_circle_outline;
      case 'rejected':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat('MMM d, yyyy • hh:mm a').format(date);
  }

  bool _isCardExpanded(String cardId) {
    return _expandedCards.contains(cardId);
  }

  void _toggleCard(String cardId) {
    setState(() {
      if (_expandedCards.contains(cardId)) {
        _expandedCards.remove(cardId);
      } else {
        _expandedCards.add(cardId);
      }
    });
  }

  void _handleAttachmentTap(String url) {
    final String fileExtension = url.split('.').last.toLowerCase();
    
    // Image files
    if (['jpg', 'jpeg', 'png', 'gif'].contains(fileExtension)) {
      _showImagePreview(url);
    }
    // Video files
    else if (['mp4', 'mov', 'avi'].contains(fileExtension)) {
      _showVideoPreview(context, url);
    }
    // PDF and other documents
    else {
      _downloadFile(url);
    }
  }

  Future<void> _downloadFile(String url) async {
    try {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;

  VideoPlayerScreen({required this.videoUrl});

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
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
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_controller),
                    FloatingActionButton(
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
                    ),
                  ],
                ),
              )
            : CircularProgressIndicator(),
      ),
    );
  }
} 