# 📸 CAMERA & GALLERY - IMAGE SOURCE SELECTION FEATURE

## What Was Added

Users can now choose between **Camera** or **Gallery** when uploading profile pictures!

## Features

✅ **Bottom Sheet Modal** - Shows options when tapping profile picture
✅ **Camera Option** - Take photo directly with device camera
✅ **Gallery Option** - Select existing photos from device
✅ **Both on All Platforms** - Works on web, mobile, and desktop
✅ **Visual UI** - Icons and descriptions for clarity
✅ **Same Upload Process** - Both use the same upload mechanism

## How It Works

### User Flow

```
User taps on profile picture
    ↓
Bottom sheet appears with 2 options:
    1. "Take Photo" (Camera icon)
    2. "Choose from Gallery" (Image icon)
    ↓
User selects one
    ↓
Camera or Gallery opens
    ↓
User captures/selects image
    ↓
Image preview shows with "Image selected ✓"
    ↓
User clicks Save Changes
    ↓
Image uploads and displays
```

## What Changed

### File: `frontend/lib/screens/volunteer/edit_profile_screen.dart`

**New Methods Added:**

1. **`_showImageSourceOptions()`**
   - Shows bottom sheet with camera and gallery options
   - Displays as modal at bottom of screen
   - Has nice icons and descriptions

2. **`_pickImageFromCamera()`**
   - Opens device camera
   - Captures photo directly
   - Returns XFile to process

3. **`_pickImageFromGallery()`**
   - Opens photo gallery/library
   - Lets user select existing photos
   - Returns XFile to process

**Updated Elements:**

- Profile picture tap now calls `_showImageSourceOptions()`
- Helper text updated to: "Tap to take photo or choose from gallery"
- Both camera and gallery use same upload and removal logic

## Testing Steps

### 1. Open Edit Profile
- Go to Volunteer Profile
- Click "Edit Profile" button

### 2. Tap Profile Picture
- Click on the profile picture
- Bottom sheet will slide up

### 3. Try Camera Option
- Click "Take Photo"
- Device camera opens
- Take a photo
- Image preview shows

### 4. Try Gallery Option
- Tap profile picture again
- Click "Choose from Gallery"
- Photo gallery opens
- Select an existing photo
- Image preview shows

### 5. Save Changes
- Click "Save Changes"
- Image uploads successfully
- Shows on profile

## UI Details

### Bottom Sheet Appearance

```
┌─────────────────────────────┐
│                             │
│  Select Image Source        │
│                             │
│  📷 Take Photo              │
│     Capture using camera    │
│  ─────────────────────      │
│  🖼️ Choose from Gallery      │
│     Select from your photos │
│                             │
└─────────────────────────────┘
```

### Platform Support

| Feature | Web | Android | iOS | Windows | macOS | Linux |
|---------|-----|---------|-----|---------|-------|-------|
| Gallery | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Camera | ⚠️ | ✅ | ✅ | ✅ | ✅ | ✅ |

**Note:** Camera on web may be limited depending on browser support.

## Code Examples

### Accessing the Feature

1. **Via UI:**
   - User taps profile picture in Edit Profile screen

2. **Methods Available:**
   ```dart
   _showImageSourceOptions()  // Shows the choice dialog
   _pickImageFromCamera()     // Opens camera
   _pickImageFromGallery()    // Opens gallery
   ```

### Image Quality

Both camera and gallery use:
```dart
imageQuality: 80  // 80% compression to reduce file size
```

## Error Handling

If user doesn't have camera permissions or gallery access:
- Shows error message on screen
- Gracefully handles cancellations
- User can try again

## Storage

- **Camera:** Temporary file in app cache
- **Gallery:** Reference to existing photo
- **Both:** Uploaded to backend and displayed

## Same Upload Logic

Both camera and gallery images go through:
1. Same upload process via `/api/upload`
2. Same removal process
3. Same display on profile
4. Same database storage

## No Backend Changes Needed

The backend upload endpoint already supports:
- Files from camera
- Files from gallery
- Web platform files
- Mobile platform files
- Desktop platform files

## Permissions Required

### Android
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

### iOS
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access needed to take profile photos</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Photo library access needed to select profile photos</string>
```

*Note: These are typically already configured in your Flutter project.*

## Browser Compatibility (Web)

- **Chrome:** Camera ✅, Gallery ✅
- **Firefox:** Camera ✅, Gallery ✅
- **Safari:** Camera ⚠️, Gallery ✅
- **Edge:** Camera ✅, Gallery ✅

## Testing Checklist

- [ ] Open Edit Profile
- [ ] Tap profile picture
- [ ] See bottom sheet with options
- [ ] Click "Take Photo" - camera opens
- [ ] Capture a photo - preview shows
- [ ] Save changes - uploads successfully
- [ ] Go back to Edit Profile
- [ ] Tap profile picture again
- [ ] Click "Choose from Gallery" - gallery opens
- [ ] Select a photo - preview shows
- [ ] Save changes - uploads successfully
- [ ] Picture displays on profile screen
- [ ] Can remove picture using "Remove picture" link
- [ ] Can upload new one after removal

## Troubleshooting

### Camera Not Opening
- Check camera permissions on device
- Restart app and try again
- Check if device has camera (some web browsers may not)

### Gallery Not Opening
- Check storage permissions on device
- Make sure device has photos
- Restart app and try again

### Image Not Uploading After Selection
- Check backend is running
- Check network connection
- Look at console logs for errors

---

**Feature is ready!** Users can now choose between camera and gallery! 📸🖼️
