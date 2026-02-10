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
  final responsibilityController = TextEditingController();

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
  final List<String> responsibilities = [];

  String _fmtDate(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  String _fmtTime(TimeOfDay t) =>
      "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00";

  int? _parseVolunteers() {
    final text = volunteersController.text.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => isStart ? eventStartDate = picked : eventEndDate = picked);
    }
  }

  Future<void> pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => isStart ? eventStartTime = picked : eventEndTime = picked);
    }
  }

  Future<void> pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => applicationDeadline = picked);
  }

  Future<void> pickBannerImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => bannerImage = image);
  }

  void _addResponsibility() {
    final text = responsibilityController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      responsibilities.add(text);
      responsibilityController.clear();
    });
  }

  Future<void> _submitEvent({required bool saveAsDraft}) async {
    if (titleController.text.trim().isEmpty) {
      _toast("Event title is required");
      return;
    }

    if (!saveAsDraft && locationController.text.trim().isEmpty) {
      _toast("Location is required");
      return;
    }
    if (!saveAsDraft && descriptionController.text.trim().isEmpty) {
      _toast("Description is required");
      return;
    }
    if (!saveAsDraft && _parseVolunteers() == null) {
      _toast("Enter valid volunteers required");
      return;
    }
    if (!saveAsDraft && (eventStartDate == null || eventEndDate == null)) {
      _toast("Select event start and end dates");
      return;
    }
    if (!saveAsDraft && (eventStartTime == null || eventEndTime == null)) {
      _toast("Select event start and end time");
      return;
    }
    if (!saveAsDraft && applicationDeadline == null) {
      _toast("Select application deadline");
      return;
    }
    if (!saveAsDraft && selectedCategories.isEmpty) {
      _toast("Select at least one category");
      return;
    }

    if (!saveAsDraft && eventType == "paid") {
      final pay = double.tryParse(paymentController.text);
      if (pay == null || pay <= 0) {
        _toast("Enter valid payment per day");
        return;
      }
    }

    setState(() => loading = true);

    try {
      String? bannerUrl;
      if (bannerImage != null) {
        bannerUrl = await EventService.uploadImage(bannerImage!);
      }

      final success = await EventService.createEvent(
        title: titleController.text.trim(),
        description: descriptionController.text.trim().isEmpty
            ? null
            : descriptionController.text.trim(),
        location: locationController.text.trim().isEmpty
            ? null
            : locationController.text.trim(),
        eventDate: eventStartDate == null ? null : _fmtDate(eventStartDate!),
        endDate: eventEndDate == null ? null : _fmtDate(eventEndDate!),
        applicationDeadline:
            applicationDeadline == null ? null : _fmtDate(applicationDeadline!),
        volunteersRequired: _parseVolunteers(),
        eventType: eventType,
        paymentPerDay: eventType == "paid"
            ? double.tryParse(paymentController.text)
            : null,
        bannerUrl: bannerUrl,
        categories: selectedCategories,
        responsibilities: responsibilities,
        startTime: eventStartTime == null ? null : _fmtTime(eventStartTime!),
        endTime: eventEndTime == null ? null : _fmtTime(eventEndTime!),
        isDraft: saveAsDraft,
      );

      if (success && mounted) {
        _toast(saveAsDraft ? "Draft saved" : "Event created");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MyEventsScreen()),
        );
      } else if (mounted) {
        _toast(saveAsDraft ? "Failed to save draft" : "Failed to create event");
      }
    } catch (e) {
      _toast("Error: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
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
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          _sectionCard("Basic Details", [
            _input("Event Title", titleController),
            _input("Location", locationController),
            _input("Description", descriptionController, maxLines: 4),
            _input("Volunteers Required", volunteersController,
                keyboardType: TextInputType.number),
          ]),
          _sectionCard("Schedule", [
            Row(children: [
              Expanded(
                child: _dateTile(
                    "Start Date", eventStartDate, () => pickDate(true)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child:
                    _dateTile("End Date", eventEndDate, () => pickDate(false)),
              ),
            ]),
            Row(children: [
              Expanded(
                child: _timeTile(
                    "Start Time", eventStartTime, () => pickTime(true)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child:
                    _timeTile("End Time", eventEndTime, () => pickTime(false)),
              ),
            ]),
            _dateTile(
                "Application Deadline", applicationDeadline, pickDeadline),
          ]),
          _sectionCard("Event Banner (Optional)", [
            InkWell(
              onTap: pickBannerImage,
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey),
                ),
                child: bannerImage == null
                    ? const Center(
                        child: Text("Upload Event Banner (Optional)"))
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: kIsWeb
                            ? Image.network(bannerImage!.path,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.broken_image)))
                            : Image.file(File(bannerImage!.path),
                                fit: BoxFit.cover),
                      ),
              ),
            ),
          ]),
          _sectionCard("Event Type", [
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
              _input("Payment per day", paymentController,
                  keyboardType: TextInputType.number),
          ]),
          _sectionCard("Responsibilities", [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: responsibilityController,
                    decoration: InputDecoration(
                      hintText: "Add responsibility",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: (_) => _addResponsibility(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addResponsibility,
                  icon: const Icon(Icons.add_circle, color: Colors.green),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (responsibilities.isEmpty)
              const Text("No responsibilities added"),
            if (responsibilities.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: responsibilities
                    .map(
                      (item) => Chip(
                        label: Text(item),
                        onDeleted: () {
                          setState(() => responsibilities.remove(item));
                        },
                      ),
                    )
                    .toList(),
              ),
          ]),
          _sectionCard("Categories", [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((c) {
                final selected = selectedCategories.contains(c);
                return ChoiceChip(
                  label: Text(c),
                  selected: selected,
                  selectedColor: const Color(0xFF22C55E),
                  labelStyle:
                      TextStyle(color: selected ? Colors.white : Colors.black),
                  onSelected: (v) {
                    setState(() {
                      v
                          ? selectedCategories.add(c)
                          : selectedCategories.remove(c);
                    });
                  },
                );
              }).toList(),
            ),
          ]),
          const SizedBox(height: 24),
          loading ? const CircularProgressIndicator() : _actionButtons(),
        ]),
      ),
    );
  }

  Widget _sectionCard(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 6),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...children,
      ]),
    );
  }

  Widget _actionButtons() => Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _submitEvent(saveAsDraft: true),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                side: const BorderSide(color: Color(0xFF3B82F6)),
              ),
              child: const Text("Save Draft"),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () => _submitEvent(saveAsDraft: false),
              child: Container(
                height: 56,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF22C55E)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Center(
                  child: Text(
                    "Create Event",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ],
      );

  Widget _input(String hint, TextEditingController c,
      {int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _dateTile(String title, DateTime? value, VoidCallback onTap) {
    return _tile(
        Icons.calendar_today, value == null ? title : _fmtDate(value), onTap);
  }

  Widget _timeTile(String title, TimeOfDay? value, VoidCallback onTap) {
    return _tile(Icons.access_time,
        value == null ? title : value.format(context), onTap);
  }

  Widget _tile(IconData icon, String text, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey),
          ),
          child: Row(children: [
            Icon(icon),
            const SizedBox(width: 12),
            Text(text),
          ]),
        ),
      ),
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    locationController.dispose();
    volunteersController.dispose();
    paymentController.dispose();
    responsibilityController.dispose();
    super.dispose();
  }
}
