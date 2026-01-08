import 'package:flutter/material.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Help & Support"),
        backgroundColor: const Color(0xFF3B82F6),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            "How can we help you?",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          _helpTile(
            icon: Icons.question_answer_outlined,
            title: "Frequently Asked Questions",
            subtitle: "Find answers to common questions",
            onTap: () {
              // TODO: FAQ screen
            },
          ),

          _helpTile(
            icon: Icons.support_agent,
            title: "Contact Support",
            subtitle: "Email our support team",
            onTap: () {
              _showContactDialog(context);
            },
          ),

          _helpTile(
            icon: Icons.bug_report_outlined,
            title: "Report a Problem",
            subtitle: "Tell us if something isn’t working",
            onTap: () {
              _showReportDialog(context);
            },
          ),

          const SizedBox(height: 30),

          const Text(
            "App Information",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          _infoTile("App Version", "1.0.0"),
          _infoTile("Developed By", "Volunteerx Team"),
          _infoTile("Support Email", "support@volunteerx.com"),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// 🔹 HELP TILE
Widget _helpTile({
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.shade200,
          blurRadius: 6,
        ),
      ],
    ),
    child: ListTile(
      leading: Icon(icon, color: const Color(0xFF22C55E)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: onTap,
    ),
  );
}

/// 🔹 INFO TILE
Widget _infoTile(String title, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

/// 📧 CONTACT SUPPORT (EMAIL ONLY)
void _showContactDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Contact Support"),
      content: const Text(
        "You can reach us at:\n\nsupport@volunteerx.com\n\nWe’ll get back to you as soon as possible.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close"),
        ),
      ],
    ),
  );
}

/// 🐞 REPORT PROBLEM
void _showReportDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Report a Problem"),
      content: const Text(
        "Please describe the issue and email it to:\n\nsupport@volunteerx.com",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("OK"),
        ),
      ],
    ),
  );
}
