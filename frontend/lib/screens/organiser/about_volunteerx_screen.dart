import 'package:flutter/material.dart';

import '../../localization/localization_extensions.dart';

class AboutVolunteerxScreen extends StatelessWidget {
  const AboutVolunteerxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr("About VolunteerX")),
        backgroundColor: const Color(0xFF3B82F6),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context.tr("What is VolunteerX?")),
            _paragraph(
              context.tr(
                "VolunteerX is a platform designed to connect event organizers with passionate volunteers. It simplifies event management, volunteer hiring, and application tracking.",
              ),
            ),
            const SizedBox(height: 20),
            _sectionTitle(context.tr("Our Mission")),
            _paragraph(
              context.tr(
                "Our mission is to empower communities by making volunteering more accessible, transparent, and impactful for everyone.",
              ),
            ),
            const SizedBox(height: 20),
            _sectionTitle(context.tr("What You Can Do")),
            _bullet(context.tr("Create and manage events")),
            _bullet(context.tr("Review volunteer applications")),
            _bullet(context.tr("Hire trusted volunteers")),
            _bullet(context.tr("Track volunteer performance")),
            const SizedBox(height: 20),
            _sectionTitle(context.tr("Version")),
            _paragraph(context.tr("VolunteerX v1.0.0")),
            const SizedBox(height: 30),
            Center(
              child: Text(
                context.tr("Copyright 2026 VolunteerX. All rights reserved."),
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

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

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

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("- "),
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
