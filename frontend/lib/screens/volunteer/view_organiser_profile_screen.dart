import 'package:flutter/material.dart';

class ViewOrganiserProfileScreen extends StatelessWidget {
  final int organiserId;

  const ViewOrganiserProfileScreen({
    super.key,
    required this.organiserId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text("Organiser Profile"),
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E6BE6), Color(0xFF2ECC71)],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _header(),
            const SizedBox(height: 16),
            _about(),
            const SizedBox(height: 16),
            _stats(),
            const SizedBox(height: 16),
            _reviews(),
            const SizedBox(height: 16),
            _connectCard(),
            
          ],
        ),
      ),
    );
  }

  // ================= HEADER =================
  Widget _header() {
    return _card(
      child: Column(
        children: const [
          CircleAvatar(
            radius: 42,
            backgroundColor: Colors.green,
            child: Icon(Icons.eco, size: 42, color: Colors.white),
          ),
          SizedBox(height: 12),
          Text(
            "Green Earth Foundation",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text("⭐ 4.6 rating", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  // ================= ABOUT =================
  Widget _about() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            "About Organisation",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            "Green Earth Foundation is a non-profit organisation focused on "
            "environmental protection through clean-up drives, tree plantations, "
            "and sustainability awareness programs.",
            style: TextStyle(height: 1.5),
          ),
        ],
      ),
    );
  }

  // ================= STATS =================
  Widget _stats() {
    return _card(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const [
          _Stat("120+", "Volunteers"),
          _Stat("35", "Events"),
          _Stat("4.6", "Rating"),
        ],
      ),
    );
  }

  Widget _connectCard() {
  return _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Connect with Us",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 4),

        const Text(
          "Follow or visit to learn more about their work",
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),

        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _socialIcon(Icons.language, "Website"),
            _socialIcon(Icons.camera_alt, "Instagram"),
            _socialIcon(Icons.facebook, "Facebook"),
            _socialIcon(Icons.link, "LinkedIn"),
          ],
        ),

        const SizedBox(height: 16),
        const Divider(height: 1),

        const SizedBox(height: 12),

        Row(
          children: const [
            Icon(Icons.email, size: 18, color: Colors.grey),
            SizedBox(width: 8),
            Text(
              "contact@greenearth.org",
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ],
    ),
  );
}



Widget _socialIcon(IconData icon, String label) {
  return Column(
    children: [
      InkWell(
        onTap: () {
          debugPrint("$label clicked");
        },
        borderRadius: BorderRadius.circular(50),
        child: CircleAvatar(
          radius: 26,
          backgroundColor: Colors.green.withOpacity(0.15),
          child: Icon(icon, color: Colors.green),
        ),
      ),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
}



  // ================= REVIEWS =================
  Widget _reviews() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Volunteer Reviews",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _review(
            "Very well organised and safe volunteering experience.",
            "Aditi",
          ),
          const SizedBox(height: 12),
          _review(
            "Clear instructions and friendly coordinators.",
            "Rahul",
          ),
        ],
      ),
    );
  }

  Widget _review(String text, String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.star, size: 16, color: Colors.amber),
            Icon(Icons.star, size: 16, color: Colors.amber),
            Icon(Icons.star, size: 16, color: Colors.amber),
            Icon(Icons.star, size: 16, color: Colors.amber),
            Icon(Icons.star, size: 16, color: Colors.amber),
          ],
        ),
        const SizedBox(height: 6),
        Text(text, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          "— $name",
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  // ================= CARD =================
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: child,
    );
  }
}

// ================= STAT =================
class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const _Stat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}
