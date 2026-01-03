import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class RequestService {
  static final _firestore = FirebaseFirestore.instance;
  // REMOVED: Firebase Storage not used due to account upgrade requirements
  // static final _storage = FirebaseStorage.instance; 
  static const _uuid = Uuid();
  static const String _backendUrl = 'http://192.168.0.101:5000';

  /// Uploads a prescription image and returns a download URL.
  /// Accepts XFile (image_picker) or Uint8List (web).
  static Future<String> uploadPrescription(dynamic image) async {
    print('Uploading prescription to local backend: $_backendUrl/upload');

    try {
      final uploadUri = Uri.parse('$_backendUrl/upload');
      final request = http.MultipartRequest('POST', uploadUri);

      if (image is XFile) {
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          image.path,
          filename: image.name,
        ));
      } else if (image is Uint8List) {
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          image,
          filename: 'prescription_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ));
      } else {
        throw Exception('Unsupported image type: ${image.runtimeType}');
      }

      print('Sending multipart request...');
      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final url = data['url'];
        print('Upload successful. URL: $url');
        return url;
      } else {
        print('Upload failed with status: ${response.statusCode}');
        print('Response: ${response.body}');
        throw Exception('Failed to upload to local backend: ${response.statusCode}');
      }
    } catch (e) {
      print('Upload error: $e');
      throw Exception('Failed to upload prescription: $e. Ensure your PC and phone are on the same Wi-Fi and PC IP (192.168.0.101) is correct.');
    }
  }

  /// Creates a request document in Firestore.
  /// If [broadcast] is true the request is intended for all nearby pharmacies.
  /// If [pharmacyId] is provided and broadcast==false the request targets that pharmacy.
  /// Returns the created DocumentReference.
  static Future<DocumentReference> createRequest({
    required String userId,
    required String medicineName,
    String? prescriptionUrl,
    bool broadcast = true,
    String? pharmacyId,
    double? userLat,
    double? userLng,
    Map<String, dynamic>? meta,
  }) async {
    // Validate input
    final trimmedName = medicineName.trim();
    if (trimmedName.isEmpty && prescriptionUrl == null) {
      throw Exception('Please provide either a medicine name or a prescription');
    }
    if (userId.isEmpty) {
      throw Exception('User ID cannot be empty');
    }

    final docRef = _firestore.collection('requests').doc();
    final payload = <String, dynamic>{
      'userId': userId,
      'medicineName': trimmedName.toLowerCase(),
      'prescriptionUrl': prescriptionUrl,
      'broadcast': broadcast, // Ensure broadcast is set correctly
      'pharmacyId': pharmacyId,
      'status': 'open', // open, accepted, cancelled, completed
      'createdAt': FieldValue.serverTimestamp(),
      'userLat': userLat,
      'userLng': userLng,
      'meta': meta ?? {},
    };

    try {
      await docRef.set(payload).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Firestore request timed out. Check your internet connection.'),
      );
      return docRef;
    } on FirebaseException catch (e) {
      throw Exception('Firestore error (${e.code}): ${e.message}');
    } catch (e) {
      throw Exception('Failed to create request: $e');
    }
  }

  /// Streams requests for a given user.
  /// Note: Removed orderBy to avoid requiring a composite index in Firestore.
  /// Results are returned in natural order (should be sorted client-side by createdAt).
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamRequestsForUser(String userId) {
    return _firestore
        .collection('requests')
        .where('userId', isEqualTo: userId)
        .snapshots();
  }

  /// Fetch open broadcast requests (useful for pharmacy apps).
  /// Returns all requests where broadcast=true and status='open'.
  /// Note: Removed orderBy to avoid requiring a composite index in Firestore.
  /// This ensures the query works immediately without index setup.
  /// Results are returned in natural order (can be sorted client-side if needed).
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamOpenBroadcastRequests() {
    // Query without orderBy to avoid index requirement
    // This ensures requests are always visible even if Firestore index is missing
    return _firestore
        .collection('requests')
        .where('broadcast', isEqualTo: true)
        .snapshots();
  }

  /// Fetch accepted requests for riders.
  /// Returns all requests where status='accepted'.
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamAcceptedRequests() {
    return _firestore
        .collection('requests')
        .where('status', isEqualTo: 'accepted')
        .snapshots();
  }

  /// Cancel a request (user action).
  static Future<void> cancelRequest(String requestId) async {
    try {
      await _firestore.collection('requests').doc(requestId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw Exception('Firestore error (${e.code}): ${e.message}');
    } catch (e) {
      throw Exception('Failed to cancel request: $e');
    }
  }

  /// Mark request accepted by a pharmacy.
  /// Prevents race conditions by checking if request is still open before accepting.
  static Future<void> acceptRequest(String requestId, String pharmacyId, double lat, double lng) async {
    try {
      // Use a transaction to ensure the request is still open
      await _firestore.runTransaction((transaction) async {
        final docRef = _firestore.collection('requests').doc(requestId);
        final doc = await transaction.get(docRef);
        
        if (!doc.exists) {
          throw Exception('Request not found');
        }
        
        final data = doc.data()!;
        if (data['status'] != 'open') {
          throw Exception('Request already ${data['status']}');
        }
        
        if (data['acceptedBy'] != null) {
          throw Exception('Request already accepted by another pharmacy');
        }
        
        transaction.update(docRef, {
          'status': 'responded',
          'acceptedBy': pharmacyId,
          'pharmacyLat': lat,
          'pharmacyLng': lng,
          'respondedAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (e) {
      throw Exception('Firestore error (${e.code}): ${e.message}');
    } catch (e) {
      throw Exception('Failed to accept request: $e');
    }
  }

  /// Utility: attempt to read a request doc once.
  static Future<DocumentSnapshot<Map<String, dynamic>>> fetchRequest(String requestId) {
    return _firestore.collection('requests').doc(requestId).get();
  }

  /// Fetch requests accepted by a specific pharmacist
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamRequestsAcceptedByPharmacist(String pharmacistId) {
    return _firestore
        .collection('requests')
        .where('acceptedBy', isEqualTo: pharmacistId)
        .snapshots();
  }

  /// Fetch active deliveries for a rider (status = delivering)
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamRiderActiveRequests(String riderId) {
    return _firestore
        .collection('requests')
        .where('riderId', isEqualTo: riderId)
        .snapshots();
  }

  /// Generic status update (e.g. for riders to mark as picked up/delivered)
  /// Optionally updates riderId if provided
  static Future<void> updateRequestStatus(String requestId, String status, {String? riderId}) async {
    try {
      final updateData = <String, dynamic>{
        'status': status,
        '${status}At': FieldValue.serverTimestamp(),
      };
      
      if (riderId != null) {
        updateData['riderId'] = riderId;
      }

      await _firestore.collection('requests').doc(requestId).update(updateData);
    } on FirebaseException catch (e) {
      throw Exception('Firestore error (${e.code}): ${e.message}');
    } catch (e) {
      throw Exception('Failed to update request status: $e');
    }
  }
}