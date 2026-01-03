import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connect_pharma/services/request_service.dart';
import 'package:connect_pharma/screens/ChatScreen.dart';
import 'package:connect_pharma/widgets/FadeInSlide.dart';
import 'package:geolocator/geolocator.dart';

class PharmacistRequestsScreen extends StatefulWidget {
  const PharmacistRequestsScreen({super.key});

  @override
  State<PharmacistRequestsScreen> createState() => _PharmacistRequestsScreenState();
}

class _PharmacistRequestsScreenState extends State<PharmacistRequestsScreen> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String currentPharmacistId = FirebaseAuth.instance.currentUser!.uid;
  final Set<String> _rejectedRequestIds = {};
  DocumentSnapshot<Map<String, dynamic>>? _currentNotificationRequest;
  StreamSubscription? _notificationSubscription;
  bool _isNotificationVisible = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _startNotificationListener();
  }

  void _startNotificationListener() {
    _notificationSubscription = RequestService.streamOpenBroadcastRequests().listen((snapshot) {
      final now = DateTime.now();
      final oneHourAgo = now.subtract(const Duration(hours: 1));
      
      final activeDocs = snapshot.docs.where((doc) {
        final data = doc.data();
        final status = data['status'];
        final createdAt = data['createdAt'] as Timestamp?;
        if (status != 'open') return false;
        if (createdAt == null) return true;
        return createdAt.toDate().isAfter(oneHourAgo);
      }).toList();

      if (activeDocs.isNotEmpty) {
        final latest = activeDocs.first;
        if (!_rejectedRequestIds.contains(latest.id) && 
            (_currentNotificationRequest == null || _currentNotificationRequest!.id != latest.id)) {
          setState(() {
            _currentNotificationRequest = latest;
            _isNotificationVisible = true;
          });
        }
      } else {
        if (_isNotificationVisible) {
          setState(() {
            _isNotificationVisible = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pharmacist Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
              }
            },
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Incoming Requests'),
            Tab(text: 'My Accepted Jobs'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildIncomingRequests(),
              _buildMyJobs(),
            ],
          ),
          _buildSlidingNotificationOverlay(),
        ],
      ),
    );
  }

  Widget _buildSlidingNotificationOverlay() {
    if (_currentNotificationRequest == null) return const SizedBox.shrink();

    final data = _currentNotificationRequest!.data()!;
    final medicineNameRaw = data['medicineName'] ?? '';
    final hasPrescription = data['prescriptionUrl'] != null;
    final medicineName = medicineNameRaw.isEmpty ? (hasPrescription ? 'Prescription Attached' : 'Unknown') : medicineNameRaw;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      bottom: _isNotificationVisible ? 20 : -250,
      left: 16,
      right: 16,
      child: Material(
        elevation: 10,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blueAccent.withOpacity(0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_active, color: Colors.blueAccent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'NEW REQUEST',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent,
                                letterSpacing: 1.1,
                              ),
                            ),
                            Text(
                              'Just now',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                        Text(
                          medicineName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (hasPrescription)
                          Row(
                            children: [
                              Icon(Icons.image, size: 14, color: Colors.blue.shade700),
                              const SizedBox(width: 4),
                              Text(
                                'Prescription Attached',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _isNotificationVisible = false;
                          _rejectedRequestIds.add(_currentNotificationRequest!.id);
                        });
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final id = _currentNotificationRequest!.id;
                        setState(() {
                          _isNotificationVisible = false;
                        });
                        _acceptRequest(id);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIncomingRequests() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: RequestService.streamOpenBroadcastRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final now = DateTime.now();
        final oneHourAgo = now.subtract(const Duration(hours: 1));
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data();
          final status = data['status'];
          final createdAt = data['createdAt'] as Timestamp?;
          
          if (status != 'open') return false; // Client-side status filter
          if (createdAt == null) return true;
          return createdAt.toDate().isAfter(oneHourAgo);
        }).toList();

        if (docs.isEmpty) {
          return const Center(child: Text('No recent open requests'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            return FadeInSlide(
              index: index,
              child: Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  title: Text(data['medicineName']?.toString().toUpperCase() ?? (data['prescriptionUrl'] != null ? 'PRESCRIPTION ATTACHED' : 'UNKNOWN')),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text('Status: ${data['status']}'),
                      if (data['prescriptionUrl'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: InkWell(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) => Dialog(
                                  backgroundColor: Colors.transparent,
                                  child: Stack(
                                    alignment: Alignment.topRight,
                                    children: [
                                      InteractiveViewer(
                                        child: Image.network(data['prescriptionUrl']),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.remove_red_eye, size: 16, color: Colors.blue),
                                  SizedBox(width: 6),
                                  Text(
                                    'VIEW PRESCRIPTION',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: () => _acceptRequest(doc.id),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: () => _cancelRequest(doc.id),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMyJobs() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: RequestService.streamRequestsAcceptedByPharmacist(currentPharmacistId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final now = DateTime.now();
        final oneHourAgo = now.subtract(const Duration(hours: 1));
        final docs = snapshot.data!.docs.where((doc) {
          final createdAt = doc.data()['createdAt'] as Timestamp?;
          if (createdAt == null) return true;
          return createdAt.toDate().isAfter(oneHourAgo);
        }).toList();

        if (docs.isEmpty) {
          return const Center(child: Text('No recent accepted jobs'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            return FadeInSlide(
              index: index,
              child: Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                elevation: 4,
                color: Colors.green.shade50,
                child: ListTile(
                  title: Text(data['medicineName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text('Status: ${data['status']}'),
                      const SizedBox(height: 4),
                      const Text('Click chat to talk to user', style: TextStyle(fontStyle: FontStyle.italic)),
                    ],
                  ),
                  trailing: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            chatId: doc.id,
                            title: 'Chat with User',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat),
                    label: const Text('Chat'),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _acceptRequest(String requestId) async {
    try {
      // 1. Check/Request location permission
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      // 2. Get current position
      final position = await Geolocator.getCurrentPosition();

      // 3. Accept request with location
      await RequestService.acceptRequest(
        requestId, 
        currentPharmacistId, 
        position.latitude, 
        position.longitude
      );
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request accepted and location shared!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _cancelRequest(String requestId) async {
    try {
      await RequestService.cancelRequest(requestId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request cancelled')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
