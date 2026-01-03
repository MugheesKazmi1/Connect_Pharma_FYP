import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:connect_pharma/screens/WelcomeScreen.dart';
import 'screens/RoleSelectionScreen.dart';
import 'screens/SignUpScreen.dart';
import 'screens/LoginScreen.dart';
import 'screens/HomeScreen.dart';
import 'services/auth_service.dart';
import 'firebase_options.dart'; 
import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'theme.dart';
import 'dart:developer' as developer;


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    MapboxOptions.setAccessToken("pk.eyJ1IjoibXVnaGVlc2them1pMTIzIiwiYSI6ImNtang3cWdoODVqYXMzZnM1Z2l0azBrZjQifQ.gBRIdmrctf3wALBo5pTaTg");
  }
  try {
    developer.log('Firebase options projectId: ${DefaultFirebaseOptions.currentPlatform.projectId}');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    developer.log('Firebase initialized. apps: ${Firebase.apps.map((e) => e.name).toList()}');
  } catch (e, st) {
    developer.log('Firebase.initializeApp failed: $e\n$st', level: 1000);
    // Optionally show a user-facing error by running app and presenting message.
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Connect-Pharma',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (_) => const WelcomeScreen(),
        '/roles': (_) => const RoleSelectionScreen(),
        '/signup': (_) => const SignUpScreen(),
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
      },
    );
  }
}