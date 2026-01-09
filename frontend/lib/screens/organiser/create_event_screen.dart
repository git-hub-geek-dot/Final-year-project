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

  DateTime? eventStartDate;
  DateTime? eventEndDate;
  DateTime? applicationDeadline;

  TimeOfDay? eventStartTime;
  TimeOfDay? eventEndTime;

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

  Future<void> pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        isStart ? eventStartDate = picked : eventEndDate = picked;
      });
    }
  }

  Future<void> pickTime(bool isStart) async {
    final picked =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) {
      setState(() {
        isStart ? eventStartTime = picked : eventEndTime = picked;
      });
    }
  }

  Future<void> pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => applicationDeadline = picked);
    }
  }

  Future<void> pickBannerImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => bannerImage = image);
  }

  Future<void> handleCreateEvent() async {
    if (titleController.text.isEmpty ||
        locationController.text.isEmpty ||
        descriptionController.text.isEmpty ||
        volunteersController.text.isEmpty ||
        eventStartDate == null ||
        eventEndDate == null ||
        eventStartTime == null ||
        eventEndTime == null ||
        applicationDeadline == null ||
        bannerImage == null ||
        selectedCategories.isEmpty) {
      _toast("Please fill all required fields");
      return;
    }

    if (eventEndDate!.isBefore(eventStartDate!)) {
      _toast("End date must be after start date");
      return;
    }

    if (eventType == "paid") {
      final pay = double.tryParse(paymentController.text);
      if (pay == null || pay <= 0) {
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
            "${eventStartDate!.year}-${eventStartDate!.month.toString().padLeft(2, '0')}-${eventStartDate!.day.toString().padLeft(2, '0')}",
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
            gradient:
                LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF22C55E)]),
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

            // 📅 START & END DATE (SIDE BY SIDE)
            Row(
              children: [
                Expanded(
                  child: _dateTile(
                      "Start Date", eventStartDate, () => pickDate(true)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _dateTile(
                      "End Date", eventEndDate, () => pickDate(false)),
                ),
              ],
            ),

            // ⏰ START & END TIME (SIDE BY SIDE)
            Row(
              children: [
                Expanded(
                  child: _timeTile(
                      "Start Time", eventStartTime, () => pickTime(true)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _timeTile(
                      "End Time", eventEndTime, () => pickTime(false)),
                ),
              ],
            ),

            _dateTile(
                "Application Deadline", applicationDeadline, pickDeadline),

            const SizedBox(height: 14),

            // 🖼 EVENT BANNER
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
                colors: [Color(0xFF3B82F6), Color(0xFF22C55E)]),
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Center(
            child: Text(
              "Create Event",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
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
    return _tile(
      Icons.calendar_today_outlined,
      value == null
          ? title
          : "${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}",
      onTap,
    );
  }

  Widget _timeTile(String title, TimeOfDay? value, VoidCallback onTap) {
    return _tile(
      Icons.access_time,
      value == null ? title : value.format(context),
      onTap,
    );
  }

  Widget _tile(IconData icon, String text, VoidCallback onTap) {
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
              Icon(icon),
              const SizedBox(width: 12),
              Text(text),
            ],
          ),
        ),
      ),
    );
  }
}
