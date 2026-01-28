# 🎉 PROFILE PICTURE UPLOAD FEATURE - COMPLETE SETUP

## ✅ What Has Been Done

### Database Level
- ✅ Added `profile_picture_url` VARCHAR(500) column to users table
- ✅ Migration successfully executed
- ✅ Column verified in database

### Backend (Node.js/Express)
- ✅ Updated `getProfile` endpoint to return profile_picture_url
- ✅ Updated `updateProfile` endpoint to accept and save profile_picture_url
- ✅ Upload endpoint at `/api/upload` already functional (uploads files to Backend/uploads/)
- ✅ Static file serving configured for /uploads directory

### Frontend (Flutter)
- ✅ Image picker integrated (gallery only for now)
- ✅ Image preview with visual feedback
- ✅ Upload functionality with error handling
- ✅ Profile picture display on both edit and view screens
- ✅ Comprehensive console logging for debugging

---

## 🚀 How to Use

### 1. Make Sure Backend is Running
```bash
cd Backend
npm start
# Server should be running on http://localhost:4000
```

### 2. Make Sure Flutter is Running
```bash
cd frontend
flutter run
```

### 3. Test the Feature
1. Go to **Volunteer Profile** screen
2. Click **"Edit Profile"** button
3. **Tap on the profile picture** (you'll see a camera/gallery icon)
4. **Select an image** from your gallery
5. You should see: **"Image selected ✓"** in green
6. Click **"Save Changes"** button
7. Wait for the upload and save to complete
8. Profile picture should now show on the profile screen

---

## 🔍 Troubleshooting

### Issue: "Failed to upload image"

**Check 1:** Backend is running
```bash
# Visit http://localhost:4000 in browser
# Should see: {"message": "API running"}
```

**Check 2:** Uploads folder exists
```bash
# Navigate to: Backend/uploads/
# Create it if missing
mkdir Backend/uploads
```

**Check 3:** File permissions
- Make sure Backend process can write to uploads folder
- On Windows, usually not an issue if folder exists

**Check 4:** Check Flutter console logs
- Look for messages starting with "Image uploaded successfully! URL:"
- If you see error, share the full error message

---

### Issue: "Update failed"

**Check 1:** Database column exists
```sql
-- In pgAdmin or psql, run:
SELECT column_name FROM information_schema.columns 
WHERE table_name = 'users' AND column_name = 'profile_picture_url';
```
Should return: `profile_picture_url`

**Check 2:** Check backend server logs
- Look for SQL errors
- Look for HTTP errors

**Check 3:** Verify the image was uploaded
- Check Backend/uploads/ folder
- Should have files like: `1234567890.jpg`

---

### Issue: Image shows as broken image / won't load

**Possible causes:**
1. Image URL is incorrect
2. Backend static file serving not working
3. Check console for the actual URL being requested

**Fix:** Test image URL directly in browser
- Look at the profile in edit screen
- Right-click image → Inspect
- Check the `src` URL
- Paste URL in browser to see if it loads

---

## 📝 Console Logging Guide

### Expected Logs When Uploading

**Flutter Console:**
```
Image selected, uploading...
Starting image upload...
Image path: /data/user/0/com.example.frontend/cache/image123.jpg
Sending upload request to: http://localhost:4000/api/upload
Upload response status: 200
Upload response: {"url":"http://localhost:4000/uploads/1234567890.jpg"}
Image uploaded successfully! URL: http://localhost:4000/uploads/1234567890.jpg
Sending profile update...
URL: http://localhost:4000/api/profile/update
Body: {"name":"John","city":"Mumbai","contact_number":"...","profile_picture_url":"http://localhost:4000/uploads/1234567890.jpg"}
Profile update response status: 200
```

**Backend Console:**
```
POST /api/upload - File received and saved
PUT /api/profile/update - Profile updated with new image URL
```

---

## 📂 File Locations

| Component | File |
|-----------|------|
| Database Column | PostgreSQL database |
| Backend Controllers | Backend/controllers/authController.js |
| Frontend Edit Screen | frontend/lib/screens/volunteer/edit_profile_screen.dart |
| Frontend View Screen | frontend/lib/screens/volunteer/volunteer_profile_screen.dart |
| Upload Endpoint | Backend/routes/upload.js |
| Upload Directory | Backend/uploads/ |
| Migration Script | Backend/runMigration.js |

---

## 🔧 Advanced: Manual Testing with Postman

### Test Image Upload Endpoint

1. **Get a valid JWT token** from login
2. **Open Postman**
3. **Create POST request to:** `http://localhost:4000/api/upload`
4. **In Headers tab, add:**
   - Key: `Authorization`
   - Value: `Bearer YOUR_JWT_TOKEN`
5. **In Body tab, select "form-data"**
6. **Add field:**
   - Key: `image`
   - Type: File
   - Select an image
7. **Click Send**
8. **Expected Response:**
```json
{
  "url": "http://localhost:4000/uploads/1234567890.jpg"
}
```

### Test Profile Update Endpoint

1. **Create PUT request to:** `http://localhost:4000/api/profile/update`
2. **In Headers tab, add:**
   - Key: `Authorization`
   - Value: `Bearer YOUR_JWT_TOKEN`
   - Key: `Content-Type`
   - Value: `application/json`
3. **In Body tab, select "raw" and "JSON":**
```json
{
  "name": "John Doe",
  "city": "Mumbai",
  "contact_number": "9876543210",
  "profile_picture_url": "http://localhost:4000/uploads/1234567890.jpg"
}
```
4. **Click Send**
5. **Expected Response:**
```json
{
  "message": "Profile updated successfully",
  "user": {
    "id": 1,
    "name": "John Doe",
    "email": "john@example.com",
    "role": "volunteer",
    "city": "Mumbai",
    "contact_number": "9876543210",
    "profile_picture_url": "http://localhost:4000/uploads/1234567890.jpg"
  }
}
```

---

## 🎯 Next Steps

### To Add Camera Feature Later:
Update `_pickImageFromGallery()` in edit_profile_screen.dart:

```dart
// Change from:
source: ImageSource.gallery,

// To:
source: ImageSource.camera,
```

Or create a dialog to let users choose between camera and gallery.

### Additional Features You Could Add:
- [ ] Crop image before upload
- [ ] Compress image to reduce file size
- [ ] Show upload progress indicator
- [ ] Allow image deletion
- [ ] Support for different image formats (PNG, GIF, etc.)

---

## ✨ Feature Summary

Your volunteer profile now has:
- ✅ Gallery image selection
- ✅ Image preview before save
- ✅ Automatic upload to server
- ✅ Image display on profile view
- ✅ Image display on profile edit
- ✅ Error handling and user feedback
- ✅ Comprehensive console logging

Ready to test! 🚀
