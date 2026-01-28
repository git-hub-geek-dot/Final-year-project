# Quick Test Commands for Image Upload

## Before Testing
1. Make sure your Backend server is running
2. Get a valid JWT token from a login request
3. Have an image file ready to upload

---

## Test with cURL

```bash
# Replace YOUR_TOKEN with actual JWT token
# Replace path/to/image.jpg with your image file path

curl -X POST http://localhost:4000/api/profile/picture/upload \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "image=@path/to/image.jpg" \
  -v
```

**-v flag shows verbose output with headers (helpful for debugging)**

---

## What to Look For in Server Logs

When you run the upload test, watch your server terminal for these logs in order:

### ✅ Success Flow:
```
📍 POST /profile/picture/upload - Request received
Headers: { ... authorization: 'Bearer YOUR_TOKEN', ... }
✅ Auth passed - User ID: 1
Multer destination - saving to: C:\...\Backend\uploads
Multer fileFilter - original name: image.jpg mimetype: image/jpeg
File accepted
✅ File uploaded - Filename: 1706424900000.jpg
UPLOAD PROFILE PICTURE - userId: 1, file: 1706424900000.jpg
Image URL: http://localhost:4000/uploads/1706424900000.jpg
Profile picture uploaded successfully for user: 1
```

### ❌ Auth Error Flow:
```
📍 POST /profile/picture/upload - Request received
AUTH ERROR: [error message]
```
**Solution:** Check your JWT token is valid and not expired

### ❌ File Error Flow:
```
Multer fileFilter - original name: file.txt mimetype: text/plain
Rejected upload mimetype: text/plain
MULTER ERROR: Invalid file type: text/plain
```
**Solution:** Only upload JPEG, PNG, WebP files

### ❌ File Size Error:
```
MULTER ERROR: LIMIT_FILE_SIZE File too large
```
**Solution:** Image must be less than 5MB

---

## Test with JavaScript/Node.js

Save this as `test-upload.js`:

```javascript
const FormData = require('form-data');
const fs = require('fs');
const http = require('http');

// Configuration
const TOKEN = 'YOUR_JWT_TOKEN_HERE';
const IMAGE_PATH = './test-image.jpg';

// Create form with file
const form = new FormData();
form.append('image', fs.createReadStream(IMAGE_PATH));

// HTTP request options
const options = {
  hostname: 'localhost',
  port: 4000,
  path: '/api/profile/picture/upload',
  method: 'POST',
  headers: {
    ...form.getHeaders(),
    'Authorization': `Bearer ${TOKEN}`
  }
};

// Make request
const req = http.request(options, (res) => {
  let data = '';
  
  console.log('Status Code:', res.statusCode);
  
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    console.log('\nResponse:');
    console.log(JSON.stringify(JSON.parse(data), null, 2));
  });
});

// Handle errors
req.on('error', err => {
  console.error('Request Error:', err);
});

// Send form
form.pipe(req);
```

Run with: `node test-upload.js`

---

## Common Issues & Fixes

### Issue: 401 Unauthorized
**Logs show:** `AUTH ERROR: Invalid or expired token`
**Fix:** 
1. Get new token from login endpoint
2. Make sure token is in correct format: `Authorization: Bearer YOUR_TOKEN`
3. Check token hasn't expired

### Issue: 400 No file uploaded
**Logs show:** `UPLOAD PROFILE PICTURE ERROR: No file uploaded`
**Fix:**
1. Make sure form field name is exactly `image` (case-sensitive)
2. Make sure you're using `multipart/form-data`
3. Verify file is being selected/attached

### Issue: File type rejected
**Logs show:** `Rejected upload mimetype: text/plain`
**Fix:**
1. Only JPEG, JPG, PNG, WebP allowed
2. Check file extension
3. If file extension wrong but content is image, rename extension

### Issue: File too large
**Logs show:** `MULTER ERROR: LIMIT_FILE_SIZE`
**Fix:**
1. Compress image to be under 5MB
2. Try with smaller test image first

### Issue: Upload silently fails
**Fix:**
1. Check all server logs - look for any error
2. Verify `/uploads` folder exists and has write permissions
3. Check database connection is working
4. Try accessing test endpoint: `http://localhost:4000/`

---

## Minimal Working Test

```bash
# 1. First, login to get token
curl -X POST http://localhost:4000/api/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password"}'

# Copy the token from response

# 2. Then upload image (replace TOKEN and path)
curl -X POST http://localhost:4000/api/profile/picture/upload \
  -H "Authorization: Bearer TOKEN" \
  -F "image=@test.jpg"

# 3. Response should show success with image URL
```

---

## Debug Checklist

- [ ] Server running on port 4000?
- [ ] Valid JWT token obtained from login?
- [ ] Image file is actual image (JPEG/PNG/WebP)?
- [ ] Image file less than 5MB?
- [ ] Form field name exactly `image`?
- [ ] Using `multipart/form-data` content type?
- [ ] Authorization header in format `Bearer TOKEN`?
- [ ] `/uploads` folder exists?
- [ ] `/uploads` folder writable?
- [ ] Database running and connected?

---

## Check Upload Success

After successful upload, you should see:

**In database:**
```sql
SELECT id, name, profile_picture_url FROM users WHERE id = 1;
```

Returns something like:
```
id | name     | profile_picture_url
1  | John Doe | http://localhost:4000/uploads/1706424900000.jpg
```

**Image accessible:**
Visit in browser: `http://localhost:4000/uploads/1706424900000.jpg`

**File system:**
Check folder: `Backend/uploads/`
Should contain: `1706424900000.jpg`
