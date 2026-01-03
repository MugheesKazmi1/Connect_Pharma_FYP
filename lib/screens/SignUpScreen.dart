
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import 'package:connect_pharma/screens/User/UserScreen.dart';
import 'package:connect_pharma/screens/LoginScreen.dart';
import 'Pharmacist/PharmacistScreen.dart';
import 'package:connect_pharma/screens/Rider/RiderScreen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _role;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is String) {
      // normalize incoming role strings
      final s = arg.trim().toLowerCase();
      if (s == 'pharmacist') {
        _role = 'pharmacist';
      } else if (s == 'driver' || s == 'rider') {
        _role = 'rider';
      } else if (s == 'user') {
        _role = 'user';
      } else {
        _role = s; // fallback
      }
      debugPrint('SignUpScreen: normalized role=$_role (from arg="$arg")');
    }
  }

  void _showMsg(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_role == null) {
      _showMsg('Please select a role before signing up.');
      return;
    }

    setState(() => _loading = true);
    try {
      debugPrint('Signing up role=$_role email=${_emailCtrl.text}');
      final cred = await authService.signUp(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        role: _role!,
        displayName: _nameCtrl.text.trim(),
      );
      debugPrint('SignUp succeeded uid=${cred.user?.uid}');

      // navigate to role-specific screen
      if (_role == 'pharmacist') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PharmacistScreen()));
      } else if (_role == 'rider') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RiderScreen()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UserScreen()));
      }
    } catch (e, st) {
      debugPrint('SignUp error: $e\n$st');
      _showMsg('Sign up failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roleLabel = _role != null ? "${_role![0].toUpperCase()}${_role!.substring(1)}" : 'Unknown';
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Create Account'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Join as a $roleLabel',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn().slideY(begin: -0.2, end: 0),
              const SizedBox(height: 32),
              CustomTextField(
                controller: _nameCtrl,
                label: 'Full Name',
                hint: 'Enter your full name',
                prefixIcon: Icons.person_outline,
                validator: (v) => (v ?? '').trim().isEmpty ? 'Enter name' : null,
              ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.05, end: 0),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _emailCtrl,
                label: 'Email',
                hint: 'Enter your email',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v ?? '').contains('@') ? null : 'Enter valid email',
              ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.05, end: 0),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _passCtrl,
                label: 'Password',
                hint: 'Create a password',
                prefixIcon: Icons.lock_outline,
                obscureText: true,
                validator: (v) => (v ?? '').length >= 6 ? null : 'Min 6 chars',
              ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.05, end: 0),
              const SizedBox(height: 32),
              CustomButton(
                text: 'Sign Up',
                onPressed: _submit,
                isLoading: _loading,
              ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: _loading ? null : () => Navigator.pushReplacementNamed(context, '/login'),
                  child: RichText(
                    text: TextSpan(
                      text: 'Already have an account? ',
                      style: Theme.of(context).textTheme.bodyMedium,
                      children: [
                        TextSpan(
                          text: 'Login',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 800.ms),
            ],
          ),
        ),
      ),
    );
  }
}