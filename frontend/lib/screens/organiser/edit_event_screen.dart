import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/event_service.dart';

class EditEventScreen extends StatefulWidget {
  final Map event;

  const EditEventScreen({super.key, required this.event});

  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final locationController = TextEditingController();
  final volunteersController = TextEditingController();
  final paymentController = TextEditingController();
  final responsibilityController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  XFile? bannerImage;
  String? existingBanner;

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

  @override
  void initState() {
    super.initState();
    final e = widget.event;

    titleController.text = e["title"] ?? "";
    descriptionController.text = e["description"] ?? "";
    locationController.text = e["location"] ?? "";
    volunteersController.text = e["volunteers_required"]?.toString() ?? "";

    eventType = e["event_type"] ?? "unpaid";
    if (eventType == "paid") {
      paymentController.text = e["payment_per_day"]?.toString() ?? "";
    }

    eventStartDate = _parseDate(e["event_date"]);
    eventEndDate = _parseDate(e["end_date"]) ?? eventStartDate;
    applicationDeadline = _parseDate(e["application_deadline"]);
    eventStartTime = _parseTime(e["start_time"]);
    eventEndTime = _parseTime(e["end_time"]);

    selectedCategories
      ..clear()
      ..addAll(
        (e["categories"] as List?)
                ?.map((item) => item.toString())
                .where((item) => item.isNotEmpty) ??
            const [],
      );

    responsibilities
      ..clear()
      ..addAll(
        (e["responsibilities"] as List?)
                ?.map((item) => item.toString())
                .where((item) => item.isNotEmpty) ??
            const [],
      );

    existingBanner = e["banner_url"]?.toString();
  }

  String _fmtDate(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  String _fmtTime(TimeOfDay t) =>
      "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00";

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  TimeOfDay? _parseTime(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    final parts = text.split(":");
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    final safeHour = hour < 0 ? 0 : (hour > 23 ? 23 : hour);
    final safeMinute = minute < 0 ? 0 : (minute > 59 ? 59 : minute);
    return TimeOfDay(hour: safeHour, minute: safeMinute);
  }

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

  Future<void> handleUpdateEvent() async {
    if (titleController.text.trim().isEmpty) {
      _toast("Event title is required");
      return;
    }
    if (locationController.text.trim().isEmpty) {
      _toast("Location is required");
      return;
    }
    if (descriptionController.text.trim().isEmpty) {
      _toast("Description is required");
      return;
    }
    if (_parseVolunteers() == null) {
      _toast("Enter valid volunteers required");
      return;
    }
    if (eventStartDate == null || eventEndDate == null) {
      _toast("Select event start and end dates");
      return;
    }
    if (eventStartTime == null || eventEndTime == null) {
      _toast("Select event start and end time");
      return;
    }
    if (applicationDeadline == null) {
      _toast("Select application deadline");
      return;
    }
    if (selectedCategories.isEmpty) {
      _toast("Select at least one category");
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
      String bannerUrl = existingBanner ?? "";

      if (bannerImage != null) {
        bannerUrl = await EventService.uploadImage(bannerImage!);
      }

      final success = await EventService.updateEvent(
        id: widget.event["id"],
        title: titleController.text.trim(),
        description: descriptionController.text.trim(),
        location: locationController.text.trim(),
        eventDate: _fmtDate(eventStartDate!),
        endDate: _fmtDate(eventEndDate!),
        applicationDeadline: _fmtDate(applicationDeadline!),
        volunteersRequired: _parseVolunteers()!,
        eventType: eventType,
        paymentPerDay:
            eventType == "paid" ? double.parse(paymentController.text) : null,
        bannerUrl: bannerUrl,
        categories: selectedCategories,
        responsibilities: responsibilities,
        startTime: _fmtTime(eventStartTime!),
        endTime: _fmtTime(eventEndTime!),
      );

      if (success && mounted) Navigator.pop(context, true);
    } catch (e) {
      _toast("Update failed: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Event"),
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
                child: bannerImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: kIsWeb
                            ? Image.network(bannerImage!.path,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.broken_image)))
                            : Image.file(File(bannerImage!.path),
                                fit: BoxFit.cover),
                      )
                    : existingBanner != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(existingBanner!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.broken_image))),
                          )
                        : const Center(
                            child: Text("Upload Event Banner (Optional)")),
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
          loading ? const CircularProgressIndicator() : _submitButton(),
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
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _submitButton() => InkWell(
        onTap: handleUpdateEvent,
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
            child: Text("Update Event",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
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
      Icons.calendar_today,
      value == null ? title : _fmtDate(value),
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
