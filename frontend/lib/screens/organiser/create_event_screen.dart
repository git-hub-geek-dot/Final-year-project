import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import '../../services/event_service.dart';
import 'my_events_screen.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final locationController = TextEditingController();
  final volunteersController = TextEditingController();
  final paymentController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  XFile? bannerImage;

  DateTime? eventDate;
  DateTime? applicationDeadline;

  bool loading = false;
  String eventType = "unpaid";

  final List<String> categories = [
    "All",
    "Education",
    "Healthcare",
    "Environment",
    "Animals",
    "Community",
    "Charity",
    "Sports & Fitness",
    "Arts & Culture",
    "Technology",
    "Skill Development",
    "Social Awareness",
    "Disaster Relief",
    "Women & Child Welfare",
    "Senior Citizen Support",
    "Cleanliness Drives",
    "Food & Nutrition",
    "Fundraising",
    "Reception & Party Management",
    "Other",
  ];

  final List<String> selectedCategories = [];

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    locationController.dispose();
    volunteersController.dispose();
    paymentController.dispose();
    super.dispose();
  }

  Future<void> pickDate(bool isDeadline) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        isDeadline ? applicationDeadline = picked : eventDate = picked;
      });
    }
  }

  Future<void> pickBannerImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => bannerImage = image);
    }
  }

  Future<void> handleCreateEvent() async {
    if (titleController.text.isEmpty ||
        locationController.text.isEmpty ||
        descriptionController.text.isEmpty ||
        volunteersController.text.isEmpty ||
        eventDate == null ||
        applicationDeadline == null ||
        bannerImage == null ||
        selectedCategories.isEmpty) {
      _toast("Please fill all required fields");
      return;
    }

    if (applicationDeadline!.isAfter(eventDate!)) {
      _toast("Application deadline must be before event date");
      return;
    }

    if (eventType == "paid") {
      final payment = double.tryParse(paymentController.text);
      if (payment == null || payment <= 0) {
        _toast("Enter valid payment per day");
        return;
      }
    }

    setState(() => loading = true);

    try {
      final success = await EventService.createEvent(
        title: titleController.text.trim(),
        description: descriptionController.text.trim(),
        location: locationController.text.trim(),
        eventDate:
            "${eventDate!.year}-${eventDate!.month.toString().padLeft(2, '0')}-${eventDate!.day.toString().padLeft(2, '0')}",
      );

      if (success && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MyEventsScreen()),
        );
      }
    } catch (e) {
      _toast("Error: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Event"),
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF22C55E)],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _input("Event Title", titleController),
            _input("Location", locationController),
            _input("Description", descriptionController, maxLines: 4),
            _input("Volunteers Required", volunteersController,
                keyboardType: TextInputType.number),

            _dateTile("Event Date", eventDate, () => pickDate(false)),
            _dateTile(
                "Application Deadline", applicationDeadline, () => pickDate(true)),

            // 🖼 Banner
            InkWell(
              onTap: pickBannerImage,
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey),
                ),
                child: bannerImage == null
                    ? const Center(child: Text("Upload Event Banner"))
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: kIsWeb
                            ? Image.network(bannerImage!.path,
                                fit: BoxFit.cover)
                            : Image.file(File(bannerImage!.path),
                                fit: BoxFit.cover),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // 💰 Event Type
            const Text("Event Type",
                style: TextStyle(fontWeight: FontWeight.bold)),
            RadioListTile(
              value: "paid",
              groupValue: eventType,
              title: const Text("Paid"),
              onChanged: (v) => setState(() => eventType = v!),
            ),
            RadioListTile(
              value: "unpaid",
              groupValue: eventType,
              title: const Text("Unpaid"),
              onChanged: (v) => setState(() => eventType = v!),
            ),

            if (eventType == "paid")
              _input("Payment per day (₹)", paymentController,
                  keyboardType: TextInputType.number),

            const SizedBox(height: 16),

            // 🏷 Categories
            const Text("Categories (Select at least one)",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              children: categories.map((tag) {
                final selected = selectedCategories.contains(tag);
                return ChoiceChip(
                  label: Text(tag),
                  selected: selected,
                  selectedColor: const Color(0xFF22C55E),
                  labelStyle:
                      TextStyle(color: selected ? Colors.white : Colors.black),
                  onSelected: (val) {
                    setState(() {
                      if (tag == "All") {
                        selectedCategories
                          ..clear()
                          ..add("All");
                      } else {
                        selectedCategories.remove("All");
                        val
                            ? selectedCategories.add(tag)
                            : selectedCategories.remove(tag);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 30),

            loading
                ? const Center(child: CircularProgressIndicator())
                : _submitButton(),
          ],
        ),
      ),
    );
  }

  Widget _submitButton() => InkWell(
        onTap: handleCreateEvent,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF22C55E)],
            ),
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Center(
            child: Text("Create Event",
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      );

  Widget _input(String hint, TextEditingController c,
      {int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _dateTile(String title, DateTime? value, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined),
              const SizedBox(width: 12),
              Text(value == null
                  ? title
                  : "${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}"),
            ],
          ),
        ),
      ),
    );
  }
}
