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

  List<Map<String, dynamic>> _getFilteredUsers() {
    final filtered = users
        .where((u) {
          final matchSearch = u["name"].toLowerCase().contains(search) ||
              u["email"].toLowerCase().contains(search);

          final matchStatus =
              statusFilter == "all" || u["status"] == statusFilter;

          final matchRole = roleFilter == "all" || u["role"] == roleFilter;

          return matchSearch && matchStatus && matchRole;
        })
        .map((u) => u as Map<String, dynamic>)
        .toList();

    filtered.sort((a, b) => _compareUsers(a, b));
    return filtered;
  }

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

  Widget _buildProfileAvatar(String profileUrl, {double radius = 24}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade200,
      backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
      onBackgroundImageError: profileUrl.isNotEmpty ? (_, __) {} : null,
      child: profileUrl.isEmpty
          ? Icon(Icons.person, color: Colors.grey.shade600)
          : null,
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 200,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required Function(bool) onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      backgroundColor: Colors.white,
      selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      checkmarkColor: Theme.of(context).primaryColor,
      side: BorderSide(
        color: selected ? Theme.of(context).primaryColor : Colors.grey.shade300,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            search.isNotEmpty || statusFilter != 'all' || roleFilter != 'all'
                ? 'No users match your filters'
                : 'No users found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            search.isNotEmpty || statusFilter != 'all' || roleFilter != 'all'
                ? 'Try adjusting your search or filters'
                : 'Users will appear here once registered',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          if (search.isNotEmpty || statusFilter != 'all' || roleFilter != 'all')
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    search = '';
                    statusFilter = 'all';
                    roleFilter = 'all';
                  });
                },
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear all filters'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEnhancedUserCard(Map<String, dynamic> user) {
    final isAdmin = user["role"] == "admin";
    final isVerified = user["isVerified"] == true;
    final strikeCount = (user["strike_count"] as num?)?.toInt() ?? 0;
    final suspendedUntilRaw = user["suspended_until"];
    final suspendedUntil = suspendedUntilRaw == null
        ? null
        : DateTime.tryParse(suspendedUntilRaw.toString());
    final isSuspended =
        suspendedUntil != null && suspendedUntil.isAfter(DateTime.now());
    final userId = (user["id"] as num?)?.toInt();
    final canSelect = !isAdmin && userId != null;
    final selected = userId != null && selectedUserIds.contains(userId);
    final profileUrl = (user["profile_picture_url"] ?? "").toString();

    // Get screen size for responsive design
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Card(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 6 : 8),
      elevation: selected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
        side: selected
            ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
        onTap: () {
          if (_selectionMode && canSelect) {
            _toggleSelected(userId);
            return;
          }
          _showUserDetails(context, user);
        },
        onLongPress: canSelect ? () => _toggleSelected(userId) : null,
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          child: Row(
            children: [
              // Selection Checkbox (when in selection mode)
              if (_selectionMode) ...[
                Checkbox(
                  value: selected,
                  onChanged: canSelect ? (_) => _toggleSelected(userId) : null,
                ),
                SizedBox(width: isSmallScreen ? 8 : 12),
              ],

              // Profile Avatar
              _buildProfileAvatar(profileUrl, radius: isSmallScreen ? 24 : 28),
              SizedBox(width: isSmallScreen ? 12 : 16),

              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name and Status Row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user["name"] ?? "Unknown",
                            style: TextStyle(
                              fontSize: isSmallScreen ? 15 : 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: isSmallScreen ? 6 : 8),
                        _buildStatusBadge(user["status"], isSuspended),
                      ],
                    ),

                    SizedBox(height: isSmallScreen ? 3 : 4),

                    // Email and Role
                    Text(
                      user["email"] ?? "",
                      style: TextStyle(
                        fontSize: isSmallScreen ? 13 : 14,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(height: isSmallScreen ? 2 : 2),

                    // Role and Additional Info
                    Row(
                      children: [
                        _buildRoleChip(user["role"]),
                        if (isVerified) ...[
                          SizedBox(width: isSmallScreen ? 6 : 8),
                          Icon(Icons.verified,
                              size: isSmallScreen ? 14 : 16,
                              color: Colors.blue),
                        ],
                        if (strikeCount > 0) ...[
                          SizedBox(width: isSmallScreen ? 6 : 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 5 : 6,
                                vertical: isSmallScreen ? 1.5 : 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius:
                                  BorderRadius.circular(isSmallScreen ? 8 : 10),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text(
                              '$strikeCount strike${strikeCount == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 11 : 12,
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Suspension Info
                    if (isSuspended) ...[
                      SizedBox(height: isSmallScreen ? 3 : 4),
                      Text(
                        "Suspended until ${_formatDateTime(suspendedUntil)}",
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: isSmallScreen ? 11 : 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Action Menu
              if (!isAdmin)
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  onSelected: (value) async {
                    if (value.startsWith("status:")) {
                      final status = value.split(":")[1];
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text("Update user status"),
                          content: Text(
                              "Set ${user["name"]} to ${status.toUpperCase()}?"),
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

                      try {
                        await AdminService.updateUserStatus(user["id"], status);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                "Status updated to ${status.toUpperCase()}"),
                            backgroundColor: Colors.green,
                          ),
                        );
                        _fetchUsers(reset: true);
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Failed to update status: $e"),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } else if (value == "strike:add") {
                      final reason = await _promptStrikeReason();
                      if (reason == null || reason.isEmpty) return;

                      try {
                        final result = await AdminService.addUserStrike(
                            user["id"], reason);
                        if (!mounted) return;
                        final action = result["action"]?.toString();
                        final count =
                            (result["strikeCount"] as num?)?.toInt() ?? 0;
                        final message = action == "banned"
                            ? "User banned after strike"
                            : action != null && action.startsWith("suspended_")
                                ? "User suspended after strike"
                                : "Strike added";
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("$message (strikes: $count)"),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        _fetchUsers(reset: true);
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Failed to add strike: $e"),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } else if (value == "strike:reset") {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text("Reset strikes"),
                          content: Text("Reset strikes for ${user["name"]}?"),
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

                      try {
                        await AdminService.resetUserStrikes(user["id"]);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Strikes reset"),
                            backgroundColor: Colors.green,
                          ),
                        );
                        _fetchUsers(reset: true);
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Failed to reset strikes: $e"),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } else if (value == "suspend") {
                      final input = await _promptSuspension();
                      if (input == null) return;

                      try {
                        await AdminService.suspendUser(
                            user["id"], input.days, input.reason);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("User suspended"),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        _fetchUsers(reset: true);
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Failed to suspend user: $e"),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } else if (value == "unsuspend") {
                      try {
                        await AdminService.unsuspendUser(user["id"]);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("User unsuspended"),
                            backgroundColor: Colors.green,
                          ),
                        );
                        _fetchUsers(reset: true);
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Failed to unsuspend user: $e"),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } else if (value == "view_details") {
                      _showUserDetails(context, user);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: "view_details",
                      padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 12 : 16,
                          vertical: isSmallScreen ? 8 : 12),
                      child: Row(
                        children: [
                          Icon(Icons.visibility, size: isSmallScreen ? 16 : 18),
                          SizedBox(width: isSmallScreen ? 6 : 8),
                          Text("View Details",
                              style:
                                  TextStyle(fontSize: isSmallScreen ? 14 : 16)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: "status:active",
                      padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 12 : 16,
                          vertical: isSmallScreen ? 8 : 12),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              size: isSmallScreen ? 16 : 18,
                              color: Colors.green),
                          SizedBox(width: isSmallScreen ? 6 : 8),
                          Text("Set Active",
                              style:
                                  TextStyle(fontSize: isSmallScreen ? 14 : 16)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: "status:inactive",
                      padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 12 : 16,
                          vertical: isSmallScreen ? 8 : 12),
                      child: Row(
                        children: [
                          Icon(Icons.pause_circle,
                              size: isSmallScreen ? 16 : 18,
                              color: Colors.orange),
                          SizedBox(width: isSmallScreen ? 6 : 8),
                          Text("Set Inactive",
                              style:
                                  TextStyle(fontSize: isSmallScreen ? 14 : 16)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: "status:banned",
                      padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 12 : 16,
                          vertical: isSmallScreen ? 8 : 12),
                      child: Row(
                        children: [
                          Icon(Icons.block,
                              size: isSmallScreen ? 16 : 18, color: Colors.red),
                          SizedBox(width: isSmallScreen ? 6 : 8),
                          Text("Set Banned",
                              style:
                                  TextStyle(fontSize: isSmallScreen ? 14 : 16)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: "strike:add",
                      padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 12 : 16,
                          vertical: isSmallScreen ? 8 : 12),
                      child: Row(
                        children: [
                          Icon(Icons.warning,
                              size: isSmallScreen ? 16 : 18,
                              color: Colors.orange),
                          SizedBox(width: isSmallScreen ? 6 : 8),
                          Text("Add Strike",
                              style:
                                  TextStyle(fontSize: isSmallScreen ? 14 : 16)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: "strike:reset",
                      padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 12 : 16,
                          vertical: isSmallScreen ? 8 : 12),
                      child: Row(
                        children: [
                          Icon(Icons.refresh,
                              size: isSmallScreen ? 16 : 18,
                              color: Colors.blue),
                          SizedBox(width: isSmallScreen ? 6 : 8),
                          Text("Reset Strikes",
                              style:
                                  TextStyle(fontSize: isSmallScreen ? 14 : 16)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: "suspend",
                      padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 12 : 16,
                          vertical: isSmallScreen ? 8 : 12),
                      child: Row(
                        children: [
                          Icon(Icons.timer_off,
                              size: isSmallScreen ? 16 : 18, color: Colors.red),
                          SizedBox(width: isSmallScreen ? 6 : 8),
                          Text("Suspend User",
                              style:
                                  TextStyle(fontSize: isSmallScreen ? 14 : 16)),
                        ],
                      ),
                    ),
                    if (isSuspended)
                      PopupMenuItem(
                        value: "unsuspend",
                        padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 12 : 16,
                            vertical: isSmallScreen ? 8 : 12),
                        child: Row(
                          children: [
                            Icon(Icons.timer,
                                size: isSmallScreen ? 16 : 18,
                                color: Colors.green),
                            SizedBox(width: isSmallScreen ? 6 : 8),
                            Text("Unsuspend",
                                style: TextStyle(
                                    fontSize: isSmallScreen ? 14 : 16)),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isSuspended) {
    Color color;
    IconData icon;
    String label;

    if (isSuspended) {
      color = Colors.red;
      icon = Icons.pause_circle;
      label = "Suspended";
    } else {
      switch (status) {
        case 'active':
          color = Colors.green;
          icon = Icons.check_circle;
          label = "Active";
          break;
        case 'inactive':
          color = Colors.orange;
          icon = Icons.pause_circle;
          label = "Inactive";
          break;
        case 'banned':
          color = Colors.red;
          icon = Icons.block;
          label = "Banned";
          break;
        default:
          color = Colors.grey;
          icon = Icons.help;
          label = status;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChip(String role) {
    Color color;
    String label;

    switch (role) {
      case 'admin':
        color = Colors.purple;
        label = 'Admin';
        break;
      case 'organiser':
        color = Colors.blue;
        label = 'Organiser';
        break;
      case 'volunteer':
        color = Colors.green;
        label = 'Volunteer';
        break;
      default:
        color = Colors.grey;
        label = role;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          if (_selectionMode)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: () => setState(() => selectedUserIds.clear()),
              tooltip: 'Clear selection',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchUsers(reset: true),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: AppBackground(
        child: loading
            ? _buildLoadingSkeleton()
            : errorMessage != null
                ? ErrorState(
                    message: errorMessage!,
                    onRetry: () => _fetchUsers(reset: true),
                  )
                : Builder(
                    builder: (context) {
                      final filteredUsers = _getFilteredUsers();

                      return Column(
                        children: [
                          // Enhanced Search Bar
                          Container(
                            margin: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: "Search by name or email...",
                                prefixIcon: const Icon(Icons.search,
                                    color: Colors.grey),
                                suffixIcon: search.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear,
                                            color: Colors.grey),
                                        onPressed: () =>
                                            setState(() => search = ""),
                                        tooltip: 'Clear search',
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                              ),
                              onChanged: (v) =>
                                  setState(() => search = v.toLowerCase()),
                            ),
                          ),

                          // Enhanced Filters with Chips
                          Container(
                            height: 50,
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                _buildFilterChip(
                                  label: 'All Status',
                                  selected: statusFilter == 'all',
                                  onSelected: (selected) =>
                                      setState(() => statusFilter = 'all'),
                                ),
                                _buildFilterChip(
                                  label: 'Active',
                                  selected: statusFilter == 'active',
                                  onSelected: (selected) =>
                                      setState(() => statusFilter = 'active'),
                                ),
                                _buildFilterChip(
                                  label: 'Inactive',
                                  selected: statusFilter == 'inactive',
                                  onSelected: (selected) =>
                                      setState(() => statusFilter = 'inactive'),
                                ),
                                _buildFilterChip(
                                  label: 'Banned',
                                  selected: statusFilter == 'banned',
                                  onSelected: (selected) =>
                                      setState(() => statusFilter = 'banned'),
                                ),
                                const SizedBox(width: 16),
                                _buildFilterChip(
                                  label: 'All Roles',
                                  selected: roleFilter == 'all',
                                  onSelected: (selected) =>
                                      setState(() => roleFilter = 'all'),
                                ),
                                _buildFilterChip(
                                  label: 'Volunteers',
                                  selected: roleFilter == 'volunteer',
                                  onSelected: (selected) =>
                                      setState(() => roleFilter = 'volunteer'),
                                ),
                                _buildFilterChip(
                                  label: 'Organisers',
                                  selected: roleFilter == 'organiser',
                                  onSelected: (selected) =>
                                      setState(() => roleFilter = 'organiser'),
                                ),
                                _buildFilterChip(
                                  label: 'Admins',
                                  selected: roleFilter == 'admin',
                                  onSelected: (selected) =>
                                      setState(() => roleFilter = 'admin'),
                                ),
                              ],
                            ),
                          ),

                          // Sort Controls
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                const Text('Sort by:',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w500)),
                                const SizedBox(width: 8),
                                DropdownButton<String>(
                                  value: sortField,
                                  underline: const SizedBox(),
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
                                      size: 20),
                                  onPressed: () =>
                                      setState(() => sortAsc = !sortAsc),
                                  tooltip: sortAsc ? 'Ascending' : 'Descending',
                                ),
                              ],
                            ),
                          ),

                          // Selection Mode Actions
                          if (_selectionMode)
                            Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .primaryColor
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Theme.of(context)
                                        .primaryColor
                                        .withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle,
                                      color: Theme.of(context).primaryColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${selectedUserIds.length} user${selectedUserIds.length == 1 ? '' : 's'} selected',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () =>
                                        setState(() => selectedUserIds.clear()),
                                    child: const Text('Clear'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: bulkLoading
                                        ? null
                                        : () => _bulkUpdateStatus("active"),
                                    icon: const Icon(Icons.check_circle,
                                        size: 16),
                                    label: const Text("Activate"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: bulkLoading
                                        ? null
                                        : () => _bulkUpdateStatus("inactive"),
                                    icon: const Icon(Icons.pause_circle,
                                        size: 16),
                                    label: const Text("Deactivate"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: bulkLoading
                                        ? null
                                        : () => _bulkUpdateStatus("banned"),
                                    icon: const Icon(Icons.block, size: 16),
                                    label: const Text("Ban"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // User List with Enhanced Empty State
                          Expanded(
                            child: filteredUsers.isEmpty
                                ? _buildEmptyState()
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    itemCount: filteredUsers.length + 1,
                                    itemBuilder: (context, i) {
                                      if (i == filteredUsers.length) {
                                        final canLoadMore = page <= totalPages;
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                          child: Center(
                                            child: canLoadMore
                                                ? ElevatedButton.icon(
                                                    onPressed: loadingMore
                                                        ? null
                                                        : () => _fetchUsers(),
                                                    icon: loadingMore
                                                        ? const SizedBox(
                                                            width: 16,
                                                            height: 16,
                                                            child:
                                                                CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2),
                                                          )
                                                        : const Icon(
                                                            Icons.expand_more),
                                                    label: Text(loadingMore
                                                        ? "Loading..."
                                                        : "Load More Users"),
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 24,
                                                          vertical: 12),
                                                    ),
                                                  )
                                                : Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            16),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.grey.shade100,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: const Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Icon(Icons.check_circle,
                                                            color:
                                                                Colors.green),
                                                        SizedBox(width: 8),
                                                        Text("All users loaded",
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .grey)),
                                                      ],
                                                    ),
                                                  ),
                                          ),
                                        );
                                      }

                                      return _buildEnhancedUserCard(
                                          filteredUsers[i]);
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
    final strikeCount = (user["strike_count"] as num?)?.toInt() ?? 0;
    final strikeHistory = (user["strike_history"] as List?) ?? [];
    final suspendedUntilRaw = user["suspended_until"];
    final suspendedUntil = suspendedUntilRaw == null
        ? null
        : DateTime.tryParse(suspendedUntilRaw.toString());
    final isSuspended =
        suspendedUntil != null && suspendedUntil.isAfter(DateTime.now());
    final suspensionReason = (user["suspension_reason"] ?? "-").toString();

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
            _detailRow("Strikes", strikeCount.toString()),
            if (strikeHistory.isNotEmpty) ...[
              const SizedBox(height: 6),
              const Text(
                "Strike History",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              ...strikeHistory.map((entry) {
                final reason = (entry["reason"] ?? "-").toString();
                final createdAtRaw = entry["created_at"];
                final createdAt = createdAtRaw == null
                    ? "-"
                    : _formatDateTime(
                        DateTime.tryParse(createdAtRaw.toString()) ??
                            DateTime.fromMillisecondsSinceEpoch(0),
                      );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text("• $createdAt: $reason"),
                );
              }),
            ],
            _detailRow(
              "Suspended",
              isSuspended ? _formatDateTime(suspendedUntil) : "No",
            ),
            if (isSuspended) _detailRow("Reason", suspensionReason),
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

  String _formatDateTime(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return "$y-$m-$d $hh:$mm";
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

  Future<_SuspensionInput?> _promptSuspension() async {
    final daysController = TextEditingController(text: "3");
    final reasonController = TextEditingController();
    final result = await showDialog<_SuspensionInput>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Suspend User"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: daysController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Days",
                hintText: "Number of days to suspend",
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Reason",
                hintText: "Reason for suspension",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              final days = int.tryParse(daysController.text.trim());
              final reason = reasonController.text.trim();
              if (days == null || days < 1 || reason.isEmpty) {
                return;
              }
              Navigator.pop(ctx, _SuspensionInput(days: days, reason: reason));
            },
            child: const Text("Suspend"),
          ),
        ],
      ),
    );
    return result;
  }

  Future<String?> _promptStrikeReason() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Strike"),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Reason for strike",
            labelText: "Reason",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text("Add Strike"),
          ),
        ],
      ),
    );
    return result;
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

class _SuspensionInput {
  final int days;
  final String reason;

  _SuspensionInput({
    required this.days,
    required this.reason,
  });
}
