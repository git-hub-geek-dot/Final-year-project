import 'package:flutter/material.dart';

class PaymentHistoryScreen extends StatelessWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final payments = [
      {"event": "Park Cleanup", "amount": "₹500", "status": "Completed"},
      {"event": "Marathon Support", "amount": "₹1,200", "status": "Completed"},
      {"event": "Food Drive", "amount": "₹800", "status": "Pending"},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Payment History")),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: payments.length,
        itemBuilder: (context, index) {
          final p = payments[index];
          return Card(
            child: ListTile(
              title: Text(p["event"]!),
              subtitle: Text(p["amount"]!),
              trailing: Text(
                p["status"]!,
                style: TextStyle(
                  color: p["status"] == "Completed"
                      ? Colors.green
                      : Colors.orange,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

