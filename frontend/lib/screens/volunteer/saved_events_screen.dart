import 'package:flutter/material.dart';
import '../../services/saved_events_service.dart';
import 'view_event_screen.dart';

class SavedEventsScreen extends StatefulWidget {
  const SavedEventsScreen({super.key});

  @override
  State<SavedEventsScreen> createState() => _SavedEventsScreenState();
}

class _SavedEventsScreenState extends State<SavedEventsScreen> {
  bool loading = true;
  String? errorMessage;
  List<Map<String, dynamic>> savedEvents = [];

  @override
  void initState() {
    super.initState();
    _loadSavedEvents();
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
        errorMessage = "Failed to load saved events.";
      });
    }
  }

  Future<void> _removeEvent(String eventId) async {
    await SavedEventsService.removeEvent(eventId);
    await _loadSavedEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Saved Events"),
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
                  ? const Center(child: Text("No saved events yet"))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: savedEvents.length,
                      itemBuilder: (context, index) {
                        final event = savedEvents[index];
                        final title = event["title"] ?? "Unknown Event";
                        final location = event["location"] ?? "";
                        final date = event["event_date"]
                                ?.toString()
                                .split("T")
                                .first ??
                            "";

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
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ViewEventScreen(event: event),
                                ),
                              );
                              await _loadSavedEvents();
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}
