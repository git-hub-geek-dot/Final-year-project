import 'package:flutter/material.dart';
import '../../services/admin_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  // ✅ ADDED (previous step)
  String query = "all"; // all | active | blocked
  String search = "";

  late Future<List<dynamic>> usersFuture;

  @override
  void initState() {
    super.initState();
    usersFuture = AdminService.getAllUsers();
  }

  void refresh() {
    setState(() {
      usersFuture = AdminService.getAllUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: usersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(child: Text("Failed to load users"));
        }

        final users = snapshot.data!;

        // ✅ ADDED: filter users before ListView
        final filtered = users.where((u) {
          final matchSearch =
              u["name"].toLowerCase().contains(search) ||
              u["email"].toLowerCase().contains(search);

          final matchStatus =
              query == "all" || u["status"] == query;

          return matchSearch && matchStatus;
        }).toList();

        // ✅ ADDED: extracted users list
        final usersList = ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final u = filtered[i];
            final isBlocked = u["status"] == "blocked";

            return Card(
              child: ListTile(
                title: Text(u["name"]),
                subtitle: Text("${u["email"]} • ${u["role"]}"),
                trailing: TextButton(
                  onPressed: () async {
                    await AdminService.updateUserStatus(
                      u["id"],
                      isBlocked ? "active" : "blocked",
                    );
                    refresh();
                  },
                  child: Text(
                    isBlocked ? "UNBLOCK" : "BLOCK",
                    style: TextStyle(
                      color: isBlocked ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ),
            );
          },
        );

        // ✅ UPDATED: wrap list with Column
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: "Search name or email",
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) =>
                    setState(() => search = v.toLowerCase()),
              ),
            ),
            DropdownButton<String>(
              value: query,
              items: const [
                DropdownMenuItem(value: "all", child: Text("All")),
                DropdownMenuItem(value: "active", child: Text("Active")),
                DropdownMenuItem(value: "blocked", child: Text("Blocked")),
              ],
              onChanged: (v) => setState(() => query = v!),
            ),
            Expanded(child: usersList),
          ],
        );
      },
    );
  }
}
