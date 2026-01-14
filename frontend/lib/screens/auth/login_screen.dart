import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/token_service.dart';
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
      print("LOGIN STARTED");

      final response = await http
          .post(
            Uri.parse("${ApiConfig.baseUrl}/login"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "email": emailController.text.trim(),
              "password": passwordController.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 5));

      print("STATUS: ${response.statusCode}");
      print("BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final String token = data["token"];
        final Map<String, dynamic> user = data["user"];
        final String role = user["role"];

        // ✅ SAVE TOKEN (TokenService - your existing system)
        await TokenService.saveToken(token);

        // ✅ ALSO SAVE TOKEN IN SharedPreferences (so EditProfile can read it)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("token", token);
        await prefs.setString("user", jsonEncode(user));

        print("TOKEN SAVED IN PREFS: ${prefs.getString("token")}");

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Login successful ✅")),
        );

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
        showError(response.body);
      }
    } catch (e) {
      print("LOGIN ERROR: $e");
      showError(e.toString());
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          prefixIcon: Icon(icon),
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
                  const Icon(Icons.volunteer_activism, size: 60),
                  const SizedBox(height: 12),
                  const Text(
                    "Login",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                    obscure: true,
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
                      : GradientButton(
                          text: "Login",
                          onTap: login,
                        ),

                  const SizedBox(height: 12),

                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, "/register"),
                    child: const Text("Don't have an account? Register"),
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