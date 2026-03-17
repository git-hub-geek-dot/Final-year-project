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
      'Help & Support': 'Help & Support',
      'FAQs': 'FAQs',
      'Common questions answered': 'Common questions answered',
      'App Support': 'App Support',
      'Issues with the app or login': 'Issues with the app or login',
      'App not loading events?': 'App not loading events?',
      'Check your internet connection and try again.':
          'Check your internet connection and try again.',
      'Login issues?': 'Login issues?',
      'Make sure your credentials are correct or use Forgot Password.':
          'Make sure your credentials are correct or use Forgot Password.',
      'App crashes or bugs?': 'App crashes or bugs?',
      'Restart the app or update to the latest version.':
          'Restart the app or update to the latest version.',
      'Still facing issues?': 'Still facing issues?',
      'Contact our support team via email.':
          'Contact our support team via email.',
      'Safety & Guidelines': 'Safety & Guidelines',
      'Your safety matters': 'Your safety matters',
      'Always verify event details before attending.':
          'Always verify event details before attending.',
      'Avoid sharing personal or financial information.':
          'Avoid sharing personal or financial information.',
      'Report suspicious organisers or events immediately.':
          'Report suspicious organisers or events immediately.',
      'Follow community guidelines and event instructions.':
          'Follow community guidelines and event instructions.',
      'Contact Us': 'Contact Us',
      'Get in touch with our team': 'Get in touch with our team',
      'Contact VolunteerX': 'Contact VolunteerX',
      'Email Support': 'Email Support',
      'Our team usually responds within 24-48 hours.':
          'Our team usually responds within 24-48 hours.',
      'Please include screenshots or details for faster support.':
          'Please include screenshots or details for faster support.',
      'Frequently Asked Questions': 'Frequently Asked Questions',
      'What is the strike/suspension policy?':
          'What is the strike/suspension policy?',
      'Repeated violations may lead to strikes. 2 strikes: 3-day suspension, 3 strikes: 7-day suspension, 4 strikes: account ban.':
          'Repeated violations may lead to strikes. 2 strikes: 3-day suspension, 3 strikes: 7-day suspension, 4 strikes: account ban.',
      'How do I apply for an event?': 'How do I apply for an event?',
      'Open an event card and tap Apply. Fill required details and submit your application.':
          'Open an event card and tap Apply. Fill required details and submit your application.',
      'Can I cancel my application?': 'Can I cancel my application?',
      'Yes. If cancellation is available for that event, you can cancel from your application details.':
          'Yes. If cancellation is available for that event, you can cancel from your application details.',
      'How are badges earned?': 'How are badges earned?',
      'Badges are awarded based on completed events and consistent participation.':
          'Badges are awarded based on completed events and consistent participation.',
      'How do paid event payments work?': 'How do paid event payments work?',
      'Payment status depends on organiser confirmation and event completion.':
          'Payment status depends on organiser confirmation and event completion.',
      'Why are events not loading?': 'Why are events not loading?',
      'Check your internet connection, then refresh the page. If it persists, contact support.':
          'Check your internet connection, then refresh the page. If it persists, contact support.',
      'What if I face login issues?': 'What if I face login issues?',
      'Verify your credentials and try Forgot Password if needed.':
          'Verify your credentials and try Forgot Password if needed.',
      'How can I improve my profile completion?':
          'How can I improve my profile completion?',
      'Update your name, email, city, profile photo, and verification status in profile settings.':
          'Update your name, email, city, profile photo, and verification status in profile settings.',
      'How do I contact support?': 'How do I contact support?',
      'Email volunteerxteam@gmail.com with screenshots and issue details for faster support.':
          'Email volunteerxteam@gmail.com with screenshots and issue details for faster support.',
      'Token not found. Please login again.':
          'Token not found. Please login again.',
      'Error {statusCode}: {message}': 'Error {statusCode}: {message}',
      'Error: {error}': 'Error: {error}',
      'Name': 'Name',
      'Email': 'Email',
      'City': 'City',
      'Profile photo': 'Profile photo',
      'Verification status': 'Verification status',
      'Logout': 'Logout',
      'Are you sure you want to logout?':
          'Are you sure you want to logout?',
      'Cancel': 'Cancel',
      'Delete Account': 'Delete Account',
      'Are you sure you want to delete your account? This action is irreversible.':
          'Are you sure you want to delete your account? This action is irreversible.',
      'Delete': 'Delete',
      'Account deleted successfully.': 'Account deleted successfully.',
      'Delete failed': 'Delete failed',
      'Server error: {error}': 'Server error: {error}',
      'City not set': 'City not set',
      'India': 'India',
      'Edit Profile': 'Edit Profile',
      'Profile Completeness': 'Profile Completeness',
      '{percent}% complete': '{percent}% complete',
      'Missing: {items}': 'Missing: {items}',
      'Impact Summary': 'Impact Summary',
      'Rating': 'Rating',
      'My Applications': 'My Applications',
      'Saved Events': 'Saved Events',
      'My Badges': 'My Badges',
      'Verification Under Review': 'Verification Under Review',
      'Verified': 'Verified',
      'Get Verified': 'Get Verified',
      'Your account is already verified.': 'Your account is already verified.',
      'Your verification request is under review.':
          'Your verification request is under review.',
      'Payment Status': 'Payment Status',
      'Invite Friends': 'Invite Friends',
      'Edit': 'Edit',
      'Only JPG, JPEG, PNG, and WEBP images are allowed':
          'Only JPG, JPEG, PNG, and WEBP images are allowed',
      'Image must be 5 MB or smaller': 'Image must be 5 MB or smaller',
      'Error picking image: {error}': 'Error picking image: {error}',
      'Profile picture updated successfully':
          'Profile picture updated successfully',
      'Failed to upload image': 'Failed to upload image',
      'Remove Profile Picture': 'Remove Profile Picture',
      'Are you sure you want to remove your profile picture?':
          'Are you sure you want to remove your profile picture?',
      'Remove': 'Remove',
      'Profile picture removed successfully':
          'Profile picture removed successfully',
      'Failed to remove picture': 'Failed to remove picture',
      'Name cannot be empty': 'Name cannot be empty',
      'Profile updated, but preferences failed':
          'Profile updated, but preferences failed',
      'Profile updated successfully': 'Profile updated successfully',
      'Update failed: {message}': 'Update failed: {message}',
      'Change Profile Picture': 'Change Profile Picture',
      'Full Name': 'Full Name',
      'City (Optional)': 'City (Optional)',
      'Contact Number (Optional)': 'Contact Number (Optional)',
      'Skills': 'Skills',
      'Add skill': 'Add skill',
      'Interests': 'Interests',
      'Add interest': 'Add interest',
      'Saving...': 'Saving...',
      'Save Changes': 'Save Changes',
      'No items added': 'No items added',
      'Unable to load badges right now.':
          'Unable to load badges right now.',
      'hosted events': 'hosted events',
      'completed events': 'completed events',
      'Requires {threshold} {noun}': 'Requires {threshold} {noun}',
      'Hosted events': 'Hosted events',
      'Completed events': 'Completed events',
      'No badge yet': 'No badge yet',
      'Refresh': 'Refresh',
      'Current Badge: {badge}': 'Current Badge: {badge}',
      '{label}: {count}': '{label}: {count}',
      'Next badge: {name} at {threshold} {label}':
          'Next badge: {name} at {threshold} {label}',
      'No badges configured in system yet.':
          'No badges configured in system yet.',
      'Badge': 'Badge',
      'Status updated': 'Status updated',
      'Failed: {message}': 'Failed: {message}',
      'Failed to update status': 'Failed to update status',
      'Received': 'Received',
      'Not applicable': 'Not applicable',
      'Payment report details are not available.':
          'Payment report details are not available.',
      'This unpaid payment report was already submitted.':
          'This unpaid payment report was already submitted.',
      'Report Unpaid Payment': 'Report Unpaid Payment',
      'This will create an admin report for unpaid compensation on {event}.':
          'This will create an admin report for unpaid compensation on {event}.',
      'this event': 'this event',
      'Details': 'Details',
      'Add any payment issue details for admin review.':
          'Add any payment issue details for admin review.',
      'Please add a short note for admin review.':
          'Please add a short note for admin review.',
      'Submit Report': 'Submit Report',
      'Unknown event': 'Unknown event',
      'Paid event': 'Paid event',
      'Unpaid payment report submitted for admin review.':
          'Unpaid payment report submitted for admin review.',
      'Failed to submit report: {error}':
          'Failed to submit report: {error}',
      'No approved events yet': 'No approved events yet',
      'Unknown Event': 'Unknown Event',
      'Unpaid payment report submitted.': 'Unpaid payment report submitted.',
      'Payment is still pending after clearance date.':
          'Payment is still pending after clearance date.',
      'Reported': 'Reported',
      'Report unpaid payment': 'Report unpaid payment',
      'Please login again to view organiser details.':
          'Please login again to view organiser details.',
      'Failed to load organiser profile': 'Failed to load organiser profile',
      'Network error': 'Network error',
      'Organiser': 'Organiser',
      'Organiser Profile': 'Organiser Profile',
      'About Organisation': 'About Organisation',
      'No description provided by organiser.':
          'No description provided by organiser.',
      'Based in {city}.': 'Based in {city}.',
      'Volunteers': 'Volunteers',
      'Connect with Us': 'Connect with Us',
      'Follow or visit to learn more about their work':
          'Follow or visit to learn more about their work',
      'Website': 'Website',
      'Instagram': 'Instagram',
      'Facebook': 'Facebook',
      'LinkedIn': 'LinkedIn',
      'Phone number is available only to approved volunteers when the organiser enables sharing.':
          'Phone number is available only to approved volunteers when the organiser enables sharing.',
      'Volunteer Reviews': 'Volunteer Reviews',
      'No reviews yet': 'No reviews yet',
      'Anonymous': 'Anonymous',
      'View All {count} Reviews': 'View All {count} Reviews',
      'All Reviews': 'All Reviews',
      'Last 5 Events Overall Rating': 'Last 5 Events Overall Rating',
      'Unknown': 'Unknown',
      'Individual Reviews': 'Individual Reviews',
      '{count} reviews': '{count} reviews',
      'No leaderboard data available': 'No leaderboard data available',
      'Failed to load leaderboard': 'Failed to load leaderboard',
      'Organisers': 'Organisers',
      'Weekly': 'Weekly',
      'Monthly': 'Monthly',
      '{count} events': '{count} events',
      '{count} events completed': '{count} events completed',
      'Announcements': 'Announcements',
      'Failed to load announcements\n{error}':
          'Failed to load announcements\n{error}',
      'No announcements for {event}': 'No announcements for {event}',
      'Announcement': 'Announcement',
      'Please login again': 'Please login again',
      'Please upload ID proof': 'Please upload ID proof',
      'Please upload selfie with ID': 'Please upload selfie with ID',
      'Verification request submitted': 'Verification request submitted',
      'Submission failed': 'Submission failed',
      'You do not need to submit verification again.':
          'You do not need to submit verification again.',
      'Back to Profile': 'Back to Profile',
      'You cannot submit another request until the current one is reviewed.':
          'You cannot submit another request until the current one is reviewed.',
      'Your previous verification request was rejected. Please review your details and submit again.':
          'Your previous verification request was rejected. Please review your details and submit again.',
      'Volunteer Verification': 'Volunteer Verification',
      'ID Type': 'ID Type',
      'Please select ID type': 'Please select ID type',
      'Upload ID Proof *': 'Upload ID Proof *',
      'ID Selected': 'ID Selected',
      'File too large (max 5MB)': 'File too large (max 5MB)',
      'Uploading ID proof...': 'Uploading ID proof...',
      'ID proof uploaded': 'ID proof uploaded',
      'Upload failed: {error}': 'Upload failed: {error}',
      'Upload Selfie with ID *': 'Upload Selfie with ID *',
      'Selfie Selected': 'Selfie Selected',
      'Uploading selfie...': 'Uploading selfie...',
      'Selfie uploaded': 'Selfie uploaded',
      'ID Number': 'ID Number',
      'Enter ID number': 'Enter ID number',
      'Invalid ID number': 'Invalid ID number',
      'Submit for Verification': 'Submit for Verification',
      'Invite friends to VolunteerX': 'Invite friends to VolunteerX',
      'Volunteer together, earn badges faster!':
          'Volunteer together, earn badges faster!',
      'Share Invite Link': 'Share Invite Link',
      'Removed': 'Removed',
      'Date not set': 'Date not set',
      'Your Organisation': 'Your Organisation',
      'Reviews': 'Reviews',
      'Your volunteers will appear here':
          'Your volunteers will appear here',
      'No events found': 'No events found',
      'Untitled Event': 'Untitled Event',
      'Location not set': 'Location not set',
      'Your organisation rating': 'Your organisation rating',
      'Volunteer reviews will appear here':
          'Volunteer reviews will appear here',
      'My Events': 'My Events',
      'Total': 'Total',
      'Search events...': 'Search events...',
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
      'Help & Support': 'सहायता और समर्थन',
      'FAQs': 'सामान्य प्रश्न',
      'Common questions answered': 'सामान्य प्रश्नों के उत्तर',
      'App Support': 'ऐप सहायता',
      'Issues with the app or login': 'ऐप या लॉगिन से जुड़ी समस्याएं',
      'App not loading events?': 'ऐप में इवेंट्स लोड नहीं हो रहे?',
      'Check your internet connection and try again.':
          'अपना इंटरनेट कनेक्शन जांचें और फिर से प्रयास करें।',
      'Login issues?': 'लॉगिन समस्या?',
      'Make sure your credentials are correct or use Forgot Password.':
          "सुनिश्चित करें कि आपके क्रेडेंशियल सही हैं या 'Forgot Password' का उपयोग करें।",
      'App crashes or bugs?': 'ऐप क्रैश या बग?',
      'Restart the app or update to the latest version.':
          'ऐप को रीस्टार्ट करें या नवीनतम संस्करण में अपडेट करें।',
      'Still facing issues?': 'अब भी समस्या है?',
      'Contact our support team via email.':
          'ईमेल के माध्यम से हमारी सहायता टीम से संपर्क करें।',
      'Safety & Guidelines': 'सुरक्षा और दिशानिर्देश',
      'Your safety matters': 'आपकी सुरक्षा महत्वपूर्ण है',
      'Always verify event details before attending.':
          'शामिल होने से पहले इवेंट विवरण सत्यापित करें।',
      'Avoid sharing personal or financial information.':
          'व्यक्तिगत या वित्तीय जानकारी साझा करने से बचें।',
      'Report suspicious organisers or events immediately.':
          'संदिग्ध आयोजकों या इवेंट्स की तुरंत रिपोर्ट करें।',
      'Follow community guidelines and event instructions.':
          'समुदाय दिशानिर्देश और इवेंट निर्देशों का पालन करें।',
      'Contact Us': 'संपर्क करें',
      'Get in touch with our team': 'हमारी टीम से संपर्क करें',
      'Contact VolunteerX': 'VolunteerX से संपर्क करें',
      'Email Support': 'ईमेल सहायता',
      'Our team usually responds within 24-48 hours.':
          'हमारी टीम आमतौर पर 24-48 घंटों में जवाब देती है।',
      'Please include screenshots or details for faster support.':
          'तेज़ सहायता के लिए कृपया स्क्रीनशॉट या विवरण शामिल करें।',
      'Frequently Asked Questions': 'अक्सर पूछे जाने वाले प्रश्न',
      'What is the strike/suspension policy?':
          'स्ट्राइक/निलंबन नीति क्या है?',
      'Repeated violations may lead to strikes. 2 strikes: 3-day suspension, 3 strikes: 7-day suspension, 4 strikes: account ban.':
          'बार-बार उल्लंघन करने पर स्ट्राइक लग सकती है। 2 स्ट्राइक: 3 दिनों का निलंबन, 3 स्ट्राइक: 7 दिनों का निलंबन, 4 स्ट्राइक: खाता प्रतिबंध।',
      'How do I apply for an event?': 'मैं किसी इवेंट के लिए आवेदन कैसे करूं?',
      'Open an event card and tap Apply. Fill required details and submit your application.':
          'किसी इवेंट कार्ड को खोलें और Apply पर टैप करें। आवश्यक विवरण भरें और आवेदन सबमिट करें।',
      'Can I cancel my application?': 'क्या मैं अपना आवेदन रद्द कर सकता हूं?',
      'Yes. If cancellation is available for that event, you can cancel from your application details.':
          'हां। यदि उस इवेंट के लिए रद्द करना उपलब्ध है, तो आप आवेदन विवरण से रद्द कर सकते हैं।',
      'How are badges earned?': 'बैज कैसे मिलते हैं?',
      'Badges are awarded based on completed events and consistent participation.':
          'बैज पूर्ण किए गए इवेंट्स और नियमित सहभागिता के आधार पर दिए जाते हैं।',
      'How do paid event payments work?': 'पेड इवेंट भुगतान कैसे काम करते हैं?',
      'Payment status depends on organiser confirmation and event completion.':
          'भुगतान स्थिति आयोजक की पुष्टि और इवेंट पूरा होने पर निर्भर करती है।',
      'Why are events not loading?': 'इवेंट्स लोड क्यों नहीं हो रहे?',
      'Check your internet connection, then refresh the page. If it persists, contact support.':
          'अपना इंटरनेट कनेक्शन जांचें, फिर पेज रिफ्रेश करें। यदि समस्या बनी रहे, तो सहायता से संपर्क करें।',
      'What if I face login issues?': 'यदि मुझे लॉगिन समस्या हो तो क्या करें?',
      'Verify your credentials and try Forgot Password if needed.':
          'अपने क्रेडेंशियल जांचें और जरूरत हो तो Forgot Password आज़माएं।',
      'How can I improve my profile completion?':
          'मैं अपना प्रोफाइल पूरा कैसे सुधारूं?',
      'Update your name, email, city, profile photo, and verification status in profile settings.':
          'प्रोफाइल सेटिंग्स में अपना नाम, ईमेल, शहर, प्रोफाइल फोटो और सत्यापन स्थिति अपडेट करें।',
      'How do I contact support?': 'मैं सहायता से कैसे संपर्क करूं?',
      'Email volunteerxteam@gmail.com with screenshots and issue details for faster support.':
          'तेज़ सहायता के लिए स्क्रीनशॉट और समस्या विवरण के साथ volunteerxteam@gmail.com पर ईमेल करें।',
      'Token not found. Please login again.':
          'टोकन नहीं मिला। कृपया फिर से लॉगिन करें।',
      'Error {statusCode}: {message}': 'त्रुटि {statusCode}: {message}',
      'Error: {error}': 'त्रुटि: {error}',
      'Name': 'नाम',
      'Email': 'ईमेल',
      'City': 'शहर',
      'Profile photo': 'प्रोफाइल फोटो',
      'Verification status': 'सत्यापन स्थिति',
      'Logout': 'लॉगआउट',
      'Are you sure you want to logout?':
          'क्या आप वाकई लॉगआउट करना चाहते हैं?',
      'Cancel': 'रद्द करें',
      'Delete Account': 'खाता हटाएं',
      'Are you sure you want to delete your account? This action is irreversible.':
          'क्या आप वाकई अपना खाता हटाना चाहते हैं? यह क्रिया अपरिवर्तनीय है।',
      'Delete': 'हटाएं',
      'Account deleted successfully.': 'खाता सफलतापूर्वक हटाया गया।',
      'Delete failed': 'हटाना विफल हुआ',
      'Server error: {error}': 'सर्वर त्रुटि: {error}',
      'City not set': 'शहर सेट नहीं है',
      'India': 'भारत',
      'Edit Profile': 'प्रोफाइल संपादित करें',
      'Profile Completeness': 'प्रोफाइल पूर्णता',
      '{percent}% complete': '{percent}% पूर्ण',
      'Missing: {items}': 'अपूर्ण: {items}',
      'Impact Summary': 'प्रभाव सारांश',
      'Rating': 'रेटिंग',
      'My Applications': 'मेरे आवेदन',
      'Saved Events': 'सेव किए गए इवेंट्स',
      'My Badges': 'मेरे बैज',
      'Verification Under Review': 'सत्यापन समीक्षा में है',
      'Verified': 'सत्यापित',
      'Get Verified': 'सत्यापन प्राप्त करें',
      'Your account is already verified.': 'आपका खाता पहले से सत्यापित है।',
      'Your verification request is under review.':
          'आपका सत्यापन अनुरोध समीक्षा में है।',
      'Payment Status': 'भुगतान स्थिति',
      'Invite Friends': 'मित्रों को आमंत्रित करें',
      'Edit': 'संपादित करें',
      'Only JPG, JPEG, PNG, and WEBP images are allowed':
          'केवल JPG, JPEG, PNG और WEBP इमेज अनुमत हैं',
      'Image must be 5 MB or smaller':
          'इमेज 5 MB या उससे कम होनी चाहिए',
      'Error picking image: {error}': 'इमेज चुनने में त्रुटि: {error}',
      'Profile picture updated successfully':
          'प्रोफाइल तस्वीर सफलतापूर्वक अपडेट हुई',
      'Failed to upload image': 'इमेज अपलोड विफल',
      'Remove Profile Picture': 'प्रोफाइल तस्वीर हटाएं',
      'Are you sure you want to remove your profile picture?':
          'क्या आप वाकई अपनी प्रोफाइल तस्वीर हटाना चाहते हैं?',
      'Remove': 'हटाएं',
      'Profile picture removed successfully':
          'प्रोफाइल तस्वीर सफलतापूर्वक हटाई गई',
      'Failed to remove picture': 'तस्वीर हटाने में विफल',
      'Name cannot be empty': 'नाम खाली नहीं हो सकता',
      'Profile updated, but preferences failed':
          'प्रोफाइल अपडेट हुई, लेकिन प्राथमिकताएं सहेजने में विफल',
      'Profile updated successfully': 'प्रोफाइल सफलतापूर्वक अपडेट हुई',
      'Update failed: {message}': 'अपडेट विफल: {message}',
      'Change Profile Picture': 'प्रोफाइल तस्वीर बदलें',
      'Full Name': 'पूरा नाम',
      'City (Optional)': 'शहर (वैकल्पिक)',
      'Contact Number (Optional)': 'संपर्क नंबर (वैकल्पिक)',
      'Skills': 'कौशल',
      'Add skill': 'कौशल जोड़ें',
      'Interests': 'रुचियां',
      'Add interest': 'रुचि जोड़ें',
      'Saving...': 'सहेजा जा रहा है...',
      'Save Changes': 'परिवर्तन सहेजें',
      'No items added': 'कोई आइटम जोड़ा नहीं गया',
      'Unable to load badges right now.':
          'अभी बैज लोड नहीं हो रहे हैं।',
      'hosted events': 'आयोजित इवेंट्स',
      'completed events': 'पूर्ण किए गए इवेंट्स',
      'Requires {threshold} {noun}': 'आवश्यक: {threshold} {noun}',
      'Hosted events': 'आयोजित इवेंट्स',
      'Completed events': 'पूर्ण किए गए इवेंट्स',
      'No badge yet': 'अभी कोई बैज नहीं',
      'Refresh': 'रिफ्रेश',
      'Current Badge: {badge}': 'वर्तमान बैज: {badge}',
      '{label}: {count}': '{label}: {count}',
      'Next badge: {name} at {threshold} {label}':
          'अगला बैज: {name} {threshold} {label} पर',
      'No badges configured in system yet.':
          'सिस्टम में अभी कोई बैज कॉन्फ़िगर नहीं है।',
      'Badge': 'बैज',
      'Status updated': 'स्थिति अपडेट हुई',
      'Failed: {message}': 'विफल: {message}',
      'Failed to update status': 'स्थिति अपडेट करने में विफल',
      'Received': 'प्राप्त',
      'Not applicable': 'लागू नहीं',
      'Payment report details are not available.':
          'भुगतान रिपोर्ट विवरण उपलब्ध नहीं हैं।',
      'This unpaid payment report was already submitted.':
          'यह अप्राप्त भुगतान रिपोर्ट पहले ही सबमिट की जा चुकी है।',
      'Report Unpaid Payment': 'अप्राप्त भुगतान रिपोर्ट करें',
      'This will create an admin report for unpaid compensation on {event}.':
          '{event} के लिए अप्राप्त भुगतान पर यह एक एडमिन रिपोर्ट बनाएगा।',
      'this event': 'इस इवेंट',
      'Details': 'विवरण',
      'Add any payment issue details for admin review.':
          'एडमिन समीक्षा के लिए भुगतान समस्या का विवरण जोड़ें।',
      'Please add a short note for admin review.':
          'एडमिन समीक्षा के लिए छोटा नोट जोड़ें।',
      'Submit Report': 'रिपोर्ट सबमिट करें',
      'Unknown event': 'अज्ञात इवेंट',
      'Paid event': 'पेड इवेंट',
      'Unpaid payment report submitted for admin review.':
          'अप्राप्त भुगतान रिपोर्ट एडमिन समीक्षा के लिए सबमिट की गई।',
      'Failed to submit report: {error}':
          'रिपोर्ट सबमिट करने में विफल: {error}',
      'No approved events yet': 'अभी तक कोई स्वीकृत इवेंट नहीं',
      'Unknown Event': 'अज्ञात इवेंट',
      'Unpaid payment report submitted.': 'अप्राप्त भुगतान रिपोर्ट सबमिट की गई।',
      'Payment is still pending after clearance date.':
          'क्लीयरेंस डेट के बाद भी भुगतान लंबित है।',
      'Reported': 'रिपोर्ट किया गया',
      'Report unpaid payment': 'अप्राप्त भुगतान रिपोर्ट करें',
      'Please login again to view organiser details.':
          'आयोजक विवरण देखने के लिए कृपया फिर से लॉगिन करें।',
      'Failed to load organiser profile': 'आयोजक प्रोफ़ाइल लोड करने में विफल',
      'Network error': 'नेटवर्क त्रुटि',
      'Organiser': 'आयोजक',
      'Organiser Profile': 'आयोजक प्रोफ़ाइल',
      'About Organisation': 'संगठन के बारे में',
      'No description provided by organiser.':
          'आयोजक द्वारा कोई विवरण उपलब्ध नहीं कराया गया।',
      'Based in {city}.': '{city} में स्थित।',
      'Volunteers': 'स्वयंसेवक',
      'Connect with Us': 'हमसे जुड़ें',
      'Follow or visit to learn more about their work':
          'उनके कार्य के बारे में अधिक जानने के लिए फॉलो करें या विज़िट करें',
      'Website': 'वेबसाइट',
      'Instagram': 'इंस्टाग्राम',
      'Facebook': 'फेसबुक',
      'LinkedIn': 'लिंक्डइन',
      'Phone number is available only to approved volunteers when the organiser enables sharing.':
          'आयोजक द्वारा शेयरिंग सक्षम करने पर फोन नंबर केवल स्वीकृत स्वयंसेवकों को दिखाई देगा।',
      'Volunteer Reviews': 'स्वयंसेवक समीक्षाएं',
      'No reviews yet': 'अभी तक कोई समीक्षा नहीं',
      'Anonymous': 'अनाम',
      'View All {count} Reviews': 'सभी {count} समीक्षाएं देखें',
      'All Reviews': 'सभी समीक्षाएं',
      'Last 5 Events Overall Rating': 'पिछले 5 इवेंट्स की कुल रेटिंग',
      'Unknown': 'अज्ञात',
      'Individual Reviews': 'व्यक्तिगत समीक्षाएं',
      '{count} reviews': '{count} समीक्षाएं',
      'No leaderboard data available': 'लीडरबोर्ड डेटा उपलब्ध नहीं है',
      'Failed to load leaderboard': 'लीडरबोर्ड लोड करने में विफल',
      'Organisers': 'आयोजक',
      'Weekly': 'साप्ताहिक',
      'Monthly': 'मासिक',
      '{count} events': '{count} इवेंट्स',
      '{count} events completed': '{count} इवेंट्स पूर्ण किए',
      'Announcements': 'घोषणाएं',
      'Failed to load announcements\n{error}':
          'घोषणाएं लोड करने में विफल\n{error}',
      'No announcements for {event}': '{event} के लिए कोई घोषणा नहीं',
      'Announcement': 'घोषणा',
      'Please login again': 'कृपया फिर से लॉगिन करें',
      'Please upload ID proof': 'कृपया आईडी प्रमाण अपलोड करें',
      'Please upload selfie with ID': 'कृपया आईडी के साथ सेल्फी अपलोड करें',
      'Verification request submitted': 'सत्यापन अनुरोध सबमिट किया गया',
      'Submission failed': 'सबमिशन विफल',
      'You do not need to submit verification again.':
          'आपको फिर से सत्यापन सबमिट करने की आवश्यकता नहीं है।',
      'Back to Profile': 'प्रोफाइल पर वापस',
      'You cannot submit another request until the current one is reviewed.':
          'वर्तमान अनुरोध की समीक्षा होने तक आप दूसरा अनुरोध सबमिट नहीं कर सकते।',
      'Your previous verification request was rejected. Please review your details and submit again.':
          'आपका पिछला सत्यापन अनुरोध अस्वीकृत हुआ था। कृपया विवरण जांचें और फिर से सबमिट करें।',
      'Volunteer Verification': 'स्वयंसेवक सत्यापन',
      'ID Type': 'आईडी प्रकार',
      'Please select ID type': 'कृपया आईडी प्रकार चुनें',
      'Upload ID Proof *': 'आईडी प्रमाण अपलोड करें *',
      'ID Selected': 'आईडी चयनित',
      'File too large (max 5MB)': 'फ़ाइल बहुत बड़ी है (अधिकतम 5MB)',
      'Uploading ID proof...': 'आईडी प्रमाण अपलोड हो रहा है...',
      'ID proof uploaded': 'आईडी प्रमाण अपलोड हो गया',
      'Upload failed: {error}': 'अपलोड विफल: {error}',
      'Upload Selfie with ID *': 'आईडी के साथ सेल्फी अपलोड करें *',
      'Selfie Selected': 'सेल्फी चयनित',
      'Uploading selfie...': 'सेल्फी अपलोड हो रही है...',
      'Selfie uploaded': 'सेल्फी अपलोड हो गई',
      'ID Number': 'आईडी नंबर',
      'Enter ID number': 'आईडी नंबर दर्ज करें',
      'Invalid ID number': 'अमान्य आईडी नंबर',
      'Submit for Verification': 'सत्यापन के लिए सबमिट करें',
      'Invite friends to VolunteerX': 'VolunteerX में दोस्तों को आमंत्रित करें',
      'Volunteer together, earn badges faster!':
          'साथ मिलकर स्वयंसेवा करें, तेजी से बैज पाएं!',
      'Share Invite Link': 'इनवाइट लिंक साझा करें',
      'Removed': 'हटाया गया',
      'Date not set': 'तारीख निर्धारित नहीं है',
      'Your Organisation': 'आपका संगठन',
      'Reviews': 'समीक्षाएं',
      'Your volunteers will appear here':
          'आपके स्वयंसेवक यहां दिखाई देंगे',
      'No events found': 'कोई इवेंट नहीं मिला',
      'Untitled Event': 'शीर्षकहीन इवेंट',
      'Location not set': 'स्थान निर्धारित नहीं है',
      'Your organisation rating': 'आपके संगठन की रेटिंग',
      'Volunteer reviews will appear here':
          'स्वयंसेवक समीक्षाएं यहां दिखाई देंगी',
      'My Events': 'मेरे इवेंट्स',
      'Total': 'कुल',
      'Search events...': 'इवेंट्स खोजें...',
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
