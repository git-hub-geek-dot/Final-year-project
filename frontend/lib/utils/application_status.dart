import 'package:flutter/material.dart';

String normalizeApplicationStatus(dynamic raw) {
  final status = (raw ?? "pending").toString().trim().toLowerCase();
  if (status.isEmpty) return "pending";
  if (status == "accepted") return "approved";
  return status;
}

String applicationStatusLabel(dynamic raw) {
  switch (normalizeApplicationStatus(raw)) {
    case "approved":
      return "Approved";
    case "waitlisted":
      return "Waitlisted";
    case "rejected":
      return "Rejected";
    case "cancelled":
      return "Cancelled";
    case "completed":
      return "Completed";
    case "pending":
      return "Pending";
    default:
      return (raw ?? "Pending").toString();
  }
}

Color applicationStatusColor(dynamic raw) {
  switch (normalizeApplicationStatus(raw)) {
    case "approved":
      return Colors.green;
    case "waitlisted":
      return Colors.amber.shade700;
    case "rejected":
      return Colors.red;
    case "cancelled":
      return Colors.red;
    case "completed":
      return Colors.blueGrey;
    case "pending":
      return Colors.orange;
    default:
      return Colors.blueGrey;
  }
}

IconData applicationStatusIcon(dynamic raw) {
  switch (normalizeApplicationStatus(raw)) {
    case "approved":
      return Icons.check_circle;
    case "waitlisted":
      return Icons.hourglass_bottom;
    case "rejected":
      return Icons.block;
    case "cancelled":
      return Icons.cancel;
    case "completed":
      return Icons.task_alt;
    case "pending":
      return Icons.hourglass_top;
    default:
      return Icons.info_outline;
  }
}

bool isApprovedApplicationStatus(dynamic raw) {
  return normalizeApplicationStatus(raw) == "approved";
}

bool isActionableReviewStatus(dynamic raw) {
  final status = normalizeApplicationStatus(raw);
  return status == "pending" || status == "waitlisted";
}
