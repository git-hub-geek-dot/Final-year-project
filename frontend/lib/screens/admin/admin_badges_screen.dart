import 'package:flutter/material.dart';
import 'package:frontend/widgets/app_background.dart';
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

    await showDialog(
      context: context,
      builder: (_) {
        String role = "volunteer";
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
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
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          role = v;
                        });
                      }
                    },
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
                    // ignore: use_build_context_synchronously
                    Navigator.pop(context);
                    refresh();
                  },
                  child: const Text("Create"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Badges'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: addBadgeDialog,
        child: const Icon(Icons.add),
      ),
      body: AppBackground(
        child: FutureBuilder<List<dynamic>>(
          future: badgesFuture,
          builder: (_, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}"));
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text("No badges created yet."));
            }

            final badges = snapshot.data!;

            return ListView.builder(
              itemCount: badges.length,
              itemBuilder: (_, i) {
                final b = badges[i];
                return ListTile(
                  leading: const Icon(Icons.emoji_events, color: Colors.amber, size: 40),
                  title: Text(b["name"], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${b["role"]} • Requires ${b["threshold"]} events"),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () => _deleteBadge(b['id']),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _deleteBadge(int badgeId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Badge'),
        content: const Text('Are you sure you want to delete this badge? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AdminService.deleteBadge(badgeId);
        refresh();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete badge: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
