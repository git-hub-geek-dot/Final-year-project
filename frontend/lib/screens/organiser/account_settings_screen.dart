import 'package:flutter/material.dart';
import '../../services/preferences_service.dart';
import 'change_password_screen.dart';
import 'update_email_screen.dart';
import 'update_phone_screen.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  bool newApplications = true;
  bool eventUpdates = true;
  bool promotions = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    newApplications = await PreferencesService.getNewApplications();
    eventUpdates = await PreferencesService.getEventUpdates();
    promotions = await PreferencesService.getPromotions();
    setState(() {});
  }

  /// 🔥 DELETE ACCOUNT LOGIC
  Future<void> _deleteAccount(BuildContext context) async {
    // Simulate API delay
    await Future.delayed(const Duration(seconds: 1));

    // Clear local data
    await PreferencesService.clearAll();

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Account deleted successfully"),
        backgroundColor: Colors.red,
      ),
    );

    // Redirect to Login / Welcome screen
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login', // 🔁 change if your route name is different
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Account Settings"),
        backgroundColor: const Color(0xFF3B82F6),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _settingTile(
            icon: Icons.lock_outline,
            title: "Change Password",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChangePasswordScreen(),
                ),
              );
            },
          ),

          _settingTile(
            icon: Icons.email_outlined,
            title: "Update Email",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const UpdateEmailScreen(),
                ),
              );
            },
          ),

          _settingTile(
            icon: Icons.phone_outlined,
            title: "Update Phone Number",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const UpdatePhoneScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 30),

          const Text(
            "Preferences",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),

          SwitchListTile(
            title: const Text("New Volunteer Applications"),
            value: newApplications,
            onChanged: (val) async {
              setState(() => newApplications = val);
              await PreferencesService.setNewApplications(val);
            },
          ),

          SwitchListTile(
            title: const Text("Event Updates"),
            value: eventUpdates,
            onChanged: (val) async {
              setState(() => eventUpdates = val);
              await PreferencesService.setEventUpdates(val);
            },
          ),

          SwitchListTile(
            title: const Text("Promotional Notifications"),
            value: promotions,
            onChanged: (val) async {
              setState(() => promotions = val);
              await PreferencesService.setPromotions(val);
            },
          ),

          const SizedBox(height: 30),

          _dangerTile(
            icon: Icons.pause_circle_outline,
            title: "Deactivate Account",
            onTap: () {
              _showConfirmDialog(
                context,
                "Deactivate Account",
                "Your account will be temporarily disabled.",
                onConfirm: () {
                  // You can add deactivate logic later
                },
              );
            },
          ),

          _dangerTile(
            icon: Icons.delete_outline,
            title: "Delete Account",
            onTap: () {
              _showConfirmDialog(
                context,
                "Delete Account",
                "This action is irreversible. All data will be lost.",
                onConfirm: () => _deleteAccount(context),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 🔹 NORMAL SETTING TILE
Widget _settingTile({
  required IconData icon,
  required String title,
  required VoidCallback onTap,
}) {
  return ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 4),
    leading: Icon(icon, color: Colors.grey),
    title: Text(title),
    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
    onTap: onTap,
  );
}

/// 🔹 DANGER TILE
Widget _dangerTile({
  required IconData icon,
  required String title,
  required VoidCallback onTap,
}) {
  return ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 4),
    leading: Icon(icon, color: Colors.red),
    title: Text(
      title,
      style: const TextStyle(color: Colors.red),
    ),
    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
    onTap: onTap,
  );
}

/// 🔥 CONFIRMATION DIALOG (REUSABLE)
void _showConfirmDialog(
  BuildContext context,
  String title,
  String message, {
  required VoidCallback onConfirm,
}) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
          child: const Text("Confirm"),
        ),
      ],
    ),
  );
}
