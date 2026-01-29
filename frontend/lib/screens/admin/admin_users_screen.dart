import 'package:flutter/material.dart';
import 'package:frontend/widgets/app_background.dart';
import '../../services/admin_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final List<dynamic> users = [];
  bool loading = true;
  bool loadingMore = false;
  int page = 1;
  int totalPages = 1;

  String search = "";
  String statusFilter = "all"; // all | active | inactive | banned
  String roleFilter = "all";   // all | volunteer | organiser | admin

  @override
  void initState() {
    super.initState();
    _fetchUsers(reset: true);
  }

  Future<void> _fetchUsers({bool reset = false}) async {
    if (loadingMore) return;
    if (reset) {
      setState(() {
        loading = true;
        page = 1;
        totalPages = 1;
        users.clear();
      });
    } else {
      setState(() => loadingMore = true);
    }

    try {
      final data = await AdminService.getAllUsers(page: page, limit: 20);
      final items = (data["items"] as List?) ?? [];
      setState(() {
        users.addAll(items);
        totalPages = data["totalPages"] ?? 1;
        loading = false;
        loadingMore = false;
        page += 1;
      });
    } catch (_) {
      setState(() {
        loading = false;
        loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
      ),
      body: AppBackground(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : Builder(
                builder: (context) {
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
                                    value: "inactive", child: Text("Inactive")),
                                DropdownMenuItem(
                                    value: "banned", child: Text("Banned")),
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
                                itemCount: filtered.length + 1,
                                itemBuilder: (context, i) {
                                  if (i == filtered.length) {
                                    final canLoadMore = page <= totalPages;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      child: Center(
                                        child: canLoadMore
                                            ? ElevatedButton(
                                                onPressed: loadingMore
                                                    ? null
                                                    : () => _fetchUsers(),
                                                child: loadingMore
                                                    ? const SizedBox(
                                                        width: 18,
                                                        height: 18,
                                                        child:
                                                            CircularProgressIndicator(strokeWidth: 2),
                                                      )
                                                    : const Text("Load More"),
                                              )
                                            : const Text("No more users"),
                                      ),
                                    );
                                  }

                                  final u = filtered[i];
                                  final isAdmin = u["role"] == "admin";
                                  final profileUrl =
                                      (u["profile_picture_url"] ?? "")
                                          .toString();

                                  return Card(
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundImage: profileUrl.isNotEmpty
                                            ? NetworkImage(profileUrl)
                                            : null,
                                        child: profileUrl.isEmpty
                                            ? const Icon(Icons.person)
                                            : null,
                                      ),
                                      title: Text(u["name"]),
                                      subtitle: Text(
                                        "${u["email"]} • ${u["role"]} • ${u["status"]}",
                                      ),
                                      onTap: () => _showUserDetails(context, u),
                                      trailing: isAdmin
                                          ? const Text("Admin")
                                          : PopupMenuButton<String>(
                                              onSelected: (value) async {
                                                await AdminService.updateUserStatus(
                                                  u["id"],
                                                  value,
                                                );
                                                _fetchUsers(reset: true);
                                              },
                                              itemBuilder: (context) => const [
                                                PopupMenuItem(
                                                  value: "active",
                                                  child: Text("Set Active"),
                                                ),
                                                PopupMenuItem(
                                                  value: "inactive",
                                                  child: Text("Set Inactive"),
                                                ),
                                                PopupMenuItem(
                                                  value: "banned",
                                                  child: Text("Set Banned"),
                                                ),
                                              ],
                                              child: Chip(
                                                label: Text(
                                                  (u["status"] ?? "active")
                                                      .toString()
                                                      .toUpperCase(),
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
              ),
      ),
    );
  }

  void _showUserDetails(BuildContext context, Map<String, dynamic> user) {
    final name = user["name"] ?? "-";
    final email = user["email"] ?? "-";
    final role = user["role"] ?? "-";
    final status = user["status"] ?? "-";
    final city = user["city"] ?? "-";
    final contact = user["contact_number"] ?? "-";
    final createdAt = (user["created_at"] ?? "-").toString();
    final profileUrl = (user["profile_picture_url"] ?? "").toString();
    final isVerified = user["isVerified"] == true;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("User Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 36,
                backgroundImage:
                    profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
                child:
                    profileUrl.isEmpty ? const Icon(Icons.person, size: 36) : null,
              ),
            ),
            const SizedBox(height: 12),
            _detailRow("Name", name),
            _detailRow("Email", email),
            _detailRow("Role", role),
            _detailRow("Verified", isVerified ? "Yes" : "No"),
            _detailRow("Status", status),
            _detailRow("City", city),
            _detailRow("Contact", contact),
            _detailRow("Joined", createdAt),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
