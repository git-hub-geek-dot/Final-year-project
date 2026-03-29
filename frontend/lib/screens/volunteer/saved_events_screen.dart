import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../services/saved_events_service.dart';
import '../../services/notification_service.dart';
import '../../utils/ist_date_time.dart';
import 'view_event_screen.dart';
import '../../localization/localization_extensions.dart';

class SavedEventsScreen extends StatefulWidget {
  const SavedEventsScreen({super.key});

  @override
  State<SavedEventsScreen> createState() => _SavedEventsScreenState();
}

class _SavedEventsScreenState extends State<SavedEventsScreen> {
  bool loading = true;
  String? errorMessage;
  List<Map<String, dynamic>> savedEvents = [];
  StreamSubscription<Map<String, dynamic>>? _notificationSub;

  @override
  void initState() {
    super.initState();
    _loadSavedEvents();
    _notificationSub =
        NotificationService.messageEvents.listen(_handleNotificationEvent);
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    super.dispose();
  }

  Future<void> _handleNotificationEvent(Map<String, dynamic> data) async {
    if (!mounted) return;

    final type = (data["type"] ?? "").toString().trim().toLowerCase();
    if (type != "event_removed" &&
        type != "event_deleted" &&
        type != "event_update" &&
        type != "event_broadcast") {
      return;
    }

    final rawEventId = data["eventId"] ?? data["event_id"];
    final eventId = rawEventId?.toString();
    if (eventId == null || eventId.trim().isEmpty) return;

    final isSaved =
        savedEvents.any((event) => event["id"].toString() == eventId);
    if (!isSaved) return;

    if (type == "event_removed" || type == "event_deleted") {
      await SavedEventsService.removeEvent(eventId);
      if (!mounted) return;
      await _loadSavedEvents();
      return;
    }

    await _refreshSavedEvent(eventId);
  }

  Future<void> _refreshSavedEvent(String eventId) async {
    http.Response? response;
    try {
      response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/events/$eventId"),
      );
    } catch (_) {
      response = null;
    }

    if (!mounted) return;

    if (response == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("Failed to refresh saved event."))),
      );
      return;
    }

    if (response.statusCode == 404) {
      await SavedEventsService.removeEvent(eventId);
      if (!mounted) return;
      await _loadSavedEvents();
      return;
    }

    if (response.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("Failed to refresh saved event."))),
      );
      return;
    }

    final decoded = jsonDecode(response.body);
    final freshEvent = decoded is Map<String, dynamic>
        ? decoded
        : Map<String, dynamic>.from(decoded as Map);
    await SavedEventsService.saveEvent(freshEvent);
    if (!mounted) return;
    await _loadSavedEvents();
  }

  Future<void> _loadSavedEvents() async {
    try {
      setState(() {
        loading = true;
        errorMessage = null;
      });

      final events = await SavedEventsService.getSavedEvents();

      if (!mounted) return;
      setState(() {
        savedEvents = events;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = context.tr("Failed to load saved events.");
      });
    }
  }

  Future<void> _removeEvent(String eventId) async {
    await SavedEventsService.removeEvent(eventId);
    await _loadSavedEvents();
  }

  Future<void> _openSavedEvent(Map<String, dynamic> event) async {
    final rawId = event["id"];
    final eventId = int.tryParse(rawId?.toString() ?? "");
    if (eventId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("Invalid event details"))),
      );
      return;
    }

    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    http.Response? response;
    try {
      response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/events/$eventId"),
      );
    } catch (_) {
      response = null;
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (response == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("Failed to load event details"))),
      );
      return;
    }

    if (response.statusCode == 404) {
      await SavedEventsService.removeEvent(eventId.toString());
      if (!mounted) return;
      await _loadSavedEvents();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("This event is no longer available."))),
      );
      return;
    }

    if (response.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("Failed to load event details"))),
      );
      return;
    }

    final decoded = jsonDecode(response.body);
    final freshEvent = decoded is Map<String, dynamic>
        ? decoded
        : Map<String, dynamic>.from(decoded as Map);

    await SavedEventsService.saveEvent(freshEvent);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewEventScreen(event: freshEvent),
      ),
    );
    await _loadSavedEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr("Saved Events")),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSavedEvents,
          ),
        ],
      ),
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
              : savedEvents.isEmpty
                  ? Center(child: Text(context.tr("No saved events yet")))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: savedEvents.length,
                      itemBuilder: (context, index) {
                        final event = savedEvents[index];
                        final title =
                            event["title"] ?? context.tr("Unknown Event");
                        final location = event["location"] ?? "";
                        final formatted =
                            IstDateTime.formatDate(event["event_date"]);
                        final date = formatted == "-" ? "" : formatted;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(title.toString()),
                            subtitle: Text(
                              [location, date]
                                  .where((value) => value.isNotEmpty)
                                  .join(" • "),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.bookmark_remove),
                              onPressed: () {
                                final id = event["id"].toString();
                                _removeEvent(id);
                              },
                            ),
                            onTap: () => _openSavedEvent(event),
                          ),
                        );
                      },
                    ),
    );
  }
}
