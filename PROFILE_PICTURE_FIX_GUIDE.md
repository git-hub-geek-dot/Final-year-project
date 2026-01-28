## TROUBLESHOOTING GUIDE: Profile Picture Upload

### Issue 1: Image Not Showing & Profile Update Failed

#### Root Cause:
The database doesn't have the `profile_picture_url` column yet. You need to run a migration.

#### Solution:

### Step 1: Add the Column to Database

Open your terminal and run this command from the Backend folder:

```bash
# For Windows (using psql)
psql -h localhost -U postgres -d volunteerx_db -f add_profile_picture_column.sql
```

Or manually in pgAdmin:
1. Open pgAdmin
2. Connect to your database
3. Run this SQL:
```sql
ALTER TABLE users ADD COLUMN profile_picture_url VARCHAR(500);
```

### Step 2: Verify the Column Was Added

In pgAdmin or psql, run:
```sql
SELECT column_name FROM information_schema.columns WHERE table_name = 'users';
```

You should see `profile_picture_url` in the list.

### Step 3: Test the Upload

1. Run the backend server
2. Open the Flutter app
3. Go to Edit Profile
4. Click on the profile picture to select an image from gallery
5. You should see "Image selected ✓" message
6. Click "Save Changes"

### Step 4: Check Console Logs

If you still get errors, check the Flutter console for debug messages:
- Look for "Image uploaded successfully! URL: ..." messages
- Look for "Profile update response status:" messages

If you see specific errors, share them for further debugging.

### Additional Debugging:

If the upload still fails, check:

1. **Backend Uploads Folder Exists:**
   - Navigate to: `Backend/uploads/`
   - Create it if it doesn't exist

2. **Check Backend Permissions:**
   - Make sure the Backend server can write to the uploads folder

3. **Test Upload Endpoint Directly:**
   - Use Postman to POST to: `http://localhost:4000/api/upload`
   - Send a file as multipart form-data
   - You should get back: `{"url": "http://localhost:4000/uploads/1234567.jpg"}`

### What the Fix Does:

✅ Adds database column for storing image URLs
✅ Adds console logging to help debug issues
✅ Saves profile picture URL to database when updated
✅ Displays profile picture on both edit and view screens
