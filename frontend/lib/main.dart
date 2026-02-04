import 'package:flutter/material.dart';

// 🔐 AUTH
import 'screens/auth/login_screen.dart';
import 'screens/auth/role_selection_screen.dart';
import 'screens/auth/register_volunteer_screen.dart';
import 'screens/auth/register_organiser_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/reset_password_screen.dart';



// 🏠 HOME SCREENS
import 'screens/volunteer/volunteer_home_screen.dart';
import 'screens/organiser/organiser_home_screen.dart';
import 'screens/admin/admin_home_screen.dart';

// 👤 ORGANISER
import 'screens/organiser/organiser_profile_screen.dart';
import 'services/token_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      home: const AuthGate(),

      routes: {
        // 🔐 AUTH
        '/': (context) => const LoginScreen(),
        '/register': (context) => const RoleSelectionScreen(),
        '/register-volunteer': (context) =>
            const RegisterVolunteerScreen(),
        '/register-organiser': (context) =>
            const RegisterOrganiserScreen(),
        '/forgot-password': (context) =>
          const ForgotPasswordScreen(),
        '/reset-password': (context) =>
          const ResetPasswordScreen(),

        // 🏠 ROLE HOMES
        '/volunteer-home': (context) =>
            const VolunteerHomeScreen(),
        '/organiser-home': (context) =>
            const OrganiserHomeScreen(),
        '/admin-home': (context) =>
            const AdminHomeScreen(),

        // 👤 ORGANISER PROFILE
        '/organiser-profile': (context) =>
            const OrganiserProfileScreen(),
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<_AuthState> _loadAuth() async {
    final token = await TokenService.getToken();
    final role = await TokenService.getRole();
    return _AuthState(token: token, role: role);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AuthState>(
      future: _loadAuth(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final token = snapshot.data?.token;
        final role = snapshot.data?.role;

        if (token == null || token.isEmpty || role == null || role.isEmpty) {
          return const LoginScreen();
        }

        if (role == "admin") {
          return const AdminHomeScreen();
        } else if (role == "organiser") {
          return const OrganiserHomeScreen();
        } else if (role == "volunteer") {
          return const VolunteerHomeScreen();
        }

        return const LoginScreen();
      },
    );
  }
}

class _AuthState {
  final String? token;
  final String? role;

  _AuthState({required this.token, required this.role});
}
