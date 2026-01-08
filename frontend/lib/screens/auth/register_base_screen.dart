import 'login_screen.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../theme/app_colors.dart';
import '../../widgets/gradient_button.dart';

abstract class RegisterBaseScreen extends StatefulWidget {
  const RegisterBaseScreen({super.key});

  String get role;
  bool get showOrganiserFields => false;
  bool get showVolunteerFields => false;

  @override
  State<RegisterBaseScreen> createState() => _RegisterBaseScreenState();
}

class _RegisterBaseScreenState extends State<RegisterBaseScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final contactController = TextEditingController();
  final cityController = TextEditingController();
  final govIdController = TextEditingController();

  bool loading = false;
  String? errorMessage;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    contactController.dispose();
    cityController.dispose();
    govIdController.dispose();
    super.dispose();
  }

  Future<void> register() async {
    if (nameController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty) {
      showError("Name, email and password are required");
      return;
    }

    if (widget.role == "organiser" &&
        contactController.text.trim().isEmpty) {
      showError("Contact number is required for organiser");
      return;
    }

    setState(() => loading = true);

    try {
      final Map<String, dynamic> body = {
        "name": nameController.text.trim(),
        "email": emailController.text.trim(),
        "password": passwordController.text.trim(),
        "role": widget.role,
      };

      if (widget.showVolunteerFields) {
        body.addAll({
          "contact_number": contactController.text.trim().isEmpty
              ? null
              : contactController.text.trim(),
          "city": cityController.text.trim().isEmpty
              ? null
              : cityController.text.trim(),
        });
      }

      if (widget.showOrganiserFields) {
        body.addAll({
          "contact_number": contactController.text.trim(),
          "government_id": govIdController.text.trim().isEmpty
              ? null
              : govIdController.text.trim(),
        });
      }

      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        showError(response.body);
      }
    } catch (e) {
      showError(e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void showError(String msg) {
    setState(() => errorMessage = msg);
  }

  Widget inputField({
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
                  Text(
                    widget.role == "organiser"
                        ? "Organiser Registration"
                        : "Volunteer Registration",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  inputField(
                    icon: Icons.person,
                    hint: "Name",
                    controller: nameController,
                  ),
                  inputField(
                    icon: Icons.email,
                    hint: "Email",
                    controller: emailController,
                  ),
                  inputField(
                    icon: Icons.lock,
                    hint: "Password",
                    controller: passwordController,
                    obscure: true,
                  ),

                  if (widget.showVolunteerFields) ...[
                    inputField(
                      icon: Icons.phone,
                      hint: "Contact number (optional)",
                      controller: contactController,
                    ),
                    inputField(
                      icon: Icons.location_city,
                      hint: "City (optional)",
                      controller: cityController,
                    ),
                  ],

                  if (widget.showOrganiserFields) ...[
                    inputField(
                      icon: Icons.phone,
                      hint: "Contact number",
                      controller: contactController,
                    ),
                    inputField(
                      icon: Icons.badge,
                      hint: "Government ID (optional)",
                      controller: govIdController,
                    ),
                  ],

                  if (errorMessage != null)
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),

                  const SizedBox(height: 20),

                  loading
                      ? const CircularProgressIndicator()
                      : GradientButton(
                          text: "Register",
                          onTap: register,
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