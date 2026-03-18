import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/api_config.dart';
import '../../services/token_service.dart';
import '../../services/verification_service.dart';
import '../../services/rating_service.dart';
import '../../widgets/organiser_bottom_nav.dart';
import '../../localization/locale_controller.dart';
import '../../localization/localization_extensions.dart';
import 'account_settings_screen.dart';
import 'about_volunteerx_screen.dart';
import 'edit_profile_screen.dart';
import 'get_verified_screen.dart';
import 'organiser_activity_screen.dart';
import 'my_events_screen.dart';
import '../notifications/notifications_screen.dart';
import '../volunteer/my_badges_screen.dart';

class OrganiserProfileScreen extends StatefulWidget {
  const OrganiserProfileScreen({super.key});

  @override
  State<OrganiserProfileScreen> createState() =>
      _OrganiserProfileScreenState();
}

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr("Help & Support")),
        backgroundColor: const Color(0xFF3B82F6),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            context.tr("How can we help you?"),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _helpTile(
            icon: Icons.question_answer_outlined,
            title: context.tr("Frequently Asked Questions"),
            subtitle: context.tr("Find answers to common questions"),
            onTap: () {
              _showFaqDialog(context);
            },
          ),
          _helpTile(
            icon: Icons.support_agent,
            title: context.tr("Contact Support"),
            subtitle: context.tr("Email our support team"),
            onTap: () {
              _showContactDialog(context);
            },
          ),
          _helpTile(
            icon: Icons.bug_report_outlined,
            title: context.tr("Report a Problem"),
            subtitle: context.tr("Tell us if something isn't working"),
            onTap: () {
              _showReportDialog(context);
            },
          ),
          const SizedBox(height: 30),
          Text(
            context.tr("App Information"),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          _infoTile(context.tr("App Version"), "1.0.0"),
          _infoTile(context.tr("Developed By"), context.tr("Volunteerx Team")),
          _infoTile(context.tr("Support Email"), "volunteerxteam@gmail.com"),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

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

const List<Map<String, String>> _supportFaqs = [
  {
    "question": "How do I manage my events?",
    "answer":
        "Open My Events to edit event details, update capacity, or change event status.",
  },
  {
    "question": "How does verification work?",
    "answer":
        "Go to Get Verified, submit the required documents, and wait for admin review.",
  },
  {
    "question": "What is the strike/suspension policy?",
    "answer":
        "Repeated violations may lead to strikes. 2 strikes: 3-day suspension, 3 strikes: 7-day suspension, 4 strikes: account ban.",
  },
  {
    "question": "Can I edit an event after publishing it?",
    "answer":
        "Yes. Use My Events to update event information. Volunteers will see the latest saved details.",
  },
  {
    "question": "Why is my event not getting applications?",
    "answer":
        "Check event date, location, category, and description clarity. Better details usually improve applications.",
  },
  {
    "question": "Can I report a volunteer issue?",
    "answer":
        "Yes. Use reporting options in the app and include clear details for faster review.",
  },
  {
    "question": "How do I update my profile information?",
    "answer":
        "Open your profile and tap Edit Profile to update your details.",
  },
  {
    "question": "How can I contact support quickly?",
    "answer":
        "Email volunteerxteam@gmail.com and attach screenshots if possible.",
  },
];

void _showFaqDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.tr("Frequently Asked Questions")),
      content: SizedBox(
        width: MediaQuery.of(dialogContext).size.width * 0.85,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _supportFaqs
                .map(
                  (faq) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    color: const Color(0xFFF5F6FA),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Theme(
                      data: Theme.of(dialogContext).copyWith(
                        dividerColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        childrenPadding:
                            const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        title: Text(
                          context.tr(faq["question"] ?? ""),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              context.tr(faq["answer"] ?? ""),
                              style: const TextStyle(height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr("Close")),
        ),
      ],
    ),
  );
}

void _showContactDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(context.tr("Contact Support")),
      content: Text(
        context.tr(
          "You can reach us at:\n\nvolunteerxteam@gmail.com\n\nWe'll get back to you as soon as possible.",
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr("Close")),
        ),
      ],
    ),
  );
}

void _showReportDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(context.tr("Report a Problem")),
      content: Text(
        context.tr(
          "Please describe the issue and email it to:\n\nvolunteerxteam@gmail.com",
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr("OK")),
        ),
      ],
    ),
  );
}

class _OrganiserProfileScreenState extends State<OrganiserProfileScreen> {
  bool loading = true;
  String? errorMessage;

  String? name;
  String? email;
  String? city;
  String? role;
  String? profilePictureUrl;
  String? verificationStatus;
  String _ratingValue = "0.0";
  String _ratingCount = "0";

