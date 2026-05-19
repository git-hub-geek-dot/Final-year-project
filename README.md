# VolunteerX 🤝

A comprehensive Flutter mobile application connecting volunteers with meaningful opportunities to make a positive impact in their communities.

---

## 🌟 Features

- **Volunteer Discovery** - Browse and search volunteer opportunities near you
- **Real-time Notifications** - Get instant updates on opportunities and messages using Firebase Messaging
- **User Authentication** - Secure login with JWT token management and Firebase Auth
- **Interactive Dashboard** - View statistics and progress with beautiful charts
- **Community Engagement** - Connect with other volunteers and organizations
- **Image Upload** - Share photos and documents for opportunities
- **Offline Support** - Persistent data storage with Shared Preferences
- **Live Communication** - Real-time messaging using Socket.io

---

## 💻 Tech Stack

### Frontend
- **Framework**: Flutter (Dart)
- **State Management**: Provider / GetX
- **Authentication**: Firebase Auth + JWT
- **Real-time**: Socket.io Client
- **Storage**: Firebase + Local (SharedPreferences)
- **UI Libraries**: 
  - `fl_chart` - Beautiful charts and graphs
  - `image_picker` - Camera and gallery access
  - `share_plus` - Social sharing
  - `intl` - Internationalization

### Backend
- Node.js / Express (referenced in Backend folder)
- Firebase Realtime Database / Firestore
- Socket.io for real-time events

---

## 📱 Screenshots & Demo

Check the `output` folder for app screenshots and demonstrations.

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.0.0 or higher)
- Android Studio / Xcode
- Firebase project setup

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/0-Amit-0/VolunteerX.git
cd VolunteerX
```

2. **Install dependencies**
```bash
cd frontend
flutter pub get
```

3. **Configure Firebase**
- Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
- Update Firebase configuration in the app

4. **Run the app**
```bash
flutter run
```

---

## 📂 Project Structure

```
VolunteerX/
├── frontend/          # Flutter mobile application
│   ├── lib/          # Source code
│   ├── assets/       # Images and resources
│   └── pubspec.yaml  # Dependencies
├── Backend/          # Backend services (Node.js)
└── output/           # App demos and screenshots
```

---

## 🔑 Key Dependencies

| Package | Purpose |
|---------|---------|
| `firebase_core` | Firebase initialization |
| `firebase_auth` | User authentication |
| `firebase_messaging` | Push notifications |
| `socket_io_client` | Real-time communication |
| `http` | API requests |
| `jwt_decode` | JWT token parsing |
| `fl_chart` | Data visualization |
| `image_picker` | Media selection |
| `shared_preferences` | Local data storage |

---

## 🎯 How It Works

1. **User Registration** - Sign up with email/password via Firebase
2. **Discover Opportunities** - Browse volunteer activities in your area
3. **Apply/Participate** - Express interest in opportunities
4. **Real-time Updates** - Receive notifications and messages
5. **Track Impact** - View your volunteer statistics and contributions

---

## 🤝 Contributing

Contributions are welcome! Feel free to:
- Report bugs
- Suggest new features
- Submit pull requests

---

## 📝 License

This project is open source and available under the MIT License.

---

## 👤 Author

**Amit Shakya**
- GitHub: [@0-Amit-0](https://github.com/0-Amit-0)
- Portfolio: [0-Amit-0.github.io](https://0-Amit-0.github.io)

---

## 📞 Support

For questions or issues, please open a GitHub issue or contact me directly.

---

**Show your support by starring this repository! ⭐**
