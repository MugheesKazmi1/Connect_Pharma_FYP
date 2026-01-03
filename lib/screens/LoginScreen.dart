import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import 'package:connect_pharma/screens/User/UserScreen.dart';
import 'package:connect_pharma/screens/Pharmacist/PharmacistScreen.dart';
import 'package:connect_pharma/screens/Rider/RiderScreen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  final _formKey = GlobalKey<FormState>();

  void _show(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
      ));

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
     setState(() => _loading = true);
    try {
      final cred = await authService.signIn(email: _email.text.trim(), password: _pass.text);
      if (!mounted) return;
      
      final role = await authService.fetchRole(cred.user!.uid);
      if (!mounted) return;

      if (role == 'pharmacist') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PharmacistScreen()));
      } else if (role == 'rider') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RiderScreen()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UserScreen()));
      }
    } catch (e) {
      _show(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Text(
                  'Welcome Back!',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: AppTheme.primaryColor,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn().slideY(begin: -0.2, end: 0),
                const SizedBox(height: 8),
                Text(
                  'Login to continue',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 48),
                CustomTextField(
                  controller: _email,
                  label: 'Email',
                  hint: 'Enter your email',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v?.isEmpty ?? true) ? 'Email is required' : null,
                ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1, end: 0),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _pass,
                  label: 'Password',
                  hint: 'Enter your password',
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                  validator: (v) => (v?.isEmpty ?? true) ? 'Password is required' : null,
                ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1, end: 0),
                const SizedBox(height: 32),
                CustomButton(
                  text: 'Login',
                  onPressed: _login,
                  isLoading: _loading,
                ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2, end: 0),
                 const SizedBox(height: 24),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/roles'),
                    child: Text(
                      "Don't have an account? Sign Up",
                      style: TextStyle(color: AppTheme.primaryColor),
                    ),
                  ),
                ).animate().fadeIn(delay: 800.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}