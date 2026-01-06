import 'package:flutter/material.dart';
import 'create_event_screen.dart';
import 'my_events_screen.dart';

class OrganiserDashboard extends StatelessWidget {
  const OrganiserDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Organiser Dashboard"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateEventScreen(),
                    ),
                  );
                },
                child: const Text("Create Event"),
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyEventsScreen(),
                    ),
                  );
                },
                child: const Text("My Events"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
