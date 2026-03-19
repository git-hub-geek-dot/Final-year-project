import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/config/api_config.dart';
import '../../services/token_service.dart';
import '../../services/verification_service.dart';
import '../../services/rating_service.dart';
import '../auth/login_screen.dart';
import '../../localization/locale_controller.dart';
import '../../localization/localization_extensions.dart';

import 'edit_profile_screen.dart';
import 'my_applications_screen.dart';
import 'my_badges_screen.dart';
import 'saved_events_screen.dart';
import 'payment_history_screen.dart';
import 'invite_friends_screen.dart';
import 'get_verified_screen.dart';

class VolunteerProfileScreen extends StatefulWidget {
  const VolunteerProfileScreen({super.key});

  @override
  State<VolunteerProfileScreen> createState() =>
      _VolunteerProfileScreenState();
}

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  List<Map<String, String>> _faqItems(BuildContext context) {
    return [
      {
        "question": context.tr("What is the strike/suspension policy?"),
        "answer": context.tr(
          "Repeated violations may lead to strikes. 2 strikes: 3-day suspension, 3 strikes: 7-day suspension, 4 strikes: account ban.",
        ),
      },
      {
        "question": context.tr("How do I apply for an event?"),
        "answer": context.tr(
          "Open an event card and tap Apply. Fill required details and submit your application.",
        ),
      },
      {
        "question": context.tr("Can I cancel my application?"),
        "answer": context.tr(
          "Yes. If cancellation is available for that event, you can cancel from your application details.",
        ),
      },
      {
        "question": context.tr("How are badges earned?"),
        "answer": context.tr(
          "Badges are awarded based on completed events and consistent participation.",
        ),
      },
      {
        "question": context.tr("How do paid event payments work?"),
        "answer": context.tr(
          "Payment status depends on organiser confirmation and event completion.",
        ),
      },
      {
        "question": context.tr("Why are events not loading?"),
        "answer": context.tr(
          "Check your internet connection, then refresh the page. If it persists, contact support.",
        ),
      },
      {
        "question": context.tr("What if I face login issues?"),
        "answer": context.tr(
          "Verify your credentials and try Forgot Password if needed.",
        ),
      },
      {
        "question": context.tr("How can I improve my profile completion?"),
        "answer": context.tr(
          "Update your name, email, city, profile photo, and verification status in profile settings.",
        ),
      },
      {
        "question": context.tr("How do I contact support?"),
        "answer": context.tr(
          "Email volunteerxteam@gmail.com with screenshots and issue details for faster support.",
        ),
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(
          context.tr("Help & Support"),
          style: const TextStyle(fontWeight: FontWeight.bold),
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
              title: context.tr("FAQs"),
              subtitle: context.tr("Common questions answered"),
              onTap: () => _showFaqBottomSheet(context),
            ),
            _supportTile(
              context,
              icon: Icons.build,
              title: context.tr("App Support"),
              subtitle: context.tr("Issues with the app or login"),
              onTap: () => _showBottomSheet(
                context,
                title: context.tr("App Support"),
                content: [
                  "- ${context.tr("App not loading events?")}\n"
                      "${context.tr("Check your internet connection and try again.")}",
                  "- ${context.tr("Login issues?")}\n"
                      "${context.tr("Make sure your credentials are correct or use Forgot Password.")}",
                  "- ${context.tr("App crashes or bugs?")}\n"
                      "${context.tr("Restart the app or update to the latest version.")}",
                  "- ${context.tr("Still facing issues?")}\n"
                      "${context.tr("Contact our support team via email.")}",
                ],
              ),
            ),
            _supportTile(
              context,
              icon: Icons.security,
              title: context.tr("Safety & Guidelines"),
              subtitle: context.tr("Your safety matters"),
              onTap: () => _showBottomSheet(
                context,
                title: context.tr("Safety & Guidelines"),
                content: [
                  "- ${context.tr("Always verify event details before attending.")}",
                  "- ${context.tr("Avoid sharing personal or financial information.")}",
                  "- ${context.tr("Report suspicious organisers or events immediately.")}",
                  "- ${context.tr("Follow community guidelines and event instructions.")}",
                ],
              ),
            ),
            _supportTile(
              context,
              icon: Icons.email,
              title: context.tr("Contact Us"),
              subtitle: context.tr("Get in touch with our team"),
              onTap: () => _showBottomSheet(
                context,
                title: context.tr("Contact VolunteerX"),
                content: [
                  context.tr("Email Support"),
                  "volunteerxteam@gmail.com",
                  "",
                  context.tr("Our team usually responds within 24-48 hours."),
                  context.tr(
                    "Please include screenshots or details for faster support.",
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  void _showFaqBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
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
                  context.tr("Frequently Asked Questions"),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ..._faqItems(context).map(
                  (faq) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    color: const Color(0xFFF5F6FA),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Theme(
                      data: Theme.of(sheetContext).copyWith(
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
                          faq["question"] ?? "",
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              faq["answer"] ?? "",
                              style: const TextStyle(height: 1.35),
                            ),
                          ),
                        ],
                      ),
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

class _VolunteerProfileScreenState extends State<VolunteerProfileScreen>
  with SingleTickerProviderStateMixin {
  bool loading = true;
  String? errorMessage;
  bool _handlingUnauthorized = false;

  int? _imageCacheBuster;

  String? name;
  String? email;
  String? city;
  String? role;
  String? verificationStatus;
  String? profilePictureUrl;
  String? _lastProfilePictureUrl;
  bool _pendingAvatarSuccess = false;

  String _impactEvents = '0';
  String _impactRating = '0';
  String _ratingCount = '0';

  late AnimationController _avatarSuccessController;
  late Animation<double> _avatarGlow;

  @override
  void initState() {
    super.initState();
    _avatarSuccessController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _avatarGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _avatarSuccessController,
        curve: Curves.easeOutCubic,
      ),
    );
    fetchProfile();
    loadVerificationStatus();
    fetchDashboard();
    loadRatingSummary();
  }

  @override
  void dispose() {
    _avatarSuccessController.dispose();
    super.dispose();
  }

  Future<void> loadVerificationStatus() async {
    try {
      final status = await VerificationService.getStatus();
      if (!mounted) return;
      setState(() {
        verificationStatus = status;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        verificationStatus = null;
      });
    }
  }

  Future<void> fetchDashboard() async {
    try {
      final token = await TokenService.getToken();
      if (token == null || token.isEmpty) {
        return;
      }

      final url = Uri.parse("${ApiConfig.baseUrl}/volunteer/dashboard");
      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (!mounted) return;

      if (response.statusCode == 401) {
        await _handleUnauthorized();
        return;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final impact = data["impact"] ?? {};
        setState(() {
          _impactEvents = (impact["events"] ?? 0).toString();
          _impactRating = (impact["rating"] ?? "0").toString();
        });
      }
    } catch (_) {
      // Keep existing state on error
    }
  }

  Future<void> loadRatingSummary() async {
    try {
      final userId = await TokenService.getUserId();
      if (userId == null) return;

      final data = await RatingService.fetchSummary(userId);
      if (!mounted) return;
      setState(() {
        _impactRating = data["rating"]?.toString() ?? _impactRating;
        _ratingCount = data["review_count"]?.toString() ?? _ratingCount;
      });
    } catch (_) {
      // Keep existing values
    }
  }

  /// ================= FETCH PROFILE FROM API =================
  Future<void> fetchProfile() async {
    try {
      setState(() {
        loading = true;
        errorMessage = null;
      });

      final token = await TokenService.getToken();

      if (token == null || token.isEmpty) {
        if (!mounted) return;
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
          "Content-Type": "application/json",
        },
      );

      if (!mounted) return;

      if (response.statusCode == 401) {
        await _handleUnauthorized();
        return;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final normalizedUrl = _normalizeProfileImageUrl(
          data["profile_picture_url"],
        );
        final previousUrl = _lastProfilePictureUrl;

        setState(() {
          name = data["name"];
          email = data["email"];
          city = data["city"];
          role = data["role"];
          profilePictureUrl = normalizedUrl;
          _imageCacheBuster = DateTime.now().millisecondsSinceEpoch;
          loading = false;
        });


        _lastProfilePictureUrl = normalizedUrl;
        if (normalizedUrl != null && normalizedUrl.isNotEmpty) {
          if (_pendingAvatarSuccess || normalizedUrl != previousUrl) {
            _triggerAvatarSuccess(delay: true);
          }
        }
        _pendingAvatarSuccess = false;
      } else {
        setState(() {
          loading = false;
          errorMessage = context.tr(
            "Error {statusCode}: {message}",
            args: {
              "statusCode": response.statusCode.toString(),
              "message": response.body,
            },
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = context.tr(
          "Error: {error}",
          args: {"error": e.toString()},
        );
      });
    }
  }


  void _triggerAvatarSuccess({bool delay = false}) {
    if (_avatarSuccessController.isAnimating) return;
    if (delay) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) {
          _avatarSuccessController.forward(from: 0);
        }
      });
      return;
    }
    _avatarSuccessController.forward(from: 0);
  }

  Future<void> _handleUnauthorized() async {
    if (_handlingUnauthorized) return;
    _handlingUnauthorized = true;

    await TokenService.clearToken();
    await LocaleController.clearAllPreserveLocale();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  /// ================= LOGOUT =================
  Future<void> logout() async {
    await TokenService.clearToken();
    await LocaleController.clearAllPreserveLocale();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  double _profileCompletionPercent() {
    final total = 5;
    var completed = 0;

    if ((name ?? '').trim().isNotEmpty) completed++;
    if ((email ?? '').trim().isNotEmpty) completed++;
    if ((city ?? '').trim().isNotEmpty) completed++;
    if ((profilePictureUrl ?? '').trim().isNotEmpty) completed++;
    if ((verificationStatus ?? '').trim().isNotEmpty) completed++;

    return completed / total;
  }

  List<String> _missingProfileItems() {
    final missing = <String>[];
    if ((name ?? '').trim().isEmpty) missing.add(context.tr("Name"));
    if ((email ?? '').trim().isEmpty) missing.add(context.tr("Email"));
    if ((city ?? '').trim().isEmpty) missing.add(context.tr("City"));
    if ((profilePictureUrl ?? '').trim().isEmpty) {
      missing.add(context.tr("Profile photo"));
    }
    if ((verificationStatus ?? '').trim().isEmpty) {
      missing.add(context.tr("Verification status"));
    }
    return missing;
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
        final pathWithQuery = parsed.hasQuery
            ? "${parsed.path}?${parsed.query}"
            : parsed.path;
        return "$origin$pathWithQuery";
      }
    }

    if (url.contains("localhost") || url.contains("127.0.0.1")) {
      if (parsed != null) {
        final pathWithQuery = parsed.hasQuery
            ? "${parsed.path}?${parsed.query}"
            : parsed.path;
        return "$origin$pathWithQuery";
      }
    }

    return url;
  }

  Widget _buildProfileAvatar() {
    final normalizedUrl = _normalizeProfileImageUrl(profilePictureUrl);
    final hasImage = normalizedUrl != null && normalizedUrl.isNotEmpty;
    final imageUrl = hasImage
        ? "${normalizedUrl}?v=${_imageCacheBuster ?? 0}"
        : null;

    return AnimatedBuilder(
      animation: _avatarSuccessController,
      builder: (context, _) {
        final glow = _avatarGlow.value;
        final glowOpacity = (1 - glow) * 0.85;
        final glowSize = 96 + (glow * 26);
        return Stack(
          alignment: Alignment.center,
          children: [
            if (hasImage)
              Container(
                width: glowSize,
                height: glowSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.withValues(alpha: glowOpacity * 0.6),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: glowOpacity),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: glowOpacity),
                      blurRadius: 32 * (1 - glow),
                      spreadRadius: 6,
                    ),
                  ],
                ),
              ),
            CircleAvatar(
              radius: 42,
              backgroundColor: Colors.white,
              child: hasImage
                  ? ClipOval(
                      child: Image.network(
                        imageUrl!,
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.person, size: 42),
                      ),
                    )
                  : const Icon(Icons.person, size: 42),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr("Logout")),
        content: Text(context.tr("Are you sure you want to logout?")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr("Cancel")),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              context.tr("Logout"),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await logout();
    }
  }

  Future<void> _deleteAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr("Token not found. Please login again.")),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr("Delete Account")),
        content: Text(
          context.tr(
            "Are you sure you want to delete your account? This action is irreversible.",
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
              context.tr("Delete"),
              style: const TextStyle(color: Colors.red),
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

      if (!mounted) return;
      Navigator.pop(context);

      if (response.statusCode == 200) {
        await TokenService.clearToken();
        await LocaleController.clearAllPreserveLocale();

        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr("Account deleted successfully.")),
          ),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      } else {
        String msg = context.tr("Delete failed");
        try {
          final data = jsonDecode(response.body);
          msg = data["message"] ?? data["error"] ?? msg;
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              "Server error: {error}",
              args: {"error": e.toString()},
            ),
          ),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      /// ================= HEADER =================
                      Container(
                        padding: const EdgeInsets.only(top: 60, bottom: 30),
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF2E6BE6),
                              Color(0xFF2ECC71)
                            ],
                          ),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(40),
                            bottomRight: Radius.circular(40),
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildProfileAvatar(),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  name ?? "",
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
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
                              city == null || city!.isEmpty
                                  ? context.tr("City not set")
                                  : "${city!}, ${context.tr("India")}",
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 14),

                            /// EDIT PROFILE
                            GestureDetector(
                              onTap: () async {
                                final updated = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const EditProfileScreen(),
                                  ),
                                );
                                if (updated == true) {
                                  _pendingAvatarSuccess = true;
                                }
                                fetchProfile();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Text(
                                  context.tr("Edit Profile"),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      /// ================= PROFILE COMPLETENESS =================
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr("Profile Completeness"),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: _profileCompletionPercent(),
                                    minHeight: 10,
                                    backgroundColor: const Color(0xFFE5E7EB),
                                    valueColor: const AlwaysStoppedAnimation(
                                      Color(0xFF22C55E),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  context.tr(
                                    "{percent}% complete",
                                    args: {
                                      "percent": (_profileCompletionPercent() *
                                          100).round().toString(),
                                    },
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if (_missingProfileItems().isNotEmpty)
                                  Text(
                                    context.tr(
                                      "Missing: {items}",
                                      args: {
                                        "items":
                                            _missingProfileItems().join(', '),
                                      },
                                    ),
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      /// ================= IMPACT SUMMARY =================
                      _sectionHeader(context.tr("Impact Summary")),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            _statCard(
                              context.tr("Events"),
                              _impactEvents,
                              Icons.event,
                            ),
                            const SizedBox(width: 10),
                            _statCard(
                              context.tr("Rating"),
                              "$_impactRating ($_ratingCount)",
                              Icons.star,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// ================= ACTIVITIES =================
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            _tile(
                              Icons.assignment,
                              context.tr("My Applications"),
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const MyApplicationsScreen(),
                                  ),
                                );
                              },
                            ),

                            _tile(
                              Icons.bookmark,
                              context.tr("Saved Events"),
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const SavedEventsScreen(),
                                  ),
                                );
                              },
                            ),

                            _tile(
                              Icons.emoji_events,
                              context.tr("My Badges"),
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const MyBadgesScreen(),
                                  ),
                                );
                              },
                            ),

                            /// ✅ GET VERIFIED (SAFE LOGIC)
                            _tile(
                              Icons.verified,
                              verificationStatus == "pending"
                                  ? context.tr("Verification Under Review")
                                  : verificationStatus == "approved"
                                      ? context.tr("Verified")
                                      : context.tr("Get Verified"),
                              () {
                                final status =
                                    (verificationStatus ?? '').toLowerCase();

                                if (status == 'approved') {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        context.tr(
                                          "Your account is already verified.",
                                        ),
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                if (status == 'pending') {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        context.tr(
                                          "Your verification request is under review.",
                                        ),
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const VolunteerGetVerifiedScreen(),
                                  ),
                                );
                              },
                            ),

                            _tile(
                              Icons.payments,
                              context.tr("Payment Status"),
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const CompensationStatusScreen(),
                                  ),
                                );
                              },
                            ),
                            _tile(
                              Icons.group,
                              context.tr("Invite Friends"),
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const InviteFriendsScreen(),
                                  ),
                                );
                              },
                            ),
                            _languageTile(),
                            _tile(
                              Icons.help_outline,
                              context.tr("Help & Support"),
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const HelpSupportScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                            _tile(
                              Icons.logout,
                              context.tr("Logout"),
                              _confirmLogout,
                              color: Colors.red,
                            ),
                            _tile(
                              Icons.delete_forever,
                              context.tr("Delete Account"),
                              _deleteAccount,
                              color: Colors.red,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
    );
  }

  Widget _tile(
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color? color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        onTap: onTap,
      ),
    );
  }

  Widget _languageTile() {
    final currentLang =
        LocaleController.locale.value?.languageCode ??
        Localizations.localeOf(context).languageCode;
    final selected = currentLang == 'hi' ? 'hi' : 'en';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(Icons.language),
        title: Text(context.tr("App Language")),
        subtitle: Text(
          selected == 'hi'
              ? context.tr("Hindi")
              : context.tr("English"),
        ),
        trailing: DropdownButtonHideUnderline(
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
      ),
    );
  }

  Widget _sectionHeader(String title, {VoidCallback? onEdit}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (onEdit != null)
            TextButton(
              onPressed: onEdit,
              child: Text(context.tr("Edit")),
            ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
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
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF2E6BE6)),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
