# Quick Test Script

## 1. Backend Running?
Check if you can access: http://localhost:4000
(You should see: {"message": "API running"})

## 2. Test Image Upload with cURL
```bash
# Replace your-token with actual JWT token from login
curl -X POST http://localhost:4000/api/upload \
  -H "Authorization: Bearer your-token" \
  -F "image=@/path/to/image.jpg"

# Expected response:
# {"url":"http://localhost:4000/uploads/1234567.jpg"}
```

## 3. Test in Flutter
- Go to Edit Profile
- Select image
- Save
- Check Flutter console for debug logs

## 4. Verify in Database
```sql
-- In pgAdmin or psql
SELECT id, name, email, profile_picture_url FROM users LIMIT 5;
```

## 5. Check Uploads Folder
Navigate to: Backend/uploads/
You should see .jpg, .png files there

---

If all above steps work, your profile picture feature is ready! 🎉
