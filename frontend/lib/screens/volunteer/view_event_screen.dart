import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../config/api_config.dart';
import '../../services/token_service.dart';
import '../../services/rating_service.dart';
import '../../services/saved_events_service.dart';
import '../../services/verification_service.dart';
import '../../services/event_service.dart';
import '../../utils/ist_date_time.dart';
import 'view_organiser_profile_screen.dart';
import 'get_verified_screen.dart';
import '../chat/event_group_chat_screen.dart';
import 'event_announcements_screen.dart';
import 'package:share_plus/share_plus.dart';
import '../rating/rating_screen.dart';
import '../../widgets/robust_image.dart';

class ViewEventScreen extends StatefulWidget {
  final Map<String, dynamic> event;

  const ViewEventScreen({super.key, required this.event});

  @override
  State<ViewEventScreen> createState() => _ViewEventScreenState();
}

class _ViewEventScreenState extends State<ViewEventScreen> {
  bool isLoadingStatus = true;
  bool isApplying = false;
  bool isSaved = false;
  String? organiserPhotoUrl;
  bool isLoadingRating = true;
  bool hasRated = false;
  int? ratingScore;
  String? ratingComment;
  String? verificationStatus;
  int? applicationId;
  bool isCancelling = false;
  final ImagePicker _picker = ImagePicker();

  /// null | pending | approved | rejected
  String? applicationStatus;

  @override
  void initState() {
    super.initState();
    _fetchApplicationStatus();
    _loadSavedState();
    _loadOrganiserPhoto();
    _fetchMyRating();
    _loadVerificationStatus();
  }

  Future<void> _loadVerificationStatus() async {
    final status = await VerificationService.getStatus();
    if (mounted) {
      setState(() {
        verificationStatus = status;
      });
    }
  }

  Future<void> _fetchMyRating() async {
    final organiserId = widget.event["organiser_id"];
    final eventId = widget.event["id"];
    if (organiserId == null || eventId == null) {
      if (!mounted) return;
      setState(() {
        isLoadingRating = false;
      });
      return;
    }

    try {
      final data = await RatingService.fetchMyRating(
        eventId: eventId,
        rateeId: organiserId,
      );
      if (!mounted) return;

      setState(() {
        hasRated = data["rated"] == true;
        ratingScore = data["score"] is int
            ? data["score"] as int
            : int.tryParse(data["score"]?.toString() ?? "");
        ratingComment = data["comment"]?.toString();
        isLoadingRating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoadingRating = false;
      });
    }
  }

  Future<void> _loadOrganiserPhoto() async {
    final eventPhoto =
        widget.event["organiser_profile_picture_url"]?.toString();
    final normalisedEventPhoto = _normalizeImageUrl(eventPhoto);
    if (normalisedEventPhoto != null) {
      setState(() {
        organiserPhotoUrl = normalisedEventPhoto;
      });
      return;
    }

    final organiserId = widget.event["organiser_id"];
    if (organiserId == null) return;

    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/organisers/$organiserId"),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final photo = _normalizeImageUrl(
          data["profile_picture_url"]?.toString(),
        );

