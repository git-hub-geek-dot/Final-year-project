import 'package:flutter/material.dart';

class AboutVolunteerxScreen extends StatelessWidget {
  const AboutVolunteerxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("About Volunteerx"),
        backgroundColor: const Color(0xFF3B82F6),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle("What is Volunteerx?"),
            _paragraph(
              "Volunteerx is a platform designed to connect event organizers "
              "with passionate volunteers. It simplifies event management, "
              "volunteer hiring, and application tracking.",
            ),

            const SizedBox(height: 20),

            _sectionTitle("Our Mission"),
            _paragraph(
              "Our mission is to empower communities by making volunteering "
              "more accessible, transparent, and impactful for everyone.",
            ),

            const SizedBox(height: 20),

            _sectionTitle("What You Can Do"),
            _bullet("Create and manage events"),
            _bullet("Review volunteer applications"),
            _bullet("Hire trusted volunteers"),
            _bullet("Track volunteer performance"),

            const SizedBox(height: 20),

            _sectionTitle("Version"),
            _paragraph("Volunteerx v1.0.0"),

            const SizedBox(height: 30),

            Center(
              child: Text(
                "© 2026 Volunteerx. All rights reserved.",
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 SECTION TITLE
  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  // 🔹 PARAGRAPH TEXT
  Widget _paragraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }

  // 🔹 BULLET POINT
  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("•  "),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
