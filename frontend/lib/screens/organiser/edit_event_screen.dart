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

  @override
  void initState() {
    super.initState();
    final e = widget.event;

    titleController.text = e["title"] ?? "";
    descriptionController.text = e["description"] ?? "";
    locationController.text = e["location"] ?? "";
    volunteersController.text =
        e["volunteers_required"]?.toString() ?? "";

    eventType = e["event_type"] ?? "unpaid";
    if (eventType == "paid") {
      paymentController.text =
          e["payment_per_day"]?.toString() ?? "";
    }

    if (e["event_date"] != null) {
      final d = DateTime.parse(e["event_date"]);
      eventStartDate = d;
      eventEndDate = d;
    }

    if (e["application_deadline"] != null) {
      applicationDeadline = DateTime.parse(e["application_deadline"]);
    }

    existingBanner = e["banner_url"];
  }

  String _fmtDate(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
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

  Future<void> handleUpdateEvent() async {
    if (titleController.text.trim().isEmpty) {
      _toast("Event title is required");
      return;
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
  eventDate: _fmtDate(eventStartDate ?? DateTime.now()),
  applicationDeadline: _fmtDate(applicationDeadline ?? DateTime.now()),
  volunteersRequired: int.parse(volunteersController.text),
  eventType: eventType,
  paymentPerDay:
      eventType == "paid" ? double.parse(paymentController.text) : null,
  bannerUrl: bannerUrl,
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

          _sectionCard("Event Banner", [
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
                                fit: BoxFit.cover)
                            : Image.file(File(bannerImage!.path),
                                fit: BoxFit.cover),
                      )
                    : existingBanner != null
                        ? Image.network(existingBanner!, fit: BoxFit.cover)
                        : const Center(child: Text("Upload Event Banner")),
              ),
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
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
}
