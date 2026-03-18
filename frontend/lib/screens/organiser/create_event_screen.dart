import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../localization/localization_extensions.dart';
import '../../services/event_service.dart';
import '../../services/verification_service.dart';
import '../../utils/ist_date_time.dart';
import '../../widgets/organiser_bottom_nav.dart';
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
  DateTime? paymentClearanceDate;
  TimeOfDay? eventStartTime;
  TimeOfDay? eventEndTime;

  bool loading = false;
  String eventType = "unpaid";
  String paymentRateType = "per_day";

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
  final List<Map<String, dynamic>> dailySchedules = [];

  String _fmtDate(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  String _fmtTime(TimeOfDay t) =>
      "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00";

  int? _parseVolunteers() {
    final text = volunteersController.text.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  void _setEventType(String value) {
    setState(() {
      eventType = value;
      if (value != "paid") {
        paymentController.clear();
        paymentClearanceDate = null;
        paymentRateType = "per_day";
      }
    });
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> _ensureVerifiedOrganiser() async {
    final status = (await VerificationService.getStatus())?.toLowerCase();

    if (status == "approved") {
      return true;
    }

    String message;
    switch (status) {
      case "pending":
        message = context.tr(
          "Your verification is under review. You can create events after approval.",
        );
        break;
      case "rejected":
        message = context.tr(
          "Your verification was rejected. Please submit verification again to create events.",
        );
        break;
      case "not_requested":
        message = context.tr("You need to be verified before creating events.");
        break;
      default:
        message = context.tr(
          "Unable to verify your account right now. Please try again.",
        );
        break;
    }

    _toast(message);
    return false;
  }

  Future<void> pickDate(bool isStart) async {
    final today = IstDateTime.startOfDay(IstDateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          eventStartDate = picked;
          return;
        }

        eventEndDate = picked;
        if (paymentClearanceDate != null &&
            paymentClearanceDate!.isBefore(picked)) {
          paymentClearanceDate = null;
        }
      });
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
    final today = IstDateTime.startOfDay(IstDateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => applicationDeadline = picked);
  }

  Future<void> pickPaymentClearanceDate() async {
    final today = IstDateTime.startOfDay(IstDateTime.now());
    final firstDate =
        eventEndDate != null && eventEndDate!.isAfter(today) ? eventEndDate! : today;
    final initialDate = paymentClearanceDate != null &&
            !paymentClearanceDate!.isBefore(firstDate)
        ? paymentClearanceDate!
        : firstDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => paymentClearanceDate = picked);
    }
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

  void _generateDailySchedules() {
    if (eventStartDate == null || eventEndDate == null) {
      _toast(context.tr("Select start and end dates first"));
      return;
    }

    setState(() {
      dailySchedules.clear();

      DateTime current = eventStartDate!;
      int dayIndex = 0;

      while (current.isBefore(eventEndDate!) ||
          current.isAtSameMomentAs(eventEndDate!)) {
        dayIndex++;
        dailySchedules.add({
          'date': _fmtDate(current),
          'start_time':
              eventStartTime != null ? _fmtTime(eventStartTime!) : '09:00:00',
          'end_time':
              eventEndTime != null ? _fmtTime(eventEndTime!) : '17:00:00',
          'dayNumber': dayIndex,
        });

        current = current.add(const Duration(days: 1));
      }
    });
  }

  void _removeScheduleDay(int index) {
    setState(() {
      dailySchedules.removeAt(index);
      // Re-number remaining days
      for (int i = index; i < dailySchedules.length; i++) {
        dailySchedules[i]['dayNumber'] = i + 1;
      }
    });
  }

  Future<void> _editScheduleTime(int index, bool isStartTime) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          dailySchedules[index]['start_time'] = _fmtTime(picked);
        } else {
          dailySchedules[index]['end_time'] = _fmtTime(picked);
        }
      });
    }
  }

  Future<void> _submitEvent({required bool saveAsDraft}) async {
    final canCreate = await _ensureVerifiedOrganiser();
    if (!canCreate) return;

    if (titleController.text.trim().isEmpty) {
      _toast(context.tr("Event title is required"));
      return;
    }

    if (!saveAsDraft && locationController.text.trim().isEmpty) {
      _toast(context.tr("Location is required"));
      return;
    }
    if (!saveAsDraft && descriptionController.text.trim().isEmpty) {
      _toast(context.tr("Description is required"));
      return;
    }
    if (!saveAsDraft && _parseVolunteers() == null) {
      _toast(context.tr("Enter valid volunteers required"));
      return;
    }
    if (!saveAsDraft && (eventStartDate == null || eventEndDate == null)) {
      _toast(context.tr("Select event start and end dates"));
      return;
    }
    if (!saveAsDraft && (eventStartTime == null || eventEndTime == null)) {
      _toast(context.tr("Select event start and end time"));
      return;
    }
    if (!saveAsDraft && applicationDeadline == null) {
      _toast(context.tr("Select application deadline"));
      return;
    }
    if (!saveAsDraft && selectedCategories.isEmpty) {
      _toast(context.tr("Select at least one category"));
      return;
    }

    if (!saveAsDraft && eventType == "paid") {
      final amount = double.tryParse(paymentController.text);
      if (amount == null || amount <= 0) {
        _toast(context.tr("Enter valid payment amount"));
        return;
      }
      if (paymentClearanceDate == null) {
        _toast(context.tr("Select payment clearance date"));
        return;
      }
      if (eventEndDate != null && paymentClearanceDate!.isBefore(eventEndDate!)) {
        _toast(
          context.tr("Payment clearance date cannot be before the event end date"),
        );
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
        paymentAmount: eventType == "paid"
            ? double.tryParse(paymentController.text)
            : null,
        paymentRateType: eventType == "paid" ? paymentRateType : null,
        paymentClearanceDate: eventType == "paid" && paymentClearanceDate != null
            ? _fmtDate(paymentClearanceDate!)
            : null,
        bannerUrl: bannerUrl,
        categories: selectedCategories,
        responsibilities: responsibilities,
        startTime: eventStartTime == null ? null : _fmtTime(eventStartTime!),
        endTime: eventEndTime == null ? null : _fmtTime(eventEndTime!),
        isDraft: saveAsDraft,
        dailySchedules: dailySchedules.isNotEmpty ? dailySchedules : null,
      );

      if (success && mounted) {
        _toast(
          saveAsDraft ? context.tr("Draft saved") : context.tr("Event created"),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MyEventsScreen()),
        );
      } else if (mounted) {
        _toast(
          saveAsDraft
              ? context.tr("Failed to save draft")
              : context.tr("Failed to create event"),
        );
      }
    } catch (e) {
      _toast(context.tr("Error: {error}", args: {"error": e.toString()}));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr("Create Event")),
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
          _sectionCard(context.tr("Basic Details"), [
            _input(context.tr("Event Title"), titleController),
            _input(context.tr("Location"), locationController),
            _input(context.tr("Description"), descriptionController, maxLines: 4),
            _input(context.tr("Volunteers Required"), volunteersController,
                keyboardType: TextInputType.number),
          ]),
          _sectionCard(context.tr("Schedule"), [
            Row(children: [
              Expanded(
                child: _dateTile(
                    context.tr("Start Date"), eventStartDate, () => pickDate(true)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child:
                    _dateTile(context.tr("End Date"), eventEndDate, () => pickDate(false)),
              ),
            ]),
            Row(children: [
              Expanded(
                child: _timeTile(
                    context.tr("Start Time"), eventStartTime, () => pickTime(true)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child:
                    _timeTile(context.tr("End Time"), eventEndTime, () => pickTime(false)),
              ),
            ]),
            _dateTile(
                context.tr("Application Deadline"), applicationDeadline, pickDeadline),
          ]),
          // Daily Schedules Section for Multi-day Events
          if (eventStartDate != null &&
              eventEndDate != null &&
              eventStartDate != eventEndDate)
            _sectionCard(context.tr("Daily Schedules"), [
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: ElevatedButton.icon(
                  onPressed: _generateDailySchedules,
                  icon: const Icon(Icons.add),
                  label: Text(context.tr("Generate schedules from dates")),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              if (dailySchedules.isNotEmpty)
                Column(
                  children: dailySchedules.asMap().entries.map((entry) {
                    int index = entry.key;
                    Map<String, dynamic> schedule = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  context.tr(
                                    "Day {number}: {date}",
                                    args: {
                                      "number": schedule['dayNumber'].toString(),
                                      "date": schedule['date'].toString(),
                                    },
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                if (dailySchedules.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () => _removeScheduleDay(index),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _editScheduleTime(index, true),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        context.tr(
                                          "Start: {time}",
                                          args: {
                                            "time":
                                                schedule['start_time'].substring(0, 5),
                                          },
                                        ),
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InkWell(
                                    onTap: () =>
                                        _editScheduleTime(index, false),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        context.tr(
                                          "End: {time}",
                                          args: {
                                            "time":
                                                schedule['end_time'].substring(0, 5),
                                          },
                                        ),
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ]),
          _sectionCard(context.tr("Event Banner (Optional)"), [
            InkWell(
              onTap: pickBannerImage,
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey),
                ),
                child: bannerImage == null
                    ? Center(
                        child: Text(context.tr("Upload Event Banner (Optional)")))
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: kIsWeb
                            ? Image.network(
                                bannerImage!.path,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.broken_image),
                                ),
                              )
                            : Image.file(
                                File(bannerImage!.path),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.broken_image),
                                ),
                              ),
                      ),
              ),
            ),
          ]),
          _sectionCard(context.tr("Event Type"), [
            RadioListTile(
              value: "paid",
              groupValue: eventType,
              title: Text(context.tr("Paid")),
              onChanged: (v) => _setEventType(v!),
            ),
            RadioListTile(
              value: "unpaid",
              groupValue: eventType,
              title: Text(context.tr("Unpaid")),
              onChanged: (v) => _setEventType(v!),
            ),
            if (eventType == "paid") ...[
              _input(context.tr("Payment Amount"), paymentController,
                  keyboardType: TextInputType.number),
              _paymentRateField(),
              _dateTile(
                context.tr("Payment Clearance Date"),
                paymentClearanceDate,
                pickPaymentClearanceDate,
              ),
            ],
          ]),
          _sectionCard(context.tr("Responsibilities"), [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: responsibilityController,
                    decoration: InputDecoration(
                      hintText: context.tr("Add responsibility"),
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
              Text(context.tr("No responsibilities added")),
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
          _sectionCard(context.tr("Categories"), [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((c) {
                final selected = selectedCategories.contains(c);
                return ChoiceChip(
                  label: Text(context.tr(c)),
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
      bottomNavigationBar: const OrganiserBottomNav(
        currentIndex: 0,
        isRootScreen: false,
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
              child: Text(context.tr("Save Draft")),
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
                child: Center(
                  child: Text(
                    context.tr("Create Event"),
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

  Widget _paymentRateField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: paymentRateType,
        decoration: InputDecoration(
          labelText: context.tr("Payment Rate"),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        items: [
          DropdownMenuItem(
            value: "per_day",
            child: Text(context.tr("Per Day")),
          ),
          DropdownMenuItem(
            value: "per_hour",
            child: Text(context.tr("Per Hour")),
          ),
          DropdownMenuItem(
            value: "fixed",
            child: Text(context.tr("Fixed Amount")),
          ),
        ],
        onChanged: (value) {
          if (value == null) return;
          setState(() => paymentRateType = value);
        },
        selectedItemBuilder: (context) => [
          Text(this.context.tr("Per Day")),
          Text(this.context.tr("Per Hour")),
          Text(this.context.tr("Fixed Amount")),
        ],
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
