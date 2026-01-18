import 'package:flutter/material.dart';
import 'package:frontend/widgets/app_background.dart';
import '../../services/admin_service.dart';
import 'package:flutter/widgets.dart';

class AdminVerificationScreen extends StatefulWidget {
  const AdminVerificationScreen({super.key});

  @override
  State<AdminVerificationScreen> createState() =>
      _AdminVerificationScreenState();
}

class _AdminVerificationScreenState extends State<AdminVerificationScreen> {
  late Future<List<dynamic>> _futureRequests;
  String _filterRole = 'all';
  String _filterStatus = 'pending';

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  void _loadRequests() {
    setState(() {
      _futureRequests = AdminService.getVerificationRequests();
    });
  }

  Future<void> _approve(int requestId) async {
    await AdminService.approveVerification(requestId);
    _loadRequests();
  }

  Future<void> _reject(int requestId) async {
    final controller = TextEditingController();

    final remark = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reject Verification"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Enter rejection reason",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim()),
            child: const Text(
              "Reject",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (remark == null || remark.isEmpty) return;

    await AdminService.rejectVerification(requestId, remark);
    _loadRequests();
  }

  // Show modal with full details and actions
  void _showDetailsModal(Map r) {
    showDialog(
      context: context,
      builder: (context) {
        final user = r["user"];
        final idType = r["idType"] ?? r["id_type"] ?? "-";
        final idNumber = r["idNumber"] ?? r["id_number"] ?? "-";
        final organisationName = r["organisationName"] ?? r["organisation_name"];
        final eventProofUrl = r["eventProofUrl"] ?? r["event_proof_url"];
        final websiteLink = r["websiteLink"] ?? r["website_link"];

        return AlertDialog(
          contentPadding: const EdgeInsets.all(12),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user["name"] ?? "Unnamed", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(user["email"] ?? ""),
                const SizedBox(height: 6),
                Text("Role: ${r["role"]}"),
                const SizedBox(height: 4),
                Text("Status: ${r["status"]}"),
                const Divider(height: 18),

                Text("ID Type: $idType"),
                const SizedBox(height: 4),
                Text("ID Number: $idNumber"),
                const SizedBox(height: 8),

                if (organisationName != null && organisationName.toString().isNotEmpty) ...[
                  Text("Organisation: $organisationName"),
                  const SizedBox(height: 8),
                ],

                if (websiteLink != null && websiteLink.toString().isNotEmpty) ...[
                  SelectableText("Website: $websiteLink"),
                  const SizedBox(height: 8),
                ],

                if (eventProofUrl != null) ...[
                  const Text("Event proof:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  SizedBox(height: 120, width: double.infinity, child: _buildPreviewImage(eventProofUrl)),
                  const SizedBox(height: 8),
                ],

                if ((r["idDocumentUrl"] ?? r["id_document_url"]) != null) ...[
                  const Text("ID Proof:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  SizedBox(height: 150, width: double.infinity, child: _buildPreviewImage(r["idDocumentUrl"] ?? r["id_document_url"])),
                  const SizedBox(height: 8),
                ],

                if ((r["selfieUrl"] ?? r["selfie_url"]) != null) ...[
                  const Text("Selfie with ID:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  SizedBox(height: 150, width: double.infinity, child: _buildPreviewImage(r["selfieUrl"] ?? r["selfie_url"])),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Close"),
            ),
            if (r["status"] == "pending") ...[
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _reject(r["id"]);
                },
                child: const Text("Reject", style: TextStyle(color: Colors.red)),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _approve(r["id"]);
                },
                child: const Text("Approve"),
              ),
            ]
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification Requests'),
      ),
      body: AppBackground(
        child: FutureBuilder<List<dynamic>>(
          future: _futureRequests,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text("Failed to load verification requests: ${snapshot.error}"),
              );
            }

            final requests = snapshot.data!;

            // Apply client-side filters
            final filtered = requests.where((r) {
              final role = (r["role"] ?? r["user"]?['role'])?.toString().toLowerCase();
              final status = (r["status"] ?? r["status"])?.toString().toLowerCase();

              final roleOk = _filterRole == 'all' || (role != null && role == _filterRole);
              final statusOk = _filterStatus == 'all' || (status != null && status == _filterStatus);
              return roleOk && statusOk;
            }).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _filterRole,
                          decoration: const InputDecoration(labelText: 'Role'),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All Roles')),
                            DropdownMenuItem(value: 'volunteer', child: Text('Volunteer')),
                            DropdownMenuItem(value: 'organiser', child: Text('Organiser')),
                          ],
                          onChanged: (v) => setState(() => _filterRole = v ?? 'all'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _filterStatus,
                          decoration: const InputDecoration(labelText: 'Status'),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                            DropdownMenuItem(value: 'pending', child: Text('Pending')),
                            DropdownMenuItem(value: 'approved', child: Text('Approved')),
                            DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                          ],
                          onChanged: (v) => setState(() => _filterStatus = v ?? 'all'),
                        ),
                      ),
                    ],
                  ),
                ),

                if (filtered.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text("No verification requests match the filters."),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final r = filtered[index];
                        final user = r["user"];

                        // choose a small thumbnail (selfie > id > event proof)
                        final thumb = (r["selfieUrl"] ?? r["selfie_url"]) ??
                            (r["idDocumentUrl"] ?? r["id_document_url"]) ??
                            (r["eventProofUrl"] ?? r["event_proof_url"]);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            onTap: () => _showDetailsModal(r),
                            leading: thumb != null
                                ? SizedBox(
                                    width: 56,
                                    height: 56,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.network(
                                        thumb,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                                      ),
                                    ),
                                  )
                                : const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(user["name"] ?? "Unnamed"),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user["email"] ?? ""),
                                const SizedBox(height: 4),
                                Text("Role: ${r["role"]} • Status: ${r["status"]}"),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.open_in_new),
                              onPressed: () => _showDetailsModal(r),
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
  
  // Helper to build tappable preview images that open full-screen
  Widget _buildPreviewImage(String url) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            child: InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
              ),
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
        ),
      ),
    );
  }
}
