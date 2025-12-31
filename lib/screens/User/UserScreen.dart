import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect_pharma/services/request_service.dart';

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  final _searchCtrl = TextEditingController();
  bool _loading = false;
  File? _prescription;
  final ImagePicker _picker = ImagePicker();
  // Track previous request statuses to detect changes
  final Map<String, String> _previousStatuses = {};
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    _listenToRequestStatusChanges();
  }

  /// Listen to user's requests and show notification when status changes to 'accepted'
  void _listenToRequestStatusChanges() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    RequestService.streamRequestsForUser(user.uid).listen((snapshot) {
      if (!mounted) return;

      // On initial load, just populate the status map without showing notifications
      if (_isInitialLoad) {
        for (var doc in snapshot.docs) {
          final requestId = doc.id;
          final data = doc.data();
          final currentStatus = data['status'] as String? ?? '';
          _previousStatuses[requestId] = currentStatus;
        }
        _isInitialLoad = false;
        return;
      }

      // After initial load, detect status changes
      for (var doc in snapshot.docs) {
        final requestId = doc.id;
        final data = doc.data();
        final currentStatus = data['status'] as String? ?? '';
        final previousStatus = _previousStatuses[requestId];

        // Detect status change from 'open' to 'accepted'
        if (previousStatus == 'open' && currentStatus == 'accepted') {
          final medicineName = data['medicineName'] as String? ?? '';
          // Capitalize first letter for better display
          final displayName = medicineName.isEmpty
              ? 'your request'
              : medicineName.length > 1
                  ? medicineName[0].toUpperCase() + medicineName.substring(1)
                  : medicineName.toUpperCase();
          _showNotification(
            'Request Accepted!',
            'Your request for "$displayName" has been accepted by a pharmacy.',
          );
        }

        // Update the previous status
        _previousStatuses[requestId] = currentStatus;
      }
    });
  }

  void _showNotification(String title, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickPrescription() async {
    final XFile? file =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    setState(() => _prescription = File(file.path));
  }

  Future<void> _uploadAndBroadcast() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('Please login first.');
      return;
    }
    setState(() => _loading = true);
    try {
      String? url;
      if (_prescription != null) {
        url = await RequestService.uploadPrescription(_prescription!);
      }
      await RequestService.createRequest(
        userId: user.uid,
        medicineName: _searchCtrl.text.trim(),
        prescriptionUrl: url,
        broadcast: true,
      );
      _showSnack('Request sent to nearby pharmacies');
      setState(() => _prescription = null);
    } catch (e) {
      _showSnack('Failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  void dispose() {
    _searchCtrl.dispose();
    _previousStatuses.clear();
    super.dispose();
  }

  Widget _profileHeader() {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? 'Guest User';
    final email = user?.email ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      child: Row(children: [
        CircleAvatar(radius: 26, child: const Icon(Icons.person)),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(displayName,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(email, style: const TextStyle(color: Colors.grey)),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (mounted)
              Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
          },
        )
      ]),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search medicine by name',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
            onSubmitted: (_) async {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null || _searchCtrl.text.trim().isEmpty) {
                _showSnack('Enter medicine name');
                return;
              }

              await RequestService.createRequest(
                userId: user.uid,
                medicineName: _searchCtrl.text.trim(),
                prescriptionUrl: null,
              );

              _showSnack('Request sent to pharmacies');
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
            icon: const Icon(Icons.upload_file), onPressed: _pickPrescription),
      ]),
    );
  }

  Widget _actionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      child: Row(children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _loading ? null : _uploadAndBroadcast,
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _loading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Upload Prescription'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton(
            onPressed: () =>
                _showSnack('AI suggestions not implemented in template'),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: const Text('Ask For Suggestions'),
          ),
        ),
      ]),
    );
  }

  Widget _mapPlaceholder() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      height: 220,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Center(
          child: Text('Map / Search results area',
              style: TextStyle(color: Colors.black54))),
    );
  }

  Widget _recentRequestsCard() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Recent Requests',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Amoxicillin 500mg'),
            subtitle: const Text('Sent 2h ago • Broadcast'),
            trailing: TextButton(
                onPressed: () => _showSnack('Track not implemented'),
                child: const Text('Track')),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Prescription (image)'),
            subtitle: const Text('Sent yesterday • Direct'),
            trailing: TextButton(
                onPressed: () => _showSnack('Details not implemented'),
                child: const Text('Details')),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final presName =
        _prescription != null ? _prescription!.path.split('/').last : 'No file';
    return Scaffold(
      appBar: AppBar(
        title: const Text('CONNECT-PHARMA'),
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => Navigator.maybePop(context)),
      ),
      body: SafeArea(
        child: ListView(
          children: [
            _profileHeader(),
            const SizedBox(height: 6),
            _searchBar(),
            const SizedBox(height: 6),
            _actionButtons(),
            const SizedBox(height: 10),
            _mapPlaceholder(),
            const SizedBox(height: 12),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('Selected file: $presName',
                    style: const TextStyle(color: Colors.black54))),
            const SizedBox(height: 12),
            _recentRequestsCard(),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSnack('Quick ask not implemented'),
        label: const Text('Quick Ask'),
        icon: const Icon(Icons.send),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (i) => _showSnack('Nav tap $i'),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.track_changes), label: 'Tracker'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Account'),
          BottomNavigationBarItem(icon: Icon(Icons.bubble_chart), label: 'AI'),
        ],
      ),
    );
  }
}
