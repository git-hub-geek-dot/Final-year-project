import 'dart:async';
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
import '../../services/notification_service.dart';
import '../../utils/ist_date_time.dart';
import '../../localization/localization_extensions.dart';
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

class _ViewEventScreenState extends State<ViewEventScreen>
    with WidgetsBindingObserver {
  bool isLoadingStatus = true;
  bool isLoadingVerification = true;
  bool isApplying = false;
  bool isSaved = false;
  String? organiserPhotoUrl;
  bool isLoadingRating = true;
  bool hasRated = false;
  int? ratingScore;
  String? ratingComment;
  String? verificationStatus;
  int? applicationId;
  String? adminCancelReason;
  String? volunteerCancelReason;
  String? cancellationSource;
  String? eventStatusOverride;
  bool isCancelling = false;
  bool isReviewClosed = false;
  final ImagePicker _picker = ImagePicker();
  StreamSubscription<Map<String, dynamic>>? _notificationSub;

  /// null | pending | approved | rejected
  String? applicationStatus;
  String? attendanceStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchApplicationStatus();
    _loadSavedState();
    _loadOrganiserPhoto();
    _fetchMyRating();
    _loadVerificationStatus();
    _notificationSub =
        NotificationService.messageEvents.listen(_handleNotificationEvent);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchApplicationStatus();
    }
  }

  void _handleNotificationEvent(Map<String, dynamic> data) {
    if (!mounted) return;

    final type = (data["type"] ?? "").toString().trim().toLowerCase();
    if (type != "application_status" &&
        type != "application_cancelled" &&
        type != "waitlist_promoted" &&
        type != "attendance_updated" &&
        type != "attendance_absent_strike" &&
        type != "event_cancelled" &&
        type != "event_removed") {
      return;
    }

    final rawEventId = data["eventId"] ?? data["event_id"];
    if (rawEventId != null) {
      final currentEventId = widget.event["id"];
      final incomingEventId = int.tryParse(rawEventId.toString());
      final normalizedCurrent = currentEventId is int
          ? currentEventId
          : int.tryParse(currentEventId?.toString() ?? "");
      if (incomingEventId != null &&
          normalizedCurrent != null &&
          incomingEventId != normalizedCurrent) {
        return;
      }
    }

    if (type == "event_cancelled" || type == "event_removed") {
      setState(() {
        eventStatusOverride = type == "event_removed" ? "deleted" : "closed";
        widget.event["status"] = eventStatusOverride;
        widget.event["computed_status"] =
            type == "event_removed" ? "deleted_by_admin" : "cancelled";
      });
    }

    _fetchApplicationStatus();
  }

  Future<void> _loadVerificationStatus() async {
    try {
      final status = await VerificationService.getStatus();
      if (!mounted) return;
      setState(() {
        verificationStatus = status?.toLowerCase();
        isLoadingVerification = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        verificationStatus = null;
        isLoadingVerification = false;
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
      final token = await TokenService.getToken();
      if (token == null || token.isEmpty) return;

      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/organisers/$organiserId"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final photo = _normalizeImageUrl(
          ((data["organiser"] as Map?)?["profile_picture_url"])?.toString(),
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

    _snack(
      updated ? context.tr("Saved event") : context.tr("Removed from saved"),
    );
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
          adminCancelReason = data["applied"] == true
              ? data["adminCancelReason"]?.toString()
              : null;
          volunteerCancelReason = data["applied"] == true
              ? data["volunteerCancelReason"]?.toString()
              : null;
          cancellationSource = data["applied"] == true
              ? data["cancellationSource"]?.toString()
              : null;
          eventStatusOverride = data["eventStatus"]?.toString();
          attendanceStatus = data["applied"] == true
              ? (data["attendanceStatus"] ?? data["attendance_status"])
                  ?.toString()
              : null;
          applicationId = resolvedApplicationId;
          isReviewClosed =
              data["applied"] == true && data["reviewClosed"] == true;
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
            adminCancelReason = match["admin_cancel_reason"]?.toString();
            volunteerCancelReason =
                match["volunteer_cancel_reason"]?.toString();
            cancellationSource = match["cancellation_source"]?.toString();
            eventStatusOverride = match["event_status"]?.toString();
            attendanceStatus = match["attendance_status"]?.toString();
          });
        }
      }
    } catch (_) {
      // Leave applicationId null if fallback lookup fails.
    }
  }

  String _extractApiMessage(String responseBody, {required String fallback}) {
    if (responseBody.trim().isEmpty) return fallback;

    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map) {
        final parsed = decoded["error"] ?? decoded["message"];
        if (parsed != null && parsed.toString().trim().isNotEmpty) {
          return parsed.toString().trim();
        }
      }
    } catch (_) {}

    return fallback;
  }

  // ================= APPLY =================
  Future<void> _applyToEvent({
    String? priorExperience,
    String? availabilityStatus,
  }) async {
    setState(() => isApplying = true);

    try {
      final token = await TokenService.getToken();
      final experience = priorExperience?.trim();
      final availability = availabilityStatus?.trim().toLowerCase();
      final payload = <String, dynamic>{};
      if (experience != null && experience.isNotEmpty) {
        payload["priorExperience"] = experience;
      }
      if (availability != null && availability.isNotEmpty) {
        payload["availabilityStatus"] = availability;
      }

      final response = await http.post(
        Uri.parse(
          "${ApiConfig.baseUrl}/events/${widget.event["id"]}/apply",
        ),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode(payload),
      );
      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final nextStatus =
            (data["status"]?.toString().toLowerCase() ?? "pending");
        setState(() {
          applicationStatus = nextStatus;
          attendanceStatus = "unmarked";
          applicationId = data["application_id"] as int?;
          isReviewClosed = false;
          isApplying = false;
        });
      } else if (response.statusCode == 403) {
        final message = _extractApiMessage(
          response.body,
          fallback: context.tr("Verification required to apply"),
        );
        setState(() {
          isApplying = false;
        });
        _snack(message);
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        await _openVolunteerVerificationFlow(context);
      } else {
        final apiMessage = _extractApiMessage(
          response.body,
          fallback: context.tr("Unable to apply"),
        );
        setState(() {
          isApplying = false;
        });

        final friendlyMessage = apiMessage.toLowerCase() == "already applied"
            ? context.tr("You have already applied to this event.")
            : apiMessage;

        _snack(friendlyMessage);

        if (response.statusCode == 409 ||
            apiMessage.toLowerCase() == "already applied") {
          await _fetchApplicationStatus();
        }
      }
    } catch (_) {
      if (!mounted) return;
      _snack(context.tr("Network error"));
      setState(() => isApplying = false);
    }
  }

  // ================= MAIN UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(context.tr("Event Details")),
        actions: [
          IconButton(
            icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
            onPressed: _toggleSaved,
            tooltip: isSaved
                ? context.tr("Remove from saved")
                : context.tr("Save event"),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              final text = """
${widget.event["title"]}
${context.tr("Location")}: ${widget.event["location"]}
${context.tr("Date")}: ${IstDateTime.formatDate(widget.event["event_date"])}


${context.tr("Join on VolunteerX")}
""";

              Share.share(text);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 10, 16, 22),
          child: _buildApplySection(),
        ),
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
          _iconRow(
            Icons.location_on,
            widget.event["location"] ?? context.tr("N/A"),
          ),
          _iconRow(
            Icons.calendar_today,
            _formatDateRange(),
          ),
          ..._buildScheduleRows(),
          _iconRow(
            Icons.people,
            context.tr(
              "Volunteers Needed: {count}",
              args: {
                "count":
                    (widget.event["volunteers_required"] ?? context.tr("N/A"))
                        .toString(),
              },
            ),
          ),
          _iconRow(
            Icons.payments,
            _paymentSummaryText(
              widget.event["event_type"],
              widget.event["payment_amount"],
              widget.event["payment_rate_type"],
            ),
          ),
          if (_paymentClearanceText(
                widget.event["event_type"],
                widget.event["payment_clearance_date"],
              ) !=
              null)
            _iconRow(
              Icons.schedule,
              _paymentClearanceText(
                widget.event["event_type"],
                widget.event["payment_clearance_date"],
              )!,
            ),
          if ((widget.event["computed_status"] == "completed") &&
              (_normalizedStatus(applicationStatus ?? "") == "approved" ||
                  _normalizedStatus(applicationStatus ?? "") == "completed") &&
              _normalizedAttendanceStatus(attendanceStatus ?? "") !=
                  "absent") ...[
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
                          title: context.tr("Rate Organiser"),
                        ),
                      ),
                    );
                    await _fetchMyRating();
                  },
                  icon: const Icon(Icons.star_border),
                  label: Text(context.tr("Rate organiser")),
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
            context.tr(
              "You rated {score}/5",
              args: {"score": score.toString()},
            ),
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
          Text(
            context.tr("About this Event"),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            widget.event["description"] ??
                context.tr("No description provided by organiser."),
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
          Text(
            context.tr("Your Responsibilities"),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(context.tr("No responsibilities provided by organiser.")),
          if (items.isNotEmpty) ...items.map(_checkItem),
        ],
      ),
    );
  }

  // ================= ORGANISER =================
  Widget _organiserCard() {
    final organiserId = widget.event["organiser_id"];
    final organiserName =
        widget.event["organiser_name"] ?? context.tr("Organiser");

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (organiserId == null) {
          _snack(context.tr("Organiser profile not available"));
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
                  Text(
                    context.tr("View organiser profile"),
                    style: const TextStyle(color: Colors.grey),
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

    final rawComputed =
        widget.event["computed_status"]?.toString().toLowerCase();
    final rawStatus =
        (eventStatusOverride ?? widget.event["status"])?.toString().toLowerCase();
    var eventStatus = (rawComputed ?? "").trim();
    if (eventStatus.isEmpty) {
      eventStatus = (rawStatus ?? "").trim();
    }
    if (eventStatus == "closed") eventStatus = "cancelled";
    if (eventStatus == "deleted" || eventStatus == "deleted_by_admin") {
      eventStatus = "removed";
    }

    final isCompleted = eventStatus == "completed" || _isPastEvent();
    final isCancelled = eventStatus == "cancelled";
    final isRemoved = eventStatus == "removed";
    final isClosed = rawStatus != null && rawStatus != "open";

    if (applicationStatus == null &&
        (isCompleted || isCancelled || isRemoved || isClosed)) {
      final closedLabel = isCompleted
          ? context.tr("Event completed")
          : isCancelled
              ? context.tr("Event cancelled")
              : isRemoved
                  ? context.tr("Event removed")
                  : context.tr("Applications closed");
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
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E6BE6), Color(0xFF2ECC71)],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2E6BE6).withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: isApplying ? null : () => _showTerms(context),
              child: Center(
                child: isApplying
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.2,
                        ),
                      )
                    : Text(
                        context.tr("Apply for this Event"),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ),
      );
    }

    final currentStatus = _normalizedStatus(applicationStatus!);
    final currentAttendance =
        _normalizedAttendanceStatus(attendanceStatus ?? "");
    final canCancel = _isCancelableStatus(currentStatus) && !_hasEventStarted();
    final isApprovedState = _isApprovedStatus(currentStatus);
    final cancelLabel = _cancelActionLabel(
      currentStatus,
      isLocked: _isWithinLockWindow(),
    );
    final statusText = currentAttendance == "absent"
        ? context.tr("Attendance Absent")
        : currentAttendance == "present"
            ? context.tr("Attendance Present")
        : isReviewClosed
            ? context.tr("Review Closed")
            : _statusText(currentStatus);
    final statusColor = currentAttendance == "absent"
        ? Colors.deepOrange
        : currentAttendance == "present"
            ? Colors.green
            : isReviewClosed
                ? Colors.redAccent
                : _statusColor(currentStatus);
    final statusDescription = isReviewClosed
        ? null
        : _statusDescription(currentStatus);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _statusPill(
          statusText,
          statusColor,
        ),
        if (statusDescription != null) ...[
          const SizedBox(height: 10),
          Text(
            statusDescription,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        if (isReviewClosed) ...[
          const SizedBox(height: 10),
          Text(
            context
                .tr("This event ended before your application was reviewed."),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        if (isApprovedState && !isCompleted) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _quickActionPill(
                  label: context.tr("Announcements"),
                  icon: Icons.campaign_outlined,
                  color: const Color(0xFF2E6BE6),
                  onTap: () {
                    final eventId = _eventIdAsInt();
                    if (eventId == null) {
                      _snack(context.tr("Event not found"));
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EventAnnouncementsScreen(
                          eventId: eventId,
                          eventTitle:
                              (widget.event["title"] ?? context.tr("Event"))
                                  .toString(),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _quickActionPill(
                  label: context.tr("Event Chat"),
                  icon: Icons.groups_2_outlined,
                  color: const Color(0xFF2ECC71),
                  onTap: () {
                    final eventId = _eventIdAsInt();
                    if (eventId == null) {
                      _snack(context.tr("Event not found"));
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EventGroupChatScreen(
                          eventId: eventId,
                          eventTitle:
                              (widget.event["title"] ?? context.tr("Event"))
                                  .toString(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          )
        ],
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
                  : Text(cancelLabel),
            ),
          ),
        ],
      ],
    );
  }

  bool _isCancelableStatus(String status) {
    final normalized = _normalizedStatus(status);
    return normalized == "approved" ||
        normalized == "pending" ||
        normalized == "waitlisted";
  }

  bool _isApprovedStatus(String status) {
    return _normalizedStatus(status) == "approved";
  }

  String _cancelActionLabel(String status, {bool isLocked = false}) {
    final base = _isApprovedStatus(status)
        ? context.tr("Cancel participation")
        : context.tr("Withdraw application");

    if (!isLocked) return base;

    return _isApprovedStatus(status)
        ? context.tr("Cancel participation (Locked)")
        : context.tr("Withdraw application (Locked)");
  }

  String _cancelDialogTitle(String status) {
    return _isApprovedStatus(status)
        ? context.tr("Cancel Participation")
        : context.tr("Withdraw Application");
  }

  String _confirmCancelLabel(String status) {
    return _isApprovedStatus(status)
        ? context.tr("Confirm Cancel")
        : context.tr("Confirm Withdraw");
  }

  String _cancellationSuccessMessage({
    required String status,
    required bool strikeIssued,
    required bool warningIssued,
  }) {
    final cancelledLabel = _isApprovedStatus(status)
        ? context.tr("Participation cancelled.")
        : context.tr("Application withdrawn.");

    if (strikeIssued) {
      return _isApprovedStatus(status)
          ? context.tr("Participation cancelled. A strike was applied.")
          : context.tr("Application withdrawn. A strike was applied.");
    }

    if (warningIssued) {
      return _isApprovedStatus(status)
          ? context.tr(
              "Participation cancelled. Warning issued for 48-72 hour window.",
            )
          : context.tr(
              "Application withdrawn. Warning issued for 48-72 hour window.",
            );
    }

    return cancelledLabel;
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

  bool _hasEventStarted() {
    final hours = _hoursBeforeEvent();
    return hours != null && hours <= 0;
  }

  bool _isWithinLockWindow() {
    final hours = _hoursBeforeEvent();
    return hours != null && hours > 0 && hours <= 48;
  }

  Future<void> _showCancelDialog() async {
    if (applicationId == null) {
      _snack(context.tr("Application not found for cancellation"));
      return;
    }

    if (_hasEventStarted()) {
      _snack(
        context.tr(
          "This event has already started. Cancellation is no longer available.",
        ),
      );
      return;
    }

    final currentStatus = _normalizedStatus(applicationStatus ?? "");
    final isApprovedApplication = _isApprovedStatus(currentStatus);
    final hoursBefore = _hoursBeforeEvent();
    final isWithinLockWindow = hoursBefore != null && hoursBefore <= 48;
    final title =
        (widget.event["title"] ?? context.tr("this event")).toString();
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
              policyText = isApprovedApplication
                  ? context.tr(
                      "This event starts in less than 48 hours. Cancelling now applies an immediate strike. Provide a reason or upload a supporting document to continue.",
                    )
                  : context.tr(
                      "This event starts in less than 48 hours. Withdrawing now applies an immediate strike. Provide a reason or upload a supporting document to continue.",
                    );
            } else if (hoursBefore != null && hoursBefore <= 72) {
              policyText = isApprovedApplication
                  ? context.tr(
                      "This cancellation is within 48-72 hours before the event. You will receive a warning. Repeated cancellations without a reason or supporting document may lead to a strike.",
                    )
                  : context.tr(
                      "This withdrawal is within 48-72 hours before the event. You will receive a warning. Repeated withdrawals without a reason or supporting document may lead to a strike.",
                    );
            } else {
              policyText = isApprovedApplication
                  ? context.tr(
                      "This cancellation is outside the strike window. No strike will be applied.",
                    )
                  : context.tr(
                      "This withdrawal is outside the strike window. No strike will be applied.",
                    );
            }

            return AlertDialog(
              title: Text(_cancelDialogTitle(currentStatus)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(
                        "Event: {title}",
                        args: {"title": title},
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      policyText,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonController,
                      onChanged: (_) {
                        if (reasonError != null || documentError != null) {
                          setLocalState(() {
                            reasonError = null;
                            documentError = null;
                          });
                        }
                      },
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: context.tr("Reason (optional)"),
                        helperText: context.tr(
                          "Provide reason or supporting document",
                        ),
                        errorText: reasonError,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr("Supporting document (optional)"),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                documentUrl == null
                                    ? context.tr(
                                        "No supporting document uploaded",
                                      )
                                    : context.tr(
                                        "Supporting document attached",
                                      ),
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
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              context.tr(
                                                "Failed to upload document: {error}",
                                                args: {"error": e.toString()},
                                              ),
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
                              label: Text(context.tr("Upload")),
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
                  child: Text(context.tr("Keep")),
                ),
                ElevatedButton(
                  onPressed: () {
                    final trimmedReason = reasonController.text.trim();
                    final hasReason = trimmedReason.isNotEmpty;
                    final hasDocument = documentUrl != null;
                    if (!hasReason && !hasDocument) {
                      final error = context.tr(
                        "Please provide a reason or upload a supporting document",
                      );
                      setLocalState(() {
                        reasonError = error;
                        documentError = error;
                      });
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  child: Text(_confirmCancelLabel(currentStatus)),
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
      final message = _cancellationSuccessMessage(
        status: currentStatus,
        strikeIssued: strikeIssued,
        warningIssued: warningIssued,
      );

      setState(() {
        applicationStatus = "cancelled";
      });

      _snack(message);
    } catch (e) {
      if (!mounted) return;
      _snack(
        context.tr(
          "Failed to cancel: {error}",
          args: {"error": e.toString()},
        ),
      );
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
          final rawDate = IstDateTime.formatDate(schedule["date"]);
          final dateStr = rawDate == "-" ? "" : rawDate;
          final formattedDate = _formatDateToDDMMYYYY(dateStr);
          final startTime = _formatTime(schedule["start_time"]);
          final endTime = _formatTime(schedule["end_time"]);
          final dayLabel = context.tr(
            "Day {number}",
            args: {"number": dayNumber.toString()},
          );
          dayNumber++;
          return _iconRow(
            Icons.access_time,
            context.tr(
              "{day} | {date} | {time}",
              args: {
                "day": dayLabel,
                "date": formattedDate,
                "time": "$startTime-$endTime",
              },
            ),
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
            context.tr(
              "Time | {time}",
              args: {"time": "$startTime-$endTime"},
            ),
          ),
        ];
      }
    }

    // Fall back to single time display
    return [
      _iconRow(
        Icons.access_time,
        context.tr(
          "Time | {time}",
          args: {
            "time":
                "${_formatTime(widget.event["start_time"])}-${_formatTime(widget.event["end_time"])}",
          },
        ),
      ),
    ];
  }

  String _formatDateToDDMMYYYY(String dateStr) {
    if (dateStr.isEmpty) return context.tr("N/A");
    final parsed = IstDateTime.tryParse(dateStr);
    if (parsed == null) return dateStr;
    final day = parsed.day.toString().padLeft(2, "0");
    final month = parsed.month.toString().padLeft(2, "0");
    return "$day/$month/${parsed.year}";
  }

  String _formatDateRange() {
    final startDateRaw = widget.event["event_date"]?.toString();
    final endDateRaw = widget.event["end_date"]?.toString();

    if (startDateRaw == null || startDateRaw.isEmpty) return context.tr("N/A");

    final startParsed = IstDateTime.tryParse(startDateRaw);
    if (startParsed == null) return context.tr("N/A");
    final startDate = IstDateTime.formatDate(startParsed);

    // If no end date or same as start date, show single date
    if (endDateRaw == null || endDateRaw.isEmpty) {
      return startDate;
    }

    final endParsed = IstDateTime.tryParse(endDateRaw);
    if (endParsed == null) return startDate;
    final endDate = IstDateTime.formatDate(endParsed);

    // If dates are the same, show single date
    if (startDate == endDate) {
      return startDate;
    }

    // Show date range for multi-day events
    return "$startDate ${context.tr("to")} $endDate";
  }

  String _formatTime(dynamic timeValue) {
    if (timeValue == null) return context.tr("N/A");
    try {
      final time = timeValue.toString();
      return time.length >= 5 ? time.substring(0, 5) : time;
    } catch (_) {
      return context.tr("N/A");
    }
  }

  bool _isPastEvent() {
    final eventDateRaw = widget.event["event_date"]?.toString();
    if (eventDateRaw == null || eventDateRaw.isEmpty) return false;

    final endDateRaw = widget.event["end_date"]?.toString();
    final relevantDateRaw = endDateRaw ?? eventDateRaw;

    final parsed = IstDateTime.tryParse(relevantDateRaw);
    if (parsed == null) return false;

    final endTimeRaw = widget.event["end_time"]?.toString();
    final endDateTime = (endTimeRaw == null || endTimeRaw.trim().isEmpty)
        ? DateTime(parsed.year, parsed.month, parsed.day, 23, 59, 59)
        : (() {
            final parts = endTimeRaw.split(":");
            final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
            final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
            final second = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
            return DateTime(
              parsed.year,
              parsed.month,
              parsed.day,
              hour,
              minute,
              second,
            );
          })();

    return IstDateTime.now().isAfter(endDateTime);
  }

  int? _eventIdAsInt() {
    final rawId = widget.event["id"];
    if (rawId is int) return rawId;
    return int.tryParse(rawId?.toString() ?? "");
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

  String _paymentRateLabel(dynamic rateType) {
    switch (rateType?.toString().toLowerCase()) {
      case "per_hour":
        return context.tr("per hour");
      case "fixed":
        return context.tr("fixed amount");
      case "per_day":
      default:
        return context.tr("per day");
    }
  }

  String? _formatPaidPaymentAmount(
    dynamic amount,
    dynamic rateType,
  ) {
    final amountText = amount?.toString();
    if (amountText == null || amountText.isEmpty) {
      return null;
    }

    if (rateType?.toString().toLowerCase() == "fixed") {
      return context.tr(
        "Rs. {amount} fixed amount",
        args: {"amount": amountText},
      );
    }

    final rateLabel = _paymentRateLabel(rateType);
    return context.tr(
      "Rs. {amount} {rate}",
      args: {
        "amount": amountText,
        "rate": rateLabel,
      },
    );
  }

  String _paymentSummaryText(
    dynamic eventType,
    dynamic paymentAmount,
    dynamic paymentRateType,
  ) {
    final type = eventType?.toString().toLowerCase();
    if (type != "paid") {
      return context.tr("Unpaid");
    }

    final paymentText =
        _formatPaidPaymentAmount(paymentAmount, paymentRateType);
    if (paymentText == null) {
      return context.tr("Paid");
    }

    return context.tr(
      "Paid: {text}",
      args: {"text": paymentText},
    );
  }

  String? _paymentClearanceText(
      dynamic eventType, dynamic paymentClearanceDate) {
    final type = eventType?.toString().toLowerCase();
    if (type != "paid") {
      return null;
    }

    final rawDate = paymentClearanceDate?.toString();
    if (rawDate == null || rawDate.trim().isEmpty) {
      return null;
    }

    return context.tr(
      "Payment clears by: {date}",
      args: {"date": IstDateTime.formatDate(rawDate)},
    );
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
            color: Colors.black.withValues(alpha: 0.06),
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
              color: Colors.green.withValues(alpha: 0.12),
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
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.25),
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
              color.withValues(alpha: 0.12),
              color.withValues(alpha: 0.22),
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

  String _normalizedStatus(String status) {
    final normalized = status.toLowerCase();
    if (normalized == "accepted") return "approved";
    return normalized;
  }

  String _normalizedAttendanceStatus(String status) {
    final normalized = status.toLowerCase().trim();
    if (normalized == "present" || normalized == "absent") {
      return normalized;
    }
    return "unmarked";
  }

  String? _statusDescription(String status) {
    final currentAttendance =
        _normalizedAttendanceStatus(attendanceStatus ?? "");
    if (currentAttendance == "present") {
      return context.tr("Your attendance was marked present for this event.");
    }
    if (currentAttendance == "absent") {
      return context.tr("You were marked absent for this event.");
    }

    switch (_normalizedStatus(status)) {
      case "pending":
        return context.tr("Your application is under review.");
      case "waitlisted":
        return context.tr(
          "This event is full right now. The organiser can review and approve waitlisted applications if a spot opens.",
        );
      case "approved":
        if (_isPastEvent()) {
          return context.tr(
            "You were approved for this event. The event has now ended.",
          );
        }
        return context.tr("You are confirmed for this event.");
      case "rejected":
        return context.tr("This application was not approved.");
      case "cancelled":
        final adminReason = (adminCancelReason ?? "").trim();
        if (adminReason.isNotEmpty) {
          if ((cancellationSource ?? "").trim().toLowerCase() == "organiser") {
            return context.tr(
              "Cancelled because the organiser cancelled this event. Reason: {reason}",
              args: {"reason": adminReason},
            );
          }
          return context.tr(
            "Cancelled by admin. Reason: {reason}",
            args: {"reason": adminReason},
          );
        }

        final volunteerReason = (volunteerCancelReason ?? "").trim();
        if (volunteerReason.isNotEmpty) {
          return context.tr(
            "You cancelled your participation. Reason: {reason}",
            args: {"reason": volunteerReason},
          );
        }

        return context.tr("This application was cancelled.");
      case "completed":
        return context.tr("Your participation for this event is completed.");
      default:
        return null;
    }
  }

  Color _statusColor(String status) {
    switch (_normalizedStatus(status)) {
      case "pending":
        return Colors.orange;
      case "approved":
        return Colors.green;
      case "rejected":
        return Colors.red;
      case "cancelled":
        return Colors.red;
      case "waitlisted":
        return Colors.amber;
      case "completed":
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }

  String _statusText(String status) {
    switch (_normalizedStatus(status)) {
      case "pending":
        return context.tr("Application Pending");
      case "approved":
        return context.tr("Application Approved");
      case "rejected":
        return context.tr("Application Rejected");
      case "cancelled":
        return context.tr("Application Cancelled");
      case "waitlisted":
        return context.tr("Application Waitlisted");
      case "completed":
        return context.tr("Event Completed");
      default:
        return context.tr("Application Status Updated");
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openVolunteerVerificationFlow(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const VolunteerGetVerifiedScreen(),
      ),
    );

    if (!mounted) return;
    await _loadVerificationStatus();
  }

  // ================= TERMS =================
  Future<void> _showTerms(BuildContext context) async {
    await _loadVerificationStatus();

    if (!context.mounted) return;

    if (verificationStatus == null) {
      _snack(
        context.tr("Couldn't verify your account status. Please try again."),
      );
      return;
    }

    // Check verification status first
    if (verificationStatus != "approved") {
      _showVerificationRequiredDialog(context);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        bool agreed = false;
        String priorExperience = "";
        String availabilityStatus = "available";

        return StatefulBuilder(
          builder: (context, setState) {
            final media = MediaQuery.of(context);
            return AnimatedPadding(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: media.size.height - media.padding.top - 12,
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    media.padding.bottom + 16,
                  ),
                  child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      context.tr("Volunteer Terms & Conditions"),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr(
                      "• Participation is voluntary and does not constitute employment.",
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                      "• Volunteers must follow organiser instructions and maintain respectful conduct.",
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                      "• Volunteers are responsible for their own safety during the event.",
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                      "• Accurate profile and contact information must be maintained at all times.",
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                      "• VolunteerX is not responsible for any payments, donations, reimbursements, or financial matters related to events; all such transactions are solely between the volunteer and the organiser.",
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr(
                      "Event dates: {dates}",
                      args: {"dates": _formatDateRange()},
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr(
                      "Time: {time}",
                      args: {
                        "time":
                            "${_formatTime(widget.event["start_time"])}-${_formatTime(widget.event["end_time"])}",
                      },
                    ),
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    context.tr("Availability for this event"),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(context.tr("Available")),
                        selected: availabilityStatus == "available",
                        onSelected: (_) =>
                            setState(() => availabilityStatus = "available"),
                      ),
                      ChoiceChip(
                        label: Text(context.tr("Partially available")),
                        selected: availabilityStatus == "partial",
                        onSelected: (_) =>
                            setState(() => availabilityStatus = "partial"),
                      ),
                      ChoiceChip(
                        label: Text(context.tr("Not sure")),
                        selected: availabilityStatus == "unsure",
                        onSelected: (_) =>
                            setState(() => availabilityStatus = "unsure"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr("Prior Experience (optional)"),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: context.tr(
                        "Briefly describe any relevant experience",
                      ),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) =>
                        setState(() => priorExperience = value),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: agreed,
                    onChanged: (v) => setState(() => agreed = v!),
                    title:
                        Text(context.tr("I agree to the Terms & Conditions")),
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: agreed
                          ? () {
                              Navigator.pop(context);
                              _applyToEvent(
                                priorExperience: priorExperience,
                                availabilityStatus: availabilityStatus,
                              );
                            }
                          : null,
                      child: Text(context.tr("Confirm & Apply")),
                    ),
                  ),
                ],
              ),
                ),
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
        message = context.tr(
          "Your verification is under review. You can apply for events after approval.",
        );
        actionText = context.tr("OK");
        action = () => Navigator.pop(context);
        break;
      case "rejected":
        message = context.tr(
          "Your verification was rejected. Please submit verification again to apply for events.",
        );
        actionText = context.tr("Get Verified");
        action = () async {
          Navigator.pop(context);
          await _openVolunteerVerificationFlow(context);
        };
        break;
      default: // "not_requested" or null
        message = context.tr(
          "You need to be verified before applying for events.",
        );
        actionText = context.tr("Get Verified");
        action = () async {
          Navigator.pop(context);
          await _openVolunteerVerificationFlow(context);
        };
        break;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr("Verification Required")),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr("Cancel")),
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
