// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:frontend/widgets/app_background.dart';
import 'package:frontend/widgets/error_state.dart';
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
  bool bulkLoading = false;
  int page = 1;
  int totalPages = 1;
  String? errorMessage;

  final Set<int> selectedUserIds = {};

  String search = "";
  String statusFilter = "all"; // all | active | inactive | banned
  String roleFilter = "all"; // all | volunteer | organiser | admin
  String sortField = "created_at"; // name | created_at | status
  bool sortAsc = false;

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
        errorMessage = null;
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
        errorMessage = null;
      });
    } catch (_) {
      setState(() {
        loading = false;
        loadingMore = false;
        if (reset) {
          errorMessage = "Failed to load users";
        }
      });
    }
  }

  bool get _selectionMode => selectedUserIds.isNotEmpty;

  void _toggleSelected(int userId) {
    setState(() {
      if (selectedUserIds.contains(userId)) {
        selectedUserIds.remove(userId);
      } else {
        selectedUserIds.add(userId);
      }
    });
  }

  Future<void> _bulkUpdateStatus(String status) async {
    if (selectedUserIds.isEmpty || bulkLoading) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Bulk update status"),
        content: Text(
          "Set ${selectedUserIds.length} users to ${status.toUpperCase()}?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => bulkLoading = true);

    final totalSelected = selectedUserIds.length;
    int successCount = 0;
    for (final id in selectedUserIds) {
      try {
        await AdminService.updateUserStatus(id, status);
        successCount++;
      } catch (_) {}
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Updated $successCount of $totalSelected users",
        ),
      ),
    );

    setState(() {
      bulkLoading = false;
      selectedUserIds.clear();
    });

    _fetchUsers(reset: true);
  }

  Widget _buildProfileAvatar(String profileUrl) {
    return CircleAvatar(
      backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
      onBackgroundImageError: profileUrl.isNotEmpty ? (_, __) {} : null,
      child: profileUrl.isEmpty ? const Icon(Icons.person) : null,
    );
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
            : errorMessage != null
                ? ErrorState(
                    message: errorMessage!,
                    onRetry: () => _fetchUsers(reset: true),
                  )
                : Builder(
                    builder: (context) {
                      final filtered = users.where((u) {
                        final matchSearch =
                            u["name"].toLowerCase().contains(search) ||
                                u["email"].toLowerCase().contains(search);

                        final matchStatus = statusFilter == "all" ||
                            u["status"] == statusFilter;

                        final matchRole =
                            roleFilter == "all" || u["role"] == roleFilter;

                        return matchSearch && matchStatus && matchRole;
                      }).toList()
                        ..sort((a, b) => _compareUsers(a, b));

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
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                DropdownButton<String>(
                                  value: statusFilter,
                                  items: const [
                                    DropdownMenuItem(
                                        value: "all",
                                        child: Text("All Status")),
                                    DropdownMenuItem(
                                        value: "active", child: Text("Active")),
                                    DropdownMenuItem(
                                        value: "inactive",
                                        child: Text("Inactive")),
                                    DropdownMenuItem(
                                        value: "banned", child: Text("Banned")),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => statusFilter = v!),
                                ),
                                DropdownButton<String>(
                                  value: roleFilter,
                                  items: const [
                                    DropdownMenuItem(
                                        value: "all", child: Text("All Roles")),
                                    DropdownMenuItem(
                                        value: "volunteer",
                                        child: Text("Volunteer")),
                                    DropdownMenuItem(
                                        value: "organiser",
                                        child: Text("Organiser")),
                                    DropdownMenuItem(
                                        value: "admin", child: Text("Admin")),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => roleFilter = v!),
                                ),
                                DropdownButton<String>(
                                  value: sortField,
                                  items: const [
                                    DropdownMenuItem(
                                        value: "created_at",
                                        child: Text("Newest")),
                                    DropdownMenuItem(
                                        value: "name", child: Text("Name")),
                                    DropdownMenuItem(
                                        value: "status", child: Text("Status")),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => sortField = v!),
                                ),
                                IconButton(
                                  icon: Icon(
                                    sortAsc
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                  ),
                                  onPressed: () =>
                                      setState(() => sortAsc = !sortAsc),
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),

                          if (_selectionMode)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text("${selectedUserIds.length} selected"),
                                  OutlinedButton(
                                    onPressed: bulkLoading
                                        ? null
                                        : () => setState(
                                              () => selectedUserIds.clear(),
                                            ),
                                    child: const Text("Clear"),
                                  ),
                                  ElevatedButton(
                                    onPressed: bulkLoading
                                        ? null
                                        : () => _bulkUpdateStatus("active"),
                                    child: const Text("Set Active"),
                                  ),
                                  ElevatedButton(
                                    onPressed: bulkLoading
                                        ? null
                                        : () => _bulkUpdateStatus("inactive"),
                                    child: const Text("Set Inactive"),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: bulkLoading
                                        ? null
                                        : () => _bulkUpdateStatus("banned"),
                                    child: const Text("Set Banned"),
                                  ),
                                ],
                              ),
                            ),

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
                                                                CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2),
                                                          )
                                                        : const Text(
                                                            "Load More"),
                                                  )
                                                : const Text("No more users"),
                                          ),
                                        );
                                      }

                                      final u = filtered[i];
                                      final isAdmin = u["role"] == "admin";
                                      final isVerified =
                                          u["isVerified"] == true;
                                      final userId = (u["id"] as num?)?.toInt();
                                      final canSelect =
                                          !isAdmin && userId != null;
                                      final selected = userId != null &&
                                          selectedUserIds.contains(userId);
                                      final profileUrl =
                                          (u["profile_picture_url"] ?? "")
                                              .toString();

                                      return Card(
                                        child: ListTile(
                                          leading: _selectionMode || selected
                                              ? SizedBox(
                                                  width: 72,
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Checkbox(
                                                        value: selected,
                                                        onChanged: canSelect
                                                            ? (_) =>
                                                                _toggleSelected(
                                                                    userId)
                                                            : null,
                                                      ),
                                                      _buildProfileAvatar(
                                                          profileUrl),
                                                    ],
                                                  ),
                                                )
                                              : _buildProfileAvatar(profileUrl),
                                          title: Text(u["name"]),
                                          subtitle: Text(
                                            "${u["email"]} • ${u["role"]} • ${u["status"]}",
                                          ),
                                          onTap: () {
                                            if (_selectionMode && canSelect) {
                                              _toggleSelected(userId);
                                              return;
                                            }
                                            _showUserDetails(context, u);
                                          },
                                          onLongPress: canSelect
                                              ? () => _toggleSelected(userId)
                                              : null,
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _verificationBadge(isVerified),
                                              const SizedBox(width: 6),
                                              if (isAdmin)
                                                const Text("Admin")
                                              else
                                                PopupMenuButton<String>(
                                                  onSelected: (value) async {
                                                    final confirm =
                                                        await showDialog<bool>(
                                                      context: context,
                                                      builder: (ctx) =>
                                                          AlertDialog(
                                                        title: const Text(
                                                          "Update user status",
                                                        ),
                                                        content: Text(
                                                          "Set ${u["name"]} to ${value.toUpperCase()}?",
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                    ctx, false),
                                                            child: const Text(
                                                                "Cancel"),
                                                          ),
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                    ctx, true),
                                                            child: const Text(
                                                                "Confirm"),
                                                          ),
                                                        ],
                                                      ),
                                                    );

                                                    if (confirm != true) return;

                                                    try {
                                                      await AdminService
                                                          .updateUserStatus(
                                                        u["id"],
                                                        value,
                                                      );
                                                      if (!mounted) return;
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            "Status updated to ${value.toUpperCase()}",
                                                          ),
                                                        ),
                                                      );
                                                      _fetchUsers(reset: true);
                                                    } catch (_) {
                                                      if (!mounted) return;
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                            "Failed to update status",
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                  itemBuilder: (context) =>
                                                      const [
                                                    PopupMenuItem(
                                                      value: "active",
                                                      child: Text("Set Active"),
                                                    ),
                                                    PopupMenuItem(
                                                      value: "inactive",
                                                      child:
                                                          Text("Set Inactive"),
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
                                            ],
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
                onBackgroundImageError:
                    profileUrl.isNotEmpty ? (_, __) {} : null,
                child: profileUrl.isEmpty
                    ? const Icon(Icons.person, size: 36)
                    : null,
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

  Widget _verificationBadge(bool isVerified) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isVerified ? Colors.green.shade50 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isVerified ? "Verified" : "Unverified",
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isVerified ? Colors.green.shade700 : Colors.grey.shade700,
        ),
      ),
    );
  }

  int _compareUsers(Map a, Map b) {
    int result;
    switch (sortField) {
      case "name":
        result = (a["name"] ?? "")
            .toString()
            .toLowerCase()
            .compareTo((b["name"] ?? "").toString().toLowerCase());
        break;
      case "status":
        result = (a["status"] ?? "")
            .toString()
            .compareTo((b["status"] ?? "").toString());
        break;
      case "created_at":
      default:
        final aDate = DateTime.tryParse((a["created_at"] ?? "").toString());
        final bDate = DateTime.tryParse((b["created_at"] ?? "").toString());
        result = (aDate ?? DateTime(1970)).compareTo(bDate ?? DateTime(1970));
        break;
    }

    return sortAsc ? result : -result;
  }
}
