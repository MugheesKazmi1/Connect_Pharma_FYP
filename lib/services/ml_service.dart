import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class MLService {
  // Use 10.0.2.2 for Android Emulator, localhost for iOS/Web
  static String get _baseUrl => kReleaseMode
      ? 'https://your-production-url.com' // TODO: Update for production
      : (defaultTargetPlatform == TargetPlatform.android
          ? 'http://192.168.0.101:5000' // Use PC local IP for physical devices
          : 'http://127.0.0.1:5000');

  static Future<Map<String, dynamic>> getAlternatives(String medicineName) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/predict'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'medicine_name': medicineName}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to load suggestions: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('ML Service Error: $e');
      return {
        'match': null,
        'message': 'Error connecting to AI service. Ensure backend is running.',
        'alternatives': []
      };
    }
  }
}
