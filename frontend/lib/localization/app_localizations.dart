import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static const supportedLocales = [
    Locale('en'),
    Locale('hi'),
  ];

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    _AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static AppLocalizations of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    return localizations ?? AppLocalizations(const Locale('en'));
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'App Language': 'App Language',
      'Choose Language': 'Choose Language',
      'English': 'English',
      'Hindi': 'Hindi',
      'Language': 'Language',
      'Volunteer': 'Volunteer',
      'Hi, {name}!': 'Hi, {name}!',
      'Find your next volunteer event': 'Find your next volunteer event',
      'My Ongoing Events': 'My Ongoing Events',
      'My Upcoming Events': 'My Upcoming Events',
      'Upcoming': 'Upcoming',
      'Ongoing': 'Ongoing',
      'No ongoing events yet': 'No ongoing events yet',
      'No upcoming events yet': 'No upcoming events yet',
      'View All': 'View All',
      'Recommended for You': 'Recommended for You',
      'No recommendations available': 'No recommendations available',
      'Event details not available': 'Event details not available',
      'Failed to open event details': 'Failed to open event details',
      'Pending Rating Reminder': 'Pending Rating Reminder',
      'Share your feedback for {event}.': 'Share your feedback for {event}.',
      '{count} completed events are waiting for your rating.':
          '{count} completed events are waiting for your rating.',
      'Rate now': 'Rate now',
      'View Details': 'View Details',
      '{filled}/{required} approved': '{filled}/{required} approved',
      'Pending': 'Pending',
      'Approved': 'Approved',
      'Rejected': 'Rejected',
      'Cancelled': 'Cancelled',
      'Apply': 'Apply',
      'Home': 'Home',
      'Events': 'Events',
      'Leaderboard': 'Leaderboard',
      'Profile': 'Profile',
      'event': 'event',
      'Failed to load events. Pull to refresh or tap Retry.':
          'Failed to load events. Pull to refresh or tap Retry.',
      'Your verification is under review. You can create events after approval.':
          'Your verification is under review. You can create events after approval.',
      'Your verification was rejected. Please submit verification again to create events.':
          'Your verification was rejected. Please submit verification again to create events.',
      'You need to be verified before creating events.':
          'You need to be verified before creating events.',
      'Unable to verify your account right now. Please try again.':
          'Unable to verify your account right now. Please try again.',
      'Create Event': 'Create Event',
      'All': 'All',
      'Completed': 'Completed',
      'Draft': 'Draft',
      'Retry': 'Retry',
      'All Events': 'All Events',
      'Ongoing Events': 'Ongoing Events',
      'Upcoming Events': 'Upcoming Events',
      'Completed Events': 'Completed Events',
      'Draft Events': 'Draft Events',
      'Cancelled Events': 'Cancelled Events',
      'No {title}': 'No {title}',
      'Organiser: {name}': 'Organiser: {name}',
      'Untitled': 'Untitled',
      'Location: {location}': 'Location: {location}',
      'N/A': 'N/A',
      'Date: {date}': 'Date: {date}',
      'No ratings yet': 'No ratings yet',
      'Review': 'Review',
      'Removed by admin': 'Removed by admin',
      'Not published': 'Not published',
      'Cancelled by organiser': 'Cancelled by organiser',
      'Starts today': 'Starts today',
      'Starts in {days}d': 'Starts in {days}d',
      'Deadline passed': 'Deadline passed',
      'Deadline soon': 'Deadline soon',
      'Approved: {accepted} / {required}': 'Approved: {accepted} / {required}',
      'Applicants: {raw} / {required}': 'Applicants: {raw} / {required}',
      'Draft not visible to volunteers': 'Draft not visible to volunteers',
      'Application deadline passed': 'Application deadline passed',
      'No applications yet': 'No applications yet',
      'Understaffed by {count}': 'Understaffed by {count}',
      'to': 'to',
    },
    'hi': {
      'App Language': 'ऐप भाषा',
      'Choose Language': 'भाषा चुनें',
      'English': 'अंग्रेज़ी',
      'Hindi': 'हिन्दी',
      'Language': 'भाषा',
      'Volunteer': 'स्वयंसेवक',
      'Hi, {name}!': 'नमस्ते, {name}!',
      'Find your next volunteer event': 'अपना अगला स्वयंसेवा कार्यक्रम खोजें',
      'My Ongoing Events': 'मेरे चल रहे कार्यक्रम',
      'My Upcoming Events': 'मेरे आगामी कार्यक्रम',
      'Upcoming': 'आगामी',
      'Ongoing': 'चल रहे',
      'No ongoing events yet': 'अभी कोई चल रहा कार्यक्रम नहीं है',
      'No upcoming events yet': 'अभी कोई आगामी कार्यक्रम नहीं है',
      'View All': 'सभी देखें',
      'Recommended for You': 'आपके लिए सुझाए गए',
      'No recommendations available': 'कोई सुझाव उपलब्ध नहीं',
      'Event details not available': 'कार्यक्रम का विवरण उपलब्ध नहीं',
      'Failed to open event details': 'कार्यक्रम का विवरण खोलने में विफल',
      'Pending Rating Reminder': 'रेटिंग लंबित है',
      'Share your feedback for {event}.': '{event} के लिए अपना फीडबैक दें।',
      '{count} completed events are waiting for your rating.':
          '{count} पूर्ण कार्यक्रम आपकी रेटिंग की प्रतीक्षा कर रहे हैं।',
      'Rate now': 'अभी रेट करें',
      'View Details': 'विवरण देखें',
      '{filled}/{required} approved': '{filled}/{required} स्वीकृत',
      'Pending': 'लंबित',
      'Approved': 'स्वीकृत',
      'Rejected': 'अस्वीकृत',
      'Cancelled': 'रद्द',
      'Apply': 'आवेदन करें',
      'Home': 'होम',
      'Events': 'कार्यक्रम',
      'Leaderboard': 'लीडरबोर्ड',
      'Profile': 'प्रोफ़ाइल',
      'event': 'कार्यक्रम',
      'Failed to load events. Pull to refresh or tap Retry.':
          'कार्यक्रम लोड नहीं हो पाए। रीफ़्रेश करने के लिए नीचे खींचें या पुनः प्रयास करें।',
      'Your verification is under review. You can create events after approval.':
          'आपका सत्यापन समीक्षा में है। स्वीकृति के बाद आप कार्यक्रम बना सकते हैं।',
      'Your verification was rejected. Please submit verification again to create events.':
          'आपका सत्यापन अस्वीकृत हो गया। कार्यक्रम बनाने के लिए फिर से सत्यापन भेजें।',
      'You need to be verified before creating events.':
          'कार्यक्रम बनाने से पहले आपका सत्यापन आवश्यक है।',
      'Unable to verify your account right now. Please try again.':
          'अभी आपका खाता सत्यापित नहीं किया जा सका। कृपया फिर से प्रयास करें।',
      'Create Event': 'कार्यक्रम बनाएं',
      'All': 'सभी',
      'Completed': 'पूर्ण',
      'Draft': 'मसौदा',
      'Retry': 'पुनः प्रयास करें',
      'All Events': 'सभी कार्यक्रम',
      'Ongoing Events': 'चल रहे कार्यक्रम',
      'Upcoming Events': 'आगामी कार्यक्रम',
      'Completed Events': 'पूर्ण कार्यक्रम',
      'Draft Events': 'मसौदा कार्यक्रम',
      'Cancelled Events': 'रद्द कार्यक्रम',
      'No {title}': 'कोई {title} नहीं',
      'Organiser: {name}': 'आयोजक: {name}',
      'Untitled': 'शीर्षक नहीं',
      'Location: {location}': 'स्थान: {location}',
      'N/A': 'उपलब्ध नहीं',
      'Date: {date}': 'तारीख: {date}',
      'No ratings yet': 'अभी तक कोई रेटिंग नहीं',
      'Review': 'समीक्षा',
      'Removed by admin': 'एडमिन द्वारा हटाया गया',
      'Not published': 'प्रकाशित नहीं',
      'Cancelled by organiser': 'आयोजक द्वारा रद्द',
      'Starts today': 'आज शुरू होता है',
      'Starts in {days}d': '{days} दिन में शुरू',
      'Deadline passed': 'समय-सीमा समाप्त',
      'Deadline soon': 'समय-सीमा जल्द',
      'Approved: {accepted} / {required}': 'स्वीकृत: {accepted} / {required}',
      'Applicants: {raw} / {required}': 'आवेदक: {raw} / {required}',
      'Draft not visible to volunteers': 'मसौदा स्वयंसेवकों को दिखाई नहीं देता',
      'Application deadline passed': 'आवेदन की समय-सीमा समाप्त',
      'No applications yet': 'अभी तक कोई आवेदन नहीं',
      'Understaffed by {count}': '{count} स्वयंसेवक कम हैं',
      'to': 'से',
    },
  };

  String t(String key, {Map<String, String> args = const {}}) {
    final lang = _localizedValues[locale.languageCode] ??
        _localizedValues['en'] ??
        const {};
    var value = lang[key] ?? _localizedValues['en']?[key] ?? key;
    if (args.isNotEmpty) {
      args.forEach((k, v) {
        value = value.replaceAll('{$k}', v);
      });
    }
    return value;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales
        .any((supported) => supported.languageCode == locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) {
    return false;
  }
}
