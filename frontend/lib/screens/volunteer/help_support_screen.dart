import 'package:flutter/material.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text(
          "Help & Support",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _supportTile(
              context,
              icon: Icons.quiz,
              title: "FAQs",
              subtitle: "Common questions answered",
              onTap: () => _showBottomSheet(
                context,
                title: "Frequently Asked Questions",
                content: const [
                  "• How do I apply for an event?\nTap on the Apply button on any event card.",
                  "• Can I cancel my application?\nYes, cancellation will be available once applications are approved.",
                  "• Are paid events guaranteed payments?\nPayments depend on organiser confirmation and event completion.",
                  "• How are badges earned?\nBadges are awarded based on completed events and participation level.",
                ],
              ),
            ),

            _supportTile(
              context,
              icon: Icons.build,
              title: "App Support",
              subtitle: "Issues with the app or login",
              onTap: () => _showBottomSheet(
                context,
                title: "App Support",
                content: const [
                  "• App not loading events?\nCheck your internet connection and try again.",
                  "• Login issues?\nMake sure your credentials are correct or use Forgot Password.",
                  "• App crashes or bugs?\nRestart the app or update to the latest version.",
                  "• Still facing issues?\nContact our support team via email.",
                ],
              ),
            ),

            _supportTile(
              context,
              icon: Icons.security,
              title: "Safety & Guidelines",
              subtitle: "Your safety matters",
              onTap: () => _showBottomSheet(
                context,
                title: "Safety & Guidelines",
                content: const [
                  "• Always verify event details before attending.",
                  "• Avoid sharing personal or financial information.",
                  "• Report suspicious organisers or events immediately.",
                  "• Follow community guidelines and event instructions.",
                ],
              ),
            ),

            _supportTile(
              context,
              icon: Icons.email,
              title: "Contact Us",
              subtitle: "Get in touch with our team",
              onTap: () => _showBottomSheet(
                context,
                title: "Contact VolunteerX",
                content: const [
                  "📩 Email Support",
                  "volunteerx@gmail.com",
                  "",
                  "Our team usually responds within 24–48 hours.",
                  "Please include screenshots or details for faster support.",
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= SUPPORT TILE =================
  Widget _supportTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF2E6BE6),
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  // ================= BOTTOM SHEET =================
  void _showBottomSheet(
    BuildContext context, {
    required String title,
    required List<String> content,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...content.map(
                  (text) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      text,
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
