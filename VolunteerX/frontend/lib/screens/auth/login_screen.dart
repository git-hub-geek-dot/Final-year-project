import 'logged_in_screen.dart';

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/token_service.dart';


import 'register_screen.dart';


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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Login"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            if (errorMessage != null)
  Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      errorMessage!,
      style: const TextStyle(
        color: Colors.red,
        fontSize: 14,
      ),
    ),
  ),


            loading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          loading = true;
                           errorMessage = null;
                           });


                        final authService = AuthService();
                        final response = await authService.login(
                          emailController.text,
                          passwordController.text,
                        );

                        if (response.containsKey("token")) {
                          await TokenService.saveToken(response["token"]);

                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LoggedInScreen(),

                            ),
                          );
                        } else {
                          setState(() {
                            errorMessage = response["error"] ?? "Invalid credentials";
                            });
                            // Auto-hide error after 3 seconds
                            Future.delayed(const Duration(seconds: 3), () {
    if (mounted) {
      setState(() {
        errorMessage = null;
      });
    }
  });
}



                        setState(() => loading = false);
                      },
                      child: const Text("Login"),
                    ),
                  ),

            const SizedBox(height: 10),

            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RegisterScreen(),
                  ),
                );
              },
              child: const Text("Don’t have an account? Register"),
            ),
          ],
        ),
      ),
    );
  }
}