        if (photo != null) {
          setState(() {
            organiserPhotoUrl = photo;
          });
        }
      }
    } catch (_) {
      // Keep fallback avatar on error.
    }
  }

  Future<void> _loadSavedState() async {
    final id = widget.event["id"]?.toString();
    if (id == null) return;

    final saved = await SavedEventsService.isSaved(id);
    if (!mounted) return;

    setState(() {
      isSaved = saved;
    });
  }

  Future<void> _toggleSaved() async {
    final updated = await SavedEventsService.toggleSaved(widget.event);
    if (!mounted) return;

    setState(() {
      isSaved = updated;
    });

    _snack(updated ? "Saved event" : "Removed from saved");
  }

  // ================= APPLICATION STATUS =================
  Future<void> _fetchApplicationStatus() async {
    try {
      final token = await TokenService.getToken();

      final response = await http.get(
        Uri.parse(
          "${ApiConfig.baseUrl}/events/${widget.event["id"]}/application-status",
        ),
        headers: {"Authorization": "Bearer $token"},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final resolvedApplicationId = data["applied"] == true
            ? (data["applicationId"] ?? data["application_id"]) as int?
            : null;
        setState(() {
          applicationStatus = data["applied"] == true ? data["status"] : null;
          applicationId = resolvedApplicationId;
          isLoadingStatus = false;
        });

        if (data["applied"] == true && resolvedApplicationId == null) {
          await _resolveApplicationIdFromMyApplications();
        }
      } else {
        setState(() {
          isLoadingStatus = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoadingStatus = false;
      });
    }
  }

  Future<void> _resolveApplicationIdFromMyApplications() async {
    try {
      final token = await TokenService.getToken();
      if (token == null || token.isEmpty) return;

      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/applications/my"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode != 200 || !mounted) return;

      final decoded = jsonDecode(response.body);
      final apps = decoded is List
          ? decoded
          : decoded is Map && decoded["applications"] is List
              ? decoded["applications"] as List
              : const [];

      final currentEventId = widget.event["id"];
      final match = apps.cast<dynamic>().firstWhere(
            (app) => app is Map && app["event_id"] == currentEventId,
            orElse: () => null,
          );

      if (match is Map && match["id"] != null) {
        final resolvedId = match["id"] is int
            ? match["id"] as int
            : int.tryParse(match["id"].toString());
        if (resolvedId != null && mounted) {
          setState(() {
            applicationId = resolvedId;
          });
        }
      }
    } catch (_) {
      // Leave applicationId null if fallback lookup fails.
    }
  }

  // ================= APPLY =================
  Future<void> _applyToEvent() async {
    setState(() => isApplying = true);

    try {
      final token = await TokenService.getToken();

      final response = await http.post(
        Uri.parse(
          "${ApiConfig.baseUrl}/events/${widget.event["id"]}/apply",
        ),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );
      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final nextStatus =
            (data["status"]?.toString().toLowerCase() ?? "pending");
        setState(() {
          applicationStatus = nextStatus;
          applicationId = data["application_id"] as int?;
          isApplying = false;
        });
      } else if (response.statusCode == 403) {
        // Verification required error from backend
        final data = jsonDecode(response.body);
        _snack(data["message"] ?? "Verification required to apply");
        setState(() {
          isApplying = false;
        });
        // Redirect to get verified page
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const VolunteerGetVerifiedScreen(),
          ),
        );
      } else {
        _snack("Unable to apply");
        setState(() {
          isApplying = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      _snack("Network error");
      setState(() => isApplying = false);
    }
  }

  // ================= MAIN UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text("Event Details"),
        actions: [
          IconButton(
            icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
            onPressed: _toggleSaved,
            tooltip: isSaved ? "Remove from saved" : "Save event",
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              final text = """
${widget.event["title"]}
Location: ${widget.event["location"]}
Date: ${widget.event["event_date"].toString().split("T")[0]}


Join on VolunteerX
""";

              Share.share(text);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Column(
              children: [
                _eventBanner(),
                const SizedBox(height: 16),
                _eventHeaderCard(),
                const SizedBox(height: 16),
                _aboutCard(),
                const SizedBox(height: 16),
                _responsibilitiesCard(),
                const SizedBox(height: 16),
                _organiserCard(),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _buildApplySection(),
          ),
        ],
      ),
    );
  }

  Widget _eventBanner() {
    final imageUrl = _normalizeImageUrl(widget.event["banner_url"]?.toString());

    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFEAF0FF),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: const Center(
          child: Icon(Icons.image, size: 48, color: Color(0xFF2E6BE6)),
        ),
      );
    }

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(24),
        bottomRight: Radius.circular(24),
      ),
      child: RobustImage(
        url: imageUrl,
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }

  // ================= HEADER =================
  Widget _eventHeaderCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.event["title"] ?? "",
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.event["description"] ?? "",
            style: TextStyle(
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          _iconRow(Icons.location_on, widget.event["location"] ?? "N/A"),
          _iconRow(
            Icons.calendar_today,
            _formatDateRange(),
          ),
          ..._buildScheduleRows(),
          _iconRow(
            Icons.people,
            "Volunteers Needed: ${widget.event["volunteers_required"] ?? "N/A"}",
          ),
          _iconRow(
            Icons.payments,
            _paymentText(
              widget.event["event_type"],
              widget.event["payment_per_day"],
            ),
          ),
          if ((widget.event["computed_status"] == "completed") &&
              (applicationStatus == "approved" ||
                  applicationStatus == "accepted" ||
                  applicationStatus == "completed")) ...[
            const SizedBox(height: 12),
            if (isLoadingRating)
              const Center(child: CircularProgressIndicator())
            else if (hasRated && ratingScore != null)
              _ratedSummary(ratingScore!, ratingComment)
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final organiserId = widget.event["organiser_id"];
                    if (organiserId == null) return;
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RatingScreen(
                          eventId: widget.event["id"],
                          rateeId: organiserId,
                          title: "Rate Organiser",
                        ),
                      ),
                    );
                    await _fetchMyRating();
                  },
                  icon: const Icon(Icons.star_border),
                  label: const Text("Rate organiser"),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _ratedSummary(int score, String? comment) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              5,
              (index) => Icon(
                index < score ? Icons.star : Icons.star_border,
                size: 16,
                color: Colors.amber,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "You rated $score/5",
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          if (comment != null && comment.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              comment,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  // ================= ABOUT =================
  Widget _aboutCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "About this Event",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            widget.event["description"] ??
                "No description provided by organiser.",
          ),
        ],
      ),
    );
  }

  // ================= RESPONSIBILITIES =================
  Widget _responsibilitiesCard() {
    final items = (widget.event["responsibilities"] as List?)
            ?.whereType<String>()
            .toList() ??
        [];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Your Responsibilities",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Text("No responsibilities provided by organiser."),
          if (items.isNotEmpty) ...items.map(_checkItem),
        ],
      ),
    );
  }

  // ================= ORGANISER =================
  Widget _organiserCard() {
    final organiserId = widget.event["organiser_id"];
    final organiserName = widget.event["organiser_name"] ?? "Organiser";

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (organiserId == null) {
          _snack("Organiser profile not available");
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ViewOrganiserProfileScreen(
              organiserId: organiserId,
            ),
          ),
        );
      },
      child: _card(
        child: Row(
          children: [
            _organiserAvatar(organiserPhotoUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    organiserName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "View organiser profile",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _organiserAvatar(String? imageUrl) {
    const double size = 44;

    if (imageUrl == null) {
      return const CircleAvatar(
        radius: 22,
        backgroundColor: Colors.green,
        child: Icon(Icons.eco, color: Colors.white),
      );
    }

    return ClipOval(
      child: RobustImage(
        url: imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorWidget: const CircleAvatar(
          radius: 22,
          backgroundColor: Colors.green,
          child: Icon(Icons.eco, color: Colors.white),
        ),
      ),
    );
  }

  // ================= APPLY =================
  Widget _buildApplySection() {
    if (isLoadingStatus) {
      return const Center(child: CircularProgressIndicator());
    }

    final computedStatus = widget.event["computed_status"]?.toString();
    final status = widget.event["status"]?.toString();
    final isCompleted = computedStatus == "completed" || _isPastEvent();
    final isClosed = status != null && status != "open";

    if (isCompleted || isClosed) {
      final closedLabel =
          isCompleted ? "Event completed" : "Applications closed";
      return SizedBox(
        height: 54,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            padding: EdgeInsets.zero,
          ),
          child: Text(
            closedLabel,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    if (applicationStatus == null) {
      return SizedBox(
        height: 54,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: isApplying ? null : () => _showTerms(context),
          style: ElevatedButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            padding: EdgeInsets.zero,
          ),
          child: Ink(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2E6BE6), Color(0xFF2ECC71)],
              ),
              borderRadius: BorderRadius.all(Radius.circular(30)),
            ),
            child: Center(
              child: isApplying
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "Apply for this Event",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
            ),
          ),
        ),
      );
    }

    final canCancel = _isCancelableStatus(applicationStatus!);
    final isApprovedState = _isApprovedStatus(applicationStatus!);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isApprovedState)
          Row(
            children: [
              Expanded(
                child: _quickActionPill(
                  label: "Announcements",
                  icon: Icons.campaign_outlined,
                  color: const Color(0xFF2E6BE6),
                  onTap: () {
                    final eventId = widget.event["id"] as int?;
                    if (eventId == null) {
                      _snack("Event not found");
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EventAnnouncementsScreen(
                          eventId: eventId,
                          eventTitle:
                              (widget.event["title"] ?? "Event").toString(),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _quickActionPill(
                  label: "Event Chat",
                  icon: Icons.groups_2_outlined,
                  color: const Color(0xFF2ECC71),
                  onTap: () {
                    final eventId = widget.event["id"] as int?;
                    if (eventId == null) {
                      _snack("Event not found");
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EventGroupChatScreen(
                          eventId: eventId,
                          eventTitle:
                              (widget.event["title"] ?? "Event").toString(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          )
        else
          _statusPill(
            _statusText(applicationStatus!),
            _statusColor(applicationStatus!),
          ),
        if (canCancel) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: isCancelling ? null : _showCancelDialog,
              child: isCancelling
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _isWithinLockWindow()
                          ? "Cancel Participation (Locked)"
                          : "Cancel Participation",
                    ),
            ),
          ),
        ],
      ],
    );
  }

  bool _isCancelableStatus(String status) {
    final normalized = status.toLowerCase();
    return normalized == "approved" || normalized == "accepted";
  }

  bool _isApprovedStatus(String status) {
    final normalized = status.toLowerCase();
    return normalized == "approved" || normalized == "accepted";
  }

  DateTime? _eventStartDateTime() {
    final eventDateRaw = widget.event["event_date"]?.toString();
    if (eventDateRaw == null || eventDateRaw.isEmpty) return null;

    final eventDate = IstDateTime.tryParse(eventDateRaw);
    if (eventDate == null) return null;

    final startTimeRaw = widget.event["start_time"]?.toString();
    if (startTimeRaw == null || startTimeRaw.isEmpty) {
      return DateTime(eventDate.year, eventDate.month, eventDate.day);
    }

    final parsedTime = DateTime.tryParse(startTimeRaw);
    int hour = parsedTime?.hour ?? 0;
    int minute = parsedTime?.minute ?? 0;
    int second = parsedTime?.second ?? 0;
    if (parsedTime == null) {
      final parts = startTimeRaw.split(":");
      if (parts.length >= 2) {
        hour = int.tryParse(parts[0]) ?? 0;
        minute = int.tryParse(parts[1]) ?? 0;
        second = int.tryParse(parts.length >= 3 ? parts[2] : "0") ?? 0;
      }
    }

    return DateTime(
      eventDate.year,
      eventDate.month,
      eventDate.day,
      hour,
      minute,
      second,
    );
  }

  double? _hoursBeforeEvent() {
    final start = _eventStartDateTime();
    if (start == null) return null;
    return start.difference(IstDateTime.now()).inMinutes / 60.0;
  }

  bool _isWithinLockWindow() {
    final hours = _hoursBeforeEvent();
    return hours != null && hours <= 48;
  }

  Future<void> _showCancelDialog() async {
    if (applicationId == null) {
      _snack("Application not found for cancellation");
      return;
    }

    final hoursBefore = _hoursBeforeEvent();
    final isWithinLockWindow = hoursBefore != null && hoursBefore <= 48;
    final title = (widget.event["title"] ?? "this event").toString();
    final reasonController = TextEditingController();
    String? documentUrl;
    bool uploadingDoc = false;
    String? reasonError;
    String? documentError;

    final bool? proceed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            String policyText;
            if (isWithinLockWindow) {
              policyText =
                  "This event starts in less than 48 hours. Cancelling now applies an immediate strike. Supporting document upload is mandatory to continue.";
            } else if (hoursBefore != null && hoursBefore <= 72) {
              policyText =
                  "This cancellation is within 48-72 hours before the event. You will receive a warning. Repeated cancellations without a reason may lead to a strike.";
            } else {
              policyText =
                  "This cancellation is outside the strike window. No strike will be applied.";
            }

            return AlertDialog(
              title: const Text("Cancel Participation"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Event: $title"),
                    const SizedBox(height: 10),
                    Text(
                      policyText,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonController,
                      onChanged: (_) {
                        if (reasonError != null) {
                          setLocalState(() => reasonError = null);
                        }
                      },
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: isWithinLockWindow
                            ? "Reason *"
                            : "Reason (optional but recommended)",
                        helperText: isWithinLockWindow
                            ? "Mandatory for cancellations within 48 hours"
                            : null,
                        errorText: reasonError,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isWithinLockWindow
                              ? "Supporting document *"
                              : "Supporting document",
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                documentUrl == null
                                    ? (isWithinLockWindow
                                        ? "Mandatory for cancellations within 48 hours"
                                        : "No supporting document uploaded")
                                    : "Supporting document attached",
                                style: TextStyle(
                                  color: documentUrl == null
                                      ? Colors.black54
                                      : Colors.green,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: uploadingDoc
                                  ? null
                                  : () async {
                                      final picked = await _picker.pickImage(
                                        source: ImageSource.gallery,
                                        imageQuality: 80,
                                      );
                                      if (picked == null) return;

                                      setLocalState(() => uploadingDoc = true);
                                      try {
                                        final uploaded =
                                            await EventService.uploadImage(
                                                picked);
                                        setLocalState(() {
                                          documentUrl = uploaded;
                                          documentError = null;
                                        });
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              "Failed to upload document: $e",
                                            ),
                                          ),
                                        );
                                      } finally {
                                        setLocalState(
                                            () => uploadingDoc = false);
                                      }
                                    },
                              icon: uploadingDoc
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.upload_file),
                              label: const Text("Upload"),
                            ),
                          ],
                        ),
                        if (documentError != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            documentError!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Keep"),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (isWithinLockWindow) {
                      final trimmedReason = reasonController.text.trim();
                      setLocalState(() {
                        reasonError = trimmedReason.isEmpty
                            ? "Reason is mandatory within 48 hours"
                            : null;
                        documentError = documentUrl == null
                            ? "Supporting document is mandatory within 48 hours"
                            : null;
                      });

                      if (trimmedReason.isEmpty || documentUrl == null) {
                        return;
                      }
                    }
                    Navigator.pop(context, true);
                  },
                  child: const Text("Confirm Cancel"),
                ),
              ],
            );
          },
        );
      },
    );

    if (proceed != true) return;

    setState(() => isCancelling = true);
    try {
      final response = await EventService.cancelMyApplication(
        applicationId: applicationId!,
        reason: reasonController.text.trim().isEmpty
            ? null
            : reasonController.text.trim(),
        supportingDocumentUrl: documentUrl,
      );

      if (!mounted) return;
      final strikeIssued = response["strikeIssued"] == true;
      final warningIssued = response["warningIssued"] == true;

      setState(() {
        applicationStatus = "cancelled";
      });

      final message = strikeIssued
          ? "Participation cancelled. A strike was applied."
          : warningIssued
              ? "Participation cancelled. Warning issued for 48-72 hour window."
              : "Participation cancelled.";
      _snack(message);
    } catch (e) {
      if (!mounted) return;
      _snack("Failed to cancel: $e");
    } finally {
      if (mounted) {
        setState(() => isCancelling = false);
      }
    }
  }

  // ================= HELPERS =================
  List<Widget> _buildScheduleRows() {
    final dailySchedules = widget.event["daily_schedules"];

    // If there are daily schedules, display them
    if (dailySchedules != null &&
        dailySchedules is List &&
        dailySchedules.isNotEmpty) {
      // Check if it's a multi-day event
      if (dailySchedules.length > 1) {
        // Multi-day: show day, date, and time on one line
        int dayNumber = 1;
        return dailySchedules.map<Widget>((schedule) {
          final dateStr = schedule["date"]?.toString().split("T")[0] ?? "";
          final formattedDate = _formatDateToDDMMYYYY(dateStr);
          final startTime = _formatTime(schedule["start_time"]);
          final endTime = _formatTime(schedule["end_time"]);
          final dayLabel = "Day $dayNumber";
          dayNumber++;
          return _iconRow(
            Icons.access_time,
            "$dayLabel | $formattedDate | $startTime-$endTime",
          );
        }).toList();
      } else {
        // Single day: show just time (no date, no day label)
        final schedule = dailySchedules[0];
        final startTime = _formatTime(schedule["start_time"]);
        final endTime = _formatTime(schedule["end_time"]);
        return [
          _iconRow(
            Icons.access_time,
            "Time | $startTime-$endTime",
          ),
        ];
      }
    }

    // Fall back to single time display
    return [
      _iconRow(
        Icons.access_time,
        "Time | ${_formatTime(widget.event["start_time"])}-${_formatTime(widget.event["end_time"])}",
      ),
    ];
  }

  String _formatDateToDDMMYYYY(String dateStr) {
    if (dateStr.isEmpty) return "N/A";
    try {
      final parts = dateStr.split("-");
      if (parts.length == 3) {
        return "${parts[2]}/${parts[1]}/${parts[0]}"; // dd/mm/yyyy
      }
      return dateStr;
    } catch (_) {
      return dateStr;
    }
  }

  String _formatDateRange() {
    final startDateRaw = widget.event["event_date"]?.toString();
    final endDateRaw = widget.event["end_date"]?.toString();

    if (startDateRaw == null || startDateRaw.isEmpty) return "N/A";

    final startDate = startDateRaw.split("T")[0];

    // If no end date or same as start date, show single date
    if (endDateRaw == null || endDateRaw.isEmpty) {
      return startDate;
    }

    final endDate = endDateRaw.split("T")[0];

    // If dates are the same, show single date
    if (startDate == endDate) {
      return startDate;
    }

    // Show date range for multi-day events
    return "$startDate to $endDate";
  }

  String _formatTime(dynamic timeValue) {
    if (timeValue == null) return "N/A";
    try {
      final time = timeValue.toString();
      return time.length >= 5 ? time.substring(0, 5) : time;
    } catch (_) {
      return "N/A";
    }
  }

  bool _isPastEvent() {
    final eventDateRaw = widget.event["event_date"]?.toString();
    if (eventDateRaw == null || eventDateRaw.isEmpty) return false;

    final endDateRaw = widget.event["end_date"]?.toString();
    final relevantDateRaw = endDateRaw ?? eventDateRaw;

    final parsed = IstDateTime.tryParse(relevantDateRaw);
    if (parsed == null) return false;

    final eventDateOnly = IstDateTime.startOfDay(parsed);
    final today = IstDateTime.startOfDay(IstDateTime.now());

    return eventDateOnly.isBefore(today);
  }

  String? _normalizeImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;

    String trimmed = url.trim();

    // Replace localhost with 10.0.2.2 for Android emulator
    if (trimmed.contains("localhost")) {
      trimmed = trimmed.replaceAll("localhost", "10.0.2.2");
    }

    if (trimmed.startsWith("http")) return trimmed;

    final baseUri = Uri.parse(ApiConfig.baseUrl);
    final origin =
        "${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}";

    return trimmed.startsWith("/") ? "$origin$trimmed" : "$origin/$trimmed";
  }

  String _paymentText(dynamic eventType, dynamic paymentPerDay) {
    final type = eventType?.toString().toLowerCase();
    if (type == "paid") {
      final amount = paymentPerDay?.toString();
      if (amount != null && amount.isNotEmpty) {
        return "Paid: ₹$amount/day";
      }
      return "Paid";
    }
    return "Unpaid";
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            Colors.white,
            const Color(0xFFF7FAFF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _iconRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: Colors.green),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _checkItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _statusPill(String text, Color color) {
    return Container(
      height: 52,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.25),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _quickActionPill({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.12),
              color.withOpacity(0.22),
            ],
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case "pending":
        return Colors.orange;
      case "approved":
      case "accepted":
        return Colors.green;
      case "rejected":
        return Colors.red;
      case "cancelled":
        return Colors.red;
      case "waitlisted":
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  String _statusText(String status) {
    if (status == "approved") {
      return "Application Approved";
    }
    switch (status) {
      case "pending":
        return "⏳ Application Pending";
      case "accepted":
        return "✅ Application Approved";
      case "rejected":
        return "❌ Application Rejected";
      case "cancelled":
        return "Application Cancelled";
      case "waitlisted":
        return "⏳ Waitlisted";
      default:
        return "";
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ================= TERMS =================
  void _showTerms(BuildContext context) {
    // Check verification status first
    if (verificationStatus != "approved") {
      _showVerificationRequiredDialog(context);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        bool agreed = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      "Volunteer Terms & Conditions",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                      "• Participation is voluntary and does not constitute employment."),
                  const SizedBox(height: 8),
                  const Text(
                      "• Volunteers must follow organiser instructions and maintain respectful conduct."),
                  const SizedBox(height: 8),
                  const Text(
                      "• Volunteers are responsible for their own safety during the event."),
                  const SizedBox(height: 8),
                  const Text(
                      "• Accurate profile and contact information must be maintained at all times."),
                  const SizedBox(height: 8),
                  const Text(
                    "• VolunteerX is not responsible for any payments, donations, reimbursements, or financial matters related to events; all such transactions are solely between the volunteer and the organiser.",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: agreed,
                    onChanged: (v) => setState(() => agreed = v!),
                    title: const Text("I agree to the Terms & Conditions"),
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: agreed
                          ? () {
                              Navigator.pop(context);
                              _applyToEvent();
                            }
                          : null,
                      child: const Text("Confirm & Apply"),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showVerificationRequiredDialog(BuildContext context) {
    String message;
    String actionText;
    VoidCallback? action;

    switch (verificationStatus) {
      case "pending":
        message =
            "Your verification is under review. You can apply for events after approval.";
        actionText = "OK";
        action = () => Navigator.pop(context);
        break;
      case "rejected":
        message =
            "Your verification was rejected. Please submit verification again to apply for events.";
        actionText = "Get Verified";
        action = () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const VolunteerGetVerifiedScreen(),
            ),
          );
        };
        break;
      default: // "not_requested" or null
        message = "You need to be verified before applying for events.";
        actionText = "Get Verified";
        action = () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const VolunteerGetVerifiedScreen(),
            ),
          );
        };
        break;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Verification Required"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: action,
            child: Text(actionText),
          ),
        ],
      ),
    );
  }
}
