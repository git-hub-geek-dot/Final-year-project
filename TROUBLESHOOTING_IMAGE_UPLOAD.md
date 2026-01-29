# Image Upload Troubleshooting Guide

## Issues Fixed ✅

1. **Added error handling for multer** - File size, type validation errors are now properly caught
2. **Improved URL construction** - Better handling of localhost vs production URLs
3. **Better error logging** - More detailed console logs for debugging
4. **File cleanup on failure** - Files are deleted if any error occurs during upload

---

## Testing the Image Upload

### Option 1: Using cURL (Command Line)

```bash
# Make sure you have a JWT token from login
curl -X POST http://localhost:4000/api/profile/picture/upload \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -F "image=@path/to/your/image.jpg"
```

### Option 2: Using Postman

1. **Set method to POST**
2. **URL:** `http://localhost:4000/api/profile/picture/upload`
3. **Headers tab:** Add `Authorization: Bearer YOUR_JWT_TOKEN`
4. **Body tab:** Select `form-data`
5. **Add form field:**
   - Key: `image`
   - Type: Select `File` from dropdown
   - Value: Choose your image file
6. **Click Send**

### Option 3: Using Thunder Client (VS Code)

Same as Postman - select form-data and add the image file with key `image`

---

## Common Error Messages & Solutions

### ❌ "No file uploaded"
**Cause:** File not sent in request body
**Solution:** 
- Make sure form field name is exactly `image`
- Use `multipart/form-data` content type
- Check that file is properly selected

### ❌ "File size too large. Maximum 5MB allowed"
**Cause:** Image file is larger than 5MB
**Solution:**
- Compress the image before uploading
- Use tools like ImageOptimizer or TinyPNG

### ❌ "Invalid file type"
**Cause:** File is not an image or wrong format
**Solution:**
- Only JPEG, JPG, PNG, WebP are allowed
- Check file extension and MIME type

### ❌ "Unauthorized"
**Cause:** Missing or invalid JWT token
**Solution:**
- Login first to get a valid token
- Add token to Authorization header: `Bearer YOUR_TOKEN`
- Check token hasn't expired

### ❌ "User not found"
**Cause:** User ID in token doesn't exist in database
**Solution:**
- Make sure you're using a token from a valid, existing user
- Check database has user record

### ❌ "Internal server error"
**Cause:** Database connection or other server issue
**Solution:**
- Check server logs for detailed error message
- Verify database is running and connected
- Check `/uploads` folder permissions

---

## Server Logs to Check

When testing, watch the server terminal for these logs:

```
UPLOAD PROFILE PICTURE - userId: 1, file: 1706424900000.jpg
Image URL: http://localhost:4000/uploads/1706424900000.jpg
Profile picture uploaded successfully for user: 1
```

If you see errors:

```
UPLOAD PROFILE PICTURE ERROR: [Error details...]
DATABASE ERROR: [Connection error...]
MULTER ERROR: [File error...]
```

---

## Verify Upload Success

### Check 1: File exists in uploads folder
```bash
# Windows
dir Backend/uploads

# Linux/Mac
ls -la Backend/uploads
```

You should see the image file with timestamp name.

### Check 2: Database updated
```sql
SELECT id, name, profile_picture_url FROM users WHERE id = 1;
```

You should see the profile_picture_url is set to something like:
`http://localhost:4000/uploads/1706424900000.jpg`

### Check 3: Access image in browser
Visit: `http://localhost:4000/uploads/FILENAME.jpg`

The image should display if all is working.

---

## API Response Examples

### ✅ Success Response
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
    "profile_picture_url": "http://localhost:4000/uploads/1706424900000.jpg"
  }
}
```

### ❌ Error Response
```json
{
  "success": false,
  "error": "No file uploaded"
}
```

---

## Debug Checklist

- [ ] Server is running (`npm start` or `node server.js`)
- [ ] JWT token is valid (not expired)
- [ ] Image file is selected in request
- [ ] Form field name is exactly `image`
- [ ] Content-Type is `multipart/form-data`
- [ ] File format is JPEG, PNG, or WebP
- [ ] File size is less than 5MB
- [ ] Database is running and connected
- [ ] `/uploads` folder exists and has write permissions
- [ ] Authorization header format is `Bearer TOKEN`

---

## Quick Test Script (Node.js)

Create `test-upload.js`:

```javascript
const FormData = require('form-data');
const fs = require('fs');
const https = require('https');

const token = 'YOUR_JWT_TOKEN';
const imageFile = './test-image.jpg';

const form = new FormData();
form.append('image', fs.createReadStream(imageFile));

const options = {
  hostname: 'localhost',
  port: 4000,
  path: '/api/profile/picture/upload',
  method: 'POST',
  headers: {
    ...form.getHeaders(),
    'Authorization': `Bearer ${token}`
  }
};

const req = https.request(options, (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    console.log('Status:', res.statusCode);
    console.log('Response:', JSON.parse(data));
  });
});

form.pipe(req);
req.on('error', err => console.error('Error:', err));
```

Run with: `node test-upload.js`

---

## Still Having Issues?

1. **Check server logs** - Look for specific error messages
2. **Verify auth middleware** - Add console.log in auth.js to debug token parsing
3. **Check upload permissions** - Ensure `/uploads` folder has write access
4. **Test with smaller file** - Try with a very small image (< 1MB)
5. **Browser console** - Check frontend for CORS or network errors
6. **Database logs** - Check PostgreSQL logs for query errors
