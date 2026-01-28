# 🎨 PROFILE PICTURE FEATURE - VISUAL FLOW

## Upload Flow Diagram

```
USER INTERFACE (Flutter)
    ↓
    [Click Profile Picture]
    ↓
    [Gallery Opens] ← ImagePicker
    ↓
    [Select Image]
    ↓
    [Show "Image selected ✓"]
    ↓
    [User Clicks "Save Changes"]
    ↓
UPLOAD PROCESS
    ↓
    [POST /api/upload with image file]
    ↓
    Backend receives file → Saves to uploads/ folder
    ↓
    Returns: {"url": "http://localhost:4000/uploads/1234567.jpg"}
    ↓
PROFILE UPDATE PROCESS
    ↓
    [PUT /api/profile/update with image URL]
    ↓
    Request body:
    {
      "name": "John",
      "city": "Mumbai",
      "contact_number": "...",
      "profile_picture_url": "http://localhost:4000/uploads/1234567.jpg"
    }
    ↓
    Backend updates user in database
    ↓
    DATABASE UPDATE
    ↓
    UPDATE users SET profile_picture_url = '...' WHERE id = user_id
    ↓
DISPLAY ON PROFILE
    ↓
    [Get /profile endpoint returns profile_picture_url]
    ↓
    [Display as NetworkImage on profile screen]
    ↓
    [Show default person icon if no image]
```

## File Structure Changes

```
Backend/
├── controllers/
│   └── authController.js ✅ UPDATED
│       ├── getProfile() - Now returns profile_picture_url
│       └── updateProfile() - Now accepts profile_picture_url
├── uploads/ ✅ ALREADY EXISTING
│   └── [uploaded images stored here]
├── routes/
│   └── upload.js ✅ ALREADY WORKING
└── runMigration.js ✅ NEW (for database setup)

frontend/lib/screens/volunteer/
├── edit_profile_screen.dart ✅ UPDATED
│   ├── _selectedImage (state variable)
│   ├── _profileImageUrl (state variable)
│   ├── _pickImageFromGallery() ✅ NEW METHOD
│   ├── _uploadProfileImage() ✅ NEW METHOD
│   └── UI with tappable profile picture
└── volunteer_profile_screen.dart ✅ UPDATED
    ├── profilePictureUrl (state variable)
    └── Display NetworkImage with fallback to icon

Database/
└── users table
    └── profile_picture_url column ✅ ADDED
```

## State Variables Used

### Edit Profile Screen
```dart
File? _selectedImage;           // The actual image file from gallery
String? _profileImageUrl;       // URL of existing/uploaded image
ImagePicker _imagePicker;       // For picking from gallery
```

### Volunteer Profile Screen
```dart
String? profilePictureUrl;      // URL from API response
```

## Data Flow

### When Editing Profile with Image

```
User in Edit Screen
    ↓
    Click Profile Picture
    ↓
    _pickImageFromGallery()
    ↓
    Sets: _selectedImage = File(path)
    ↓
    User clicks Save
    ↓
    _saveChanges()
    ↓
    Calls: _uploadProfileImage()
    ↓
    MultipartRequest to /api/upload
    ↓
    Gets back: {"url": "..."}
    ↓
    Calls: PUT /profile/update with profile_picture_url
    ↓
    Navigator.pop() to refresh main profile
    ↓
    Main profile screen calls: fetchProfile()
    ↓
    Gets: profile_picture_url from API
    ↓
    Displays: NetworkImage(profilePictureUrl)
```

## Network Requests

### 1. Image Upload
```
POST http://localhost:4000/api/upload
Content-Type: multipart/form-data
Authorization: Bearer {token}

[Binary Image Data]

Response:
{
  "url": "http://localhost:4000/uploads/1234567890.jpg"
}
```

### 2. Profile Update
```
PUT http://localhost:4000/api/profile/update
Content-Type: application/json
Authorization: Bearer {token}

{
  "name": "John",
  "city": "Mumbai",
  "contact_number": "9876543210",
  "profile_picture_url": "http://localhost:4000/uploads/1234567890.jpg"
}

Response:
{
  "message": "Profile updated successfully",
  "user": {
    "id": 1,
    "name": "John",
    ...
    "profile_picture_url": "http://localhost:4000/uploads/1234567890.jpg"
  }
}
```

### 3. Get Profile (To Display)
```
GET http://localhost:4000/api/profile
Authorization: Bearer {token}

Response:
{
  "id": 1,
  "name": "John",
  "email": "john@example.com",
  "city": "Mumbai",
  "role": "volunteer",
  "contact_number": "9876543210",
  "profile_picture_url": "http://localhost:4000/uploads/1234567890.jpg"
}
```

## Error Handling

```
┌─ Image Upload Fails?
│  └─ Show: "Image upload failed: [error message]"
│
├─ Profile Update Fails?
│  └─ Show: "Update failed: [response body]"
│
└─ Network Error?
   └─ Show: "Error: [exception message]"
```

## UI Components

### Edit Profile Screen

```
┌─────────────────────────────────┐
│     Edit Profile                │
├─────────────────────────────────┤
│                                 │
│         [Tappable Avatar]       │ ← Click to select image
│            with Camera Icon     │
│         "Tap to choose from     │
│          gallery"               │
│                                 │
│  ═════════════════════════════  │
│                                 │
│  [Full Name input field]        │
│  [Email input field] (disabled) │
│  [City input field]             │
│  [Contact Number field]         │
│                                 │
│  ═════════════════════════════  │
│                                 │
│    [Save Changes] button        │
│                                 │
└─────────────────────────────────┘
```

### Profile View Screen

```
┌─────────────────────────────────┐
│     Gradient Header             │
│                                 │
│      [Profile Picture]          │ ← Shows uploaded image
│     or default icon             │
│                                 │
│      John Doe                   │
│      Mumbai, India              │
│    [Edit Profile] button        │
│                                 │
└─────────────────────────────────┘
    [My Applications]
    [My Badges]
    [Payment History]
    [Invite Friends]
    [Help & Support]
    [Logout]
```

## Technology Stack

```
Backend:
- Node.js / Express
- PostgreSQL Database
- Multer (File Upload)
- JWT (Authentication)

Frontend:
- Flutter / Dart
- image_picker package
- http package
- shared_preferences

Communication:
- RESTful API
- HTTP/HTTPS
- Multipart Form Data (for files)
- JSON (for data)
```
