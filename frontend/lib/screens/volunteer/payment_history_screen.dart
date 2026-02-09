import 'package:flutter/material.dart';

class PaymentHistoryScreen extends StatelessWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final payments = <Map<String, String>>[];

    return Scaffold(
      appBar: AppBar(title: const Text("Payment History")),
      body: payments.isEmpty
          ? const Center(child: Text("No payment history yet"))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: payments.length,
              itemBuilder: (context, index) {
                final p = payments[index];
                return Card(
                  child: ListTile(
                    title: Text(p["event"] ?? ""),
                    subtitle: Text(p["amount"] ?? ""),
                    trailing: Text(
                      p["status"] ?? "",
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

