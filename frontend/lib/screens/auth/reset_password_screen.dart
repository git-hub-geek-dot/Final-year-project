import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../theme/app_colors.dart';
import '../../widgets/gradient_button.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final tokenController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  bool loading = false;
  String? message;

  @override
  void dispose() {
    tokenController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> resetPassword() async {
    final token = tokenController.text.trim();
    final password = passwordController.text.trim();
    final confirm = confirmController.text.trim();

    if (token.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() => message = "All fields are required");
      return;
    }

    if (password != confirm) {
      setState(() => message = "Passwords do not match");
      return;
    }

    if (password.length < 6) {
      setState(() => message = "Password must be at least 6 characters");
      return;
    }

    setState(() {
      loading = true;
      message = null;
    });

    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/reset-password"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "token": token,
          "password": password,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password reset successful")),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
      } else {
        final data = jsonDecode(response.body);
        setState(() => message = data["message"] ?? "Reset failed");
      }
    } catch (_) {
      if (mounted) {
        setState(() => message = "Network error. Please try again.");
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _inputField({
    required IconData icon,
    required String hint,
    required TextEditingController controller,
    bool obscure = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        maxLines: maxLines,
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
      appBar: AppBar(title: const Text("Reset Password")),
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
                  const Text(
                    "Set a new password",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Paste the reset token from your email.",
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  _inputField(
                    icon: Icons.key,
                    hint: "Reset Token",
                    controller: tokenController,
                    maxLines: 2,
                  ),
                  _inputField(
                    icon: Icons.lock,
                    hint: "New Password",
                    controller: passwordController,
                    obscure: true,
                  ),
                  _inputField(
                    icon: Icons.lock_outline,
                    hint: "Confirm Password",
                    controller: confirmController,
                    obscure: true,
                  ),
                  if (message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        message!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 8),
                  loading
                      ? const CircularProgressIndicator()
                      : AbsorbPointer(
                          absorbing: loading,
                          child: Opacity(
                            opacity: loading ? 0.6 : 1,
                            child: GradientButton(
                              text: "Reset Password",
                              onTap: resetPassword,
                            ),
                          ),
                        ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: loading
                        ? null
                        : () => Navigator.pushNamed(context, "/"),
                    child: const Text("Back to login"),
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