  @override
  void initState() {
    super.initState();
    _refreshProfile();
  }

  Future<void> _refreshProfile() async {
    await Future.wait([
      fetchProfile(),
      loadVerificationStatus(),
      loadRatingSummary(),
    ]);
  }

  Future<void> loadVerificationStatus() async {
    final status = await VerificationService.getStatus();
    setState(() {
      verificationStatus = status;
    });
  }

  Future<void> fetchProfile() async {
    try {
      setState(() {
        loading = true;
        errorMessage = null;
      });

      final token = await TokenService.getToken();
      if (token == null || token.isEmpty) {
        setState(() {
          loading = false;
          errorMessage = context.tr("Token not found. Please login again.");
        });
        return;
      }

      final url = Uri.parse("${ApiConfig.baseUrl}/profile");
      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json"
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          name = data["name"];
          email = data["email"];
          city = data["city"];
          profilePictureUrl =
              _normalizeProfileImageUrl(data["profile_picture_url"]?.toString());
          role = data["role"];
          loading = false;
        });
      } else {
        setState(() {
          loading = false;
          errorMessage = context.tr(
            "Error {code}: {message}",
            args: {
              "code": response.statusCode.toString(),
              "message": response.body,
            },
          );
        });
      }
    } catch (e) {
      setState(() {
        loading = false;
        errorMessage = context.tr("Error: {error}", args: {"error": "$e"});
      });
    }
  }

  String? _normalizeProfileImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;

    final baseUri = Uri.parse(ApiConfig.baseUrl);
    final origin =
        "${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}";

    if (url.startsWith("/uploads/")) {
      return "$origin$url";
    }

    if (url.startsWith("uploads/")) {
      return "$origin/$url";
    }

    final parsed = Uri.tryParse(url);
    if (parsed != null && parsed.hasScheme) {
      if (ApiConfig.useCloud) {
        return url;
      }

      final host = parsed.host;
      final isLocalLike = host == "localhost" ||
          host == "127.0.0.1" ||
          host.startsWith("10.") ||
          host.startsWith("192.168.") ||
          host.startsWith("172.");

      if (isLocalLike && host != baseUri.host) {
        final pathWithQuery =
            parsed.hasQuery ? "${parsed.path}?${parsed.query}" : parsed.path;
        return "$origin$pathWithQuery";
      }
    }

    return url;
  }

  Future<void> loadRatingSummary() async {
    try {
      final userId = await TokenService.getUserId();
      if (userId == null) return;

      final data = await RatingService.fetchSummary(userId);
      setState(() {
        _ratingValue = data["rating"]?.toString() ?? _ratingValue;
        _ratingCount = data["review_count"]?.toString() ?? _ratingCount;
      });
    } catch (_) {
      // Keep defaults
    }
  }

  Future<void> handleDeactivateAccount(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("Token not found. Please login again."))),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr("Deactivate Account")),
        content: Text(
          context.tr(
            "Are you sure you want to deactivate your account?\n\nYour data will remain saved, but you will not be able to login again.",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr("Cancel")),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              context.tr("Deactivate"),
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await http.put(
        Uri.parse("${ApiConfig.baseUrl}/account/deactivate"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      Navigator.pop(context);

      if (response.statusCode == 200) {
        await TokenService.clearToken();
        await LocaleController.clearAllPreserveLocale();

        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr("Account deactivated"))),
        );

        Navigator.pushNamedAndRemoveUntil(
          context,
          '/',
          (route) => false,
        );
      } else {
        String msg = context.tr("Deactivate failed");
        try {
          final data = jsonDecode(response.body);
          msg = data["message"] ?? data["error"] ?? msg;
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr("Server error: {error}", args: {"error": "$e"}),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: errorMessage != null
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : Column(
                        children: [
                      // 🔷 HEADER
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF22C55E)],
                          ),
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(40),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Volunteerx",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const NotificationsScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.notifications,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            CircleAvatar(
                              radius: 38,
                              backgroundColor: Colors.white,
                              backgroundImage: profilePictureUrl != null
                                  ? NetworkImage(profilePictureUrl!)
                                  : null,
                              onBackgroundImageError: profilePictureUrl != null
                                  ? (_, __) {
                                      if (!mounted || profilePictureUrl == null) {
                                        return;
                                      }
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                        if (!mounted ||
                                            profilePictureUrl == null) {
                                          return;
                                        }
                                        setState(() => profilePictureUrl = null);
                                      });
                                    }
                                  : null,
                              child: profilePictureUrl == null
                                  ? const Icon(Icons.person, size: 40)
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  name ?? "",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (verificationStatus == "approved") ...[
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.verified,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.tr(
                                "Rating: {rating} ({count})",
                                args: {
                                  "rating": _ratingValue,
                                  "count": _ratingCount,
                                },
                              ),
                              style: const TextStyle(color: Colors.white70),
                            ),
                            Text(
                              city == null || city!.isEmpty
                                  ? context.tr("City not set")
                                  : context.tr(
                                      "{city}, India",
                                      args: {"city": city!},
                                    ),
                              style:
                                  const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: () async {
                                final updated = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const EditProfileScreen(),
                                  ),
                                );

                                if (updated == true) {
                                  fetchProfile();
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  context.tr("Edit Profile"),
                                  style: TextStyle(
                                    color: Color(0xFF22C55E),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 📋 OPTIONS
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            _profileOption(
                              context: context,
                              icon: Icons.event,
                              text: context.tr("My Events"),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const MyEventsScreen(),
                                  ),
                                );
                              },
                            ),
                            _profileOption(
                              context: context,
                              icon: Icons.manage_accounts,
                              text: context.tr("Account Settings"),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const AccountSettingsScreen(),
                                  ),
                                );
                              },
                            ),
                            _profileOption(
                              context: context,
                              icon: Icons.emoji_events,
                              text: context.tr("My Badges"),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const MyBadgesScreen(),
                                  ),
                                );
                              },
                            ),
                            _profileOption(
                              context: context,
                              icon: Icons.verified,
                              text: verificationStatus == "pending"
                                  ? context.tr("Verification Under Review")
                                  : verificationStatus == "approved"
                                      ? context.tr("Verified")
                                      : context.tr("Get Verified"),
                              onTap: () {
                                final status =
                                    (verificationStatus ?? '').toLowerCase();

                                if (status == 'approved') {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        context.tr("Your account is already verified."),
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                if (status == 'pending') {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        context.tr("Your verification request is under review."),
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const OrganiserGetVerifiedScreen(),
                                  ),
                                );
                              },
                            ),
                            _profileOption(
                              context: context,
                              icon: Icons.dashboard,
                              text: context.tr("Organisation Activity"),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const OrganiserActivityScreen(),
                                  ),
                                );
                              },
                            ),
                            _languageOption(context),

                            _profileOption(
                              context: context,
                              icon: Icons.help_outline,
                              text: context.tr("Help & Support"),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const HelpSupportScreen(),
                                  ),
                                );
                              },
                            ),
                            _profileOption(
                              context: context,
                              icon: Icons.info_outline,
                              text: context.tr("About Volunteerx"),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const AboutVolunteerxScreen(),
                                  ),
                                );
                              },
                            ),
                            _profileOption(
                              context: context,
                              icon: Icons.logout,
                              text: context.tr("Logout"),
                              isLogout: true,
                            ),
                            _profileOption(
                              context: context,
                              icon: Icons.delete_forever,
                              text: context.tr("Delete Account"),
                              isDelete: true,
                              onTap: () =>
                                  handleDeactivateAccount(context),
                            ),
                          ],
                        ),
                      ),
                        ],
                      ),
              ),
            ),

      bottomNavigationBar: const OrganiserBottomNav(currentIndex: 2),
    );
  }
}

