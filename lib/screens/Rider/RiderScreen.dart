import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connect_pharma/services/request_service.dart';
import 'package:connect_pharma/screens/ChatScreen.dart';
import 'package:connect_pharma/widgets/FadeInSlide.dart';
import 'package:connect_pharma/screens/Rider/RiderMapScreen.dart';

class RiderScreen extends StatefulWidget {
  const RiderScreen({super.key});

  @override
  State<RiderScreen> createState() => _RiderScreenState();
}

class _RiderScreenState extends State<RiderScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
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
    _notificationSubscription = RequestService.streamAcceptedRequests().listen((snapshot) {
      final now = DateTime.now();
      final oneHourAgo = now.subtract(const Duration(hours: 1));
      
      final activeDocs = snapshot.docs.where((doc) {
        final data = doc.data();
        final status = data['status'];
        final createdAt = data['createdAt'] as Timestamp?;
        if (status != 'accepted') return false;
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
        title: const Text('Rider Dashboard'),
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
            Tab(text: 'New Orders'),
            Tab(text: 'My Deliveries'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildNewOrders(),
              _buildMyDeliveries(),
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
    final medicineName = data['medicineName'] ?? 'Unknown Medicine';

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
            border: Border.all(color: Colors.orange.withOpacity(0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.1),
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
                      color: Colors.orange.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delivery_dining, color: Colors.orange),
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
                              'NEW ORDER READY',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
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
                      child: const Text('Ignore', style: TextStyle(fontWeight: FontWeight.w600)),
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
                        _startDelivery(id);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Deliver Now', style: TextStyle(fontWeight: FontWeight.bold)),
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

  // Tab 1: Orders ready for pickup (Accepted by pharmacist)
  Widget _buildNewOrders() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: RequestService.streamAcceptedRequests(),
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
                
                if (status != 'accepted') return false; // Client-side status filter
                if (createdAt == null) return true;
                return createdAt.toDate().isAfter(oneHourAgo);
              }).toList();

              if (docs.isEmpty) {
                return const Center(
                  child: Text('No recent orders waiting for pickup'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  final medicineName = data['medicineName'] ?? 'Unknown Medicine';
                  final pharmacyId = data['acceptedBy'] ?? 'Unknown Pharmacy';
                  
                  return FadeInSlide(
                    index: index,
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    medicineName.toUpperCase(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Ready',
                                    style: TextStyle(
                                      color: Colors.green.shade800,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.store, size: 16, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Pharmacy ID: $pharmacyId',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.delivery_dining),
                                label: const Text('Start Delivery'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => _startDelivery(doc.id),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // Tab 2: Orders currently being delivered by this rider
  Widget _buildMyDeliveries() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Error: Not logged in'));

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: RequestService.streamRiderActiveRequests(user.uid),
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
          
          if (status != 'delivering') return false; // Client-side status filter
          if (createdAt == null) return true;
          return createdAt.toDate().isAfter(oneHourAgo);
        }).toList();

        if (docs.isEmpty) {
          return const Center(
            child: Text('No recent active deliveries'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final medicineName = data['medicineName'] ?? 'Unknown';
            
            return FadeInSlide(
              index: index,
              child: Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                elevation: 4,
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medicineName.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.orange, size: 16),
                          SizedBox(width: 4),
                          Text('In Transit', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.check),
                              label: const Text('Complete'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              onPressed: () => _completeDelivery(doc.id),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.map),
                              label: const Text('Map'),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RiderMapScreen(
                                      requestData: data,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.chat),
                              label: const Text('Chat'),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(
                                      chatId: '${doc.id}_rider',
                                      title: 'Chat with User',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
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

  Future<void> _startDelivery(String requestId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await RequestService.updateRequestStatus(
        requestId, 
        'delivering',
        riderId: user.uid
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery started! Moved to "My Deliveries"')),
        );
        // Switch to My Deliveries tab
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _completeDelivery(String requestId) async {
    try {
      await RequestService.updateRequestStatus(requestId, 'completed');
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order completed!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
