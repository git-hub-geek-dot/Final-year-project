# Profile Image Upload Feature

## Overview
This feature allows volunteers to upload, update, and delete their profile pictures. The authentication code has been preserved in all endpoints.

## API Endpoints

### 1. Upload Profile Picture
**Endpoint:** `POST /profile/picture/upload`
**Authentication:** Required (Bearer Token)
**Content-Type:** `multipart/form-data`

**Request:**
- Form data with file field: `image` (file upload)

**Response (Success):**
```json
{
  "success": true,
  "message": "Profile picture uploaded successfully",
  "user": {
    "id": 1,
    "name": "John Doe",
    "email": "john@example.com",
    "role": "volunteer",
    "city": "Mumbai",
    "contact_number": "9876543210",
    "profile_picture_url": "http://localhost:3000/uploads/1768369030958.jpg"
  }
}
```

**Response (Error):**
```json
{
  "success": false,
  "error": "No file uploaded"
}
```

**File Requirements:**
- Supported formats: JPEG, JPG, PNG, WebP
- Max file size: 5MB
- Files are automatically validated and saved with timestamp names

---

### 2. Delete Profile Picture
**Endpoint:** `DELETE /profile/picture`
**Authentication:** Required (Bearer Token)
**Content-Type:** `application/json`

**Request:**
```bash
curl -X DELETE http://localhost:3000/profile/picture \
  -H "Authorization: Bearer YOUR_TOKEN"
```

**Response (Success):**
```json
{
  "success": true,
  "message": "Profile picture removed successfully",
  "user": {
    "id": 1,
    "name": "John Doe",
    "email": "john@example.com",
    "role": "volunteer",
    "city": "Mumbai",
    "contact_number": "9876543210",
    "profile_picture_url": null
  }
}
```

**Features:**
- Removes profile picture from database
- Deletes physical file from uploads folder
- Sets profile_picture_url to NULL

---

### 3. Update Profile Picture (URL)
**Endpoint:** `PUT /profile/picture`
**Authentication:** Required (Bearer Token)
**Content-Type:** `application/json`

**Request:**
```json
{
  "profilePictureUrl": "http://example.com/image.jpg"
}
```

**Response (Success):**
```json
{
  "success": true,
  "message": "Profile picture updated successfully",
  "user": {
    "id": 1,
    "name": "John Doe",
    "email": "john@example.com",
    "role": "volunteer",
    "city": "Mumbai",
    "contact_number": "9876543210",
    "profile_picture_url": "http://example.com/image.jpg"
  }
}
```

---

## Frontend Implementation Example (Flutter)

### 1. Upload Image
```dart
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

Future<void> uploadProfilePicture() async {
  final picker = ImagePicker();
  final pickedFile = await picker.pickImage(source: ImageSource.gallery);
  
  if (pickedFile != null) {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('http://localhost:3000/profile/picture/upload'),
    );
    
    request.headers['Authorization'] = 'Bearer $authToken';
    request.files.add(
      await http.MultipartFile.fromPath('image', pickedFile.path),
    );
    
    final response = await request.send();
    final responseData = jsonDecode(await response.stream.bytesToString());
    
    if (response.statusCode == 200) {
      print('Picture uploaded: ${responseData['user']['profile_picture_url']}');
    }
  }
}
```

### 2. Delete Image
```dart
Future<void> deleteProfilePicture() async {
  final response = await http.delete(
    Uri.parse('http://localhost:3000/profile/picture'),
    headers: {
      'Authorization': 'Bearer $authToken',
      'Content-Type': 'application/json',
    },
  );
  
  if (response.statusCode == 200) {
    print('Profile picture deleted successfully');
  }
}
```

### 3. Display Image
```dart
String? profileImageUrl; // From user data

Widget buildProfileImage() {
  if (profileImageUrl != null && profileImageUrl!.isNotEmpty) {
    return Image.network(
      profileImageUrl!,
      width: 150,
      height: 150,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset('assets/images/placeholder.png');
      },
    );
  } else {
    return Image.asset('assets/images/placeholder.png');
  }
}
```

---

## Implementation Details

### Upload Process
1. User selects image file
2. Image is validated (format & size)
3. Old profile picture (if exists) is retrieved from database
4. New image is saved to `Backend/uploads/` folder
5. Database is updated with new image URL
6. Old image file is deleted from uploads folder
7. User data is returned with new profile picture URL

### Delete Process
1. Current profile picture URL is retrieved
2. Physical file is deleted from uploads folder
3. Database entry is cleared (set to NULL)
4. User data is returned with null profile_picture_url

### Security Features
- Authentication middleware on all endpoints
- File validation (format & size limits)
- Automatic file naming with timestamp
- Old files are cleaned up automatically
- User can only modify their own profile

---

## Database Schema
The User model includes:
```prisma
model User {
  id                    Int
  name                  String
  email                 String
  profilePictureUrl     String?  @map("profile_picture_url")
  // ... other fields
}
```

---

## Routes Integration
Make sure these routes are registered in your main server file:
```javascript
const profileRoutes = require('./routes/profileRoutes');
app.use('/api', profileRoutes);
```

Or if using a different path:
```javascript
app.use('/profile', profileRoutes);
```