Widget _profileOption({
  required BuildContext context,
  required IconData icon,
  required String text,
  bool isLogout = false,
  bool isDelete = false,
  VoidCallback? onTap,
}) {
  return InkWell(
    onTap: () async {
      if (isLogout) {
        await TokenService.clearToken();
        await LocaleController.clearAllPreserveLocale();

        Navigator.pushNamedAndRemoveUntil(
          context,
          '/',
          (route) => false,
        );
      } else {
        onTap?.call();
      }
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
      child: Row(
        children: [
          Icon(
            icon,
            color: (isLogout || isDelete) ? Colors.red : Colors.grey,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: (isLogout || isDelete)
                    ? Colors.red
                    : Colors.black,
              ),
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 14),
        ],
      ),
    ),
  );
}

Widget _languageOption(BuildContext context) {
  final currentLang = LocaleController.locale.value?.languageCode ??
      Localizations.localeOf(context).languageCode;
  final selected = currentLang == 'hi' ? 'hi' : 'en';

  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
    child: Row(
      children: [
        const Icon(Icons.language, color: Colors.grey),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr("App Language"),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                selected == 'hi'
                    ? context.tr("Hindi")
                    : context.tr("English"),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selected,
            items: [
              DropdownMenuItem(
                value: 'en',
                child: Text(context.tr("English")),
              ),
              DropdownMenuItem(
                value: 'hi',
                child: Text(context.tr("Hindi")),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              LocaleController.setLocale(Locale(value));
            },
          ),
        ),
      ],
    ),
  );
}

