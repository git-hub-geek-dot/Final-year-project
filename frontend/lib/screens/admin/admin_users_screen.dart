import 'package:flutter/material.dart';
import '../../services/admin_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
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

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, i) {
            final u = users[i];
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
      },
    );
  }
}
