
import 'package:flutter/material.dart';
import '../../services/token_service.dart';
import 'login_screen.dart';



class LoggedInScreen extends StatelessWidget {

  const LoggedInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await TokenService.clearToken();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const LoginScreen(),
                ),
                (_) => false,
              );
            },
          )
        ],
      ),
      body: const Center(
        child: Text(
          "You are logged in 🎉",
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
