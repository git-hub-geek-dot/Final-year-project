import 'package:flutter/material.dart';
import '../../services/admin_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  late Future<List<dynamic>> usersFuture;

  String search = "";
  String statusFilter = "all"; // all | active | blocked
  String roleFilter = "all";   // all | volunteer | organiser | admin

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

        final filtered = users.where((u) {
          final matchSearch =
              u["name"].toLowerCase().contains(search) ||
              u["email"].toLowerCase().contains(search);

          final matchStatus =
              statusFilter == "all" || u["status"] == statusFilter;

          final matchRole =
              roleFilter == "all" || u["role"] == roleFilter;

          return matchSearch && matchStatus && matchRole;
        }).toList();

        return Column(
          children: [
            // 🔍 Search
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

            // 🔽 Filters
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  DropdownButton<String>(
                    value: statusFilter,
                    items: const [
                      DropdownMenuItem(
                          value: "all", child: Text("All Status")),
                      DropdownMenuItem(
                          value: "active", child: Text("Active")),
                      DropdownMenuItem(
                          value: "blocked", child: Text("Blocked")),
                    ],
                    onChanged: (v) =>
                        setState(() => statusFilter = v!),
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<String>(
                    value: roleFilter,
                    items: const [
                      DropdownMenuItem(
                          value: "all", child: Text("All Roles")),
                      DropdownMenuItem(
                          value: "volunteer", child: Text("Volunteer")),
                      DropdownMenuItem(
                          value: "organiser", child: Text("Organiser")),
                      DropdownMenuItem(
                          value: "admin", child: Text("Admin")),
                    ],
                    onChanged: (v) =>
                        setState(() => roleFilter = v!),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // 📋 User list
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text("No users found"))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final u = filtered[i];
                        final isBlocked = u["status"] == "banned";
                        final isAdmin = u["role"] == "admin";

                        return Card(
                          child: ListTile(
                            title: Text(u["name"]),
                            subtitle: Text(
                              "${u["email"]} • ${u["role"]} • ${u["status"]}",
                            ),
                            trailing: TextButton(
                              onPressed: isAdmin
                                  ? null
                                  : () async {
                                      await AdminService.updateUserStatus(
                                        u["id"],
                                        isBlocked ? "active" : "banned",
                                      );
                                      refresh();
                                    },
                              child: Text(
                                isBlocked ? "UNBLOCK" : "BLOCK",
                                style: TextStyle(
                                  color: isBlocked
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
