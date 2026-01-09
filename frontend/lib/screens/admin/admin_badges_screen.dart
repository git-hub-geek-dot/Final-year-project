import 'package:flutter/material.dart';
import '../../services/admin_service.dart';

class AdminBadgesScreen extends StatefulWidget {
  const AdminBadgesScreen({super.key});

  @override
  State<AdminBadgesScreen> createState() => _AdminBadgesScreenState();
}

class _AdminBadgesScreenState extends State<AdminBadgesScreen> {
  late Future<List<dynamic>> badgesFuture;

  @override
  void initState() {
    super.initState();
    badgesFuture = AdminService.getBadges();
  }

  void refresh() {
    setState(() {
      badgesFuture = AdminService.getBadges();
    });
  }

  Future<void> addBadgeDialog() async {
    final name = TextEditingController();
    final desc = TextEditingController();
    final threshold = TextEditingController();
    String role = "volunteer";

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Create Badge"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: "Name")),
            TextField(controller: desc, decoration: const InputDecoration(labelText: "Description")),
            TextField(controller: threshold, decoration: const InputDecoration(labelText: "Threshold")),
            DropdownButton<String>(
              value: role,
              items: const [
                DropdownMenuItem(value: "volunteer", child: Text("Volunteer")),
                DropdownMenuItem(value: "organiser", child: Text("Organiser")),
              ],
              onChanged: (v) => role = v!,
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await AdminService.createBadge({
                "name": name.text,
                "description": desc.text,
                "role": role,
                "threshold": int.parse(threshold.text),
              });
              Navigator.pop(context);
              refresh();
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: ElevatedButton(
              onPressed: addBadgeDialog,
              child: const Text("Add Badge"),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: badgesFuture,
            builder: (_, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final badges = snapshot.data!;
              if (badges.isEmpty) {
                return const Center(child: Text("No badges created"));
              }

              return ListView.builder(
                itemCount: badges.length,
                itemBuilder: (_, i) {
                  final b = badges[i];
                  return ListTile(
                    leading: const Icon(Icons.emoji_events),
                    title: Text(b["name"]),
                    subtitle: Text("${b["role"]} • ${b["threshold"]} events"),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
