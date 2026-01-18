import 'package:flutter/material.dart';

// 🔐 AUTH
import 'screens/auth/login_screen.dart';
import 'screens/auth/role_selection_screen.dart';
import 'screens/auth/register_volunteer_screen.dart';
import 'screens/auth/register_organiser_screen.dart';



// 🏠 HOME SCREENS
import 'screens/volunteer/volunteer_home_screen.dart';
import 'screens/organiser/organiser_home_screen.dart';
import 'screens/admin/admin_home_screen.dart';

// 👤 ORGANISER
import 'screens/organiser/organiser_profile_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // ✅ LOGIN IS DEFAULT LANDING PAGE
      initialRoute: '/',

      routes: {
        // 🔐 AUTH
        '/': (context) => const LoginScreen(),
        '/register': (context) => const RoleSelectionScreen(),
        '/register-volunteer': (context) =>
            const RegisterVolunteerScreen(),
        '/register-organiser': (context) =>
            const RegisterOrganiserScreen(),

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
