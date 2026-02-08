import 'package:flutter/material.dart';

class OrganiserActivityScreen extends StatefulWidget {
  const OrganiserActivityScreen({super.key});

  @override
  State<OrganiserActivityScreen> createState() =>
      _OrganiserActivityScreenState();
}

class _OrganiserActivityScreenState extends State<OrganiserActivityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: Column(
        children: [
          // 🔷 HEADER
          Container(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF22C55E)],
              ),
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(40),
              ),
            ),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.business, size: 36),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Your Organisation",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // 📑 TABS
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  tabs: const [
                    Tab(text: "Volunteers"),
                    Tab(text: "Events"),
                    Tab(text: "Rating"),
                    Tab(text: "Reviews"),
                  ],
                ),
              ],
            ),
          ),

          // 🧩 TAB CONTENT
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                // VOLUNTEERS
                Center(child: Text("Your volunteers will appear here")),

                // EVENTS
                Center(child: Text("Your events will appear here")),

                // RATING
                Center(
                  child: Text(
                    "Your organisation rating",
                    style: TextStyle(fontSize: 16),
                  ),
                ),

                // REVIEWS
                Center(child: Text("Volunteer reviews will appear here")),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
