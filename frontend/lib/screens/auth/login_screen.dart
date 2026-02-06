import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/token_service.dart';
import '../../services/notification_service.dart';
import '../../config/api_config.dart';
import '../../theme/app_colors.dart';
import '../../widgets/gradient_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool _obscurePassword = true;
  String? errorMessage;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      showError("Email and password required");
      return;
    }

    setState(() => loading = true);

    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": emailController.text.trim(),
          "password": passwordController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final String token = data["token"];
        final String role = data["user"]["role"];
        final int userId = data["user"]["id"];

        // ✅ Save auth data in ONE place (TokenService)
        await TokenService.saveAuthData(
          token: token,
          userId: userId,
          role: role,
        );

        await NotificationService.init();
        await NotificationService.registerToken();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Login successful")),
        );

        // ✅ Role-based navigation
        if (role == "admin") {
          Navigator.pushReplacementNamed(context, "/admin-home");
        } else if (role == "organiser") {
          Navigator.pushReplacementNamed(context, "/organiser-home");
        } else if (role == "volunteer") {
          Navigator.pushReplacementNamed(context, "/volunteer-home");
        } else {
          showError("Unknown role: $role");
        }
      } else {
        final err = jsonDecode(response.body);
        showError(err["message"] ?? "Login failed");
      }
    } catch (e) {
      showError("Network error. Please try again.");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void showError(String msg) {
    setState(() => errorMessage = msg);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => errorMessage = null);
    });
  }

  Widget _inputField({
    required IconData icon,
    required String hint,
    required TextEditingController controller,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    bool? isObscured,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          prefixIcon: Icon(icon),
          suffixIcon: onToggleObscure == null
              ? null
              : IconButton(
                  onPressed: onToggleObscure,
                  icon: Icon(
                    (isObscured ?? true)
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                ),
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 120,
                    child: Image.asset('assets/images/volunteerx_logo.png'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Login",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  _inputField(
                    icon: Icons.email,
                    hint: "Email",
                    controller: emailController,
                  ),
                  _inputField(
                    icon: Icons.lock,
                    hint: "Password",
                    controller: passwordController,
                    obscure: _obscurePassword,
                    isObscured: _obscurePassword,
                    onToggleObscure: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),

                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  const SizedBox(height: 20),

                  loading
                      ? const CircularProgressIndicator()
                      : AbsorbPointer(
                          absorbing: loading,
                          child: Opacity(
                            opacity: loading ? 0.6 : 1,
                            child: GradientButton(
                              text: "Login",
                              onTap: login,
                            ),
                          ),
                        ),

                  const SizedBox(height: 12),

                  TextButton(
                    onPressed: loading
                        ? null
                        : () =>
                            Navigator.pushNamed(context, "/forgot-password"),
                    child: const Text("Forgot password?"),
                  ),

                  const SizedBox(height: 4),

                  TextButton(
                    onPressed: loading
                        ? null
                        : () =>
                            Navigator.pushNamed(context, "/register"),
                    child: const Text(
                      "Don't have an account? Register",
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
