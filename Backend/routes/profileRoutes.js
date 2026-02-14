const express = require("express");
const router = express.Router();
const multer = require("multer");
const path = require("path");
const fs = require("fs");

const authMiddleware = require("../middleware/auth");
const profileController = require("../controllers/profileController");
const { storage: cloudinaryStorage } = require("../config/cloudinary");

// ================= MULTER CONFIGURATION FOR PROFILE PICTURE =================
// Check if Cloudinary is configured
const isCloudinaryConfigured = process.env.CLOUDINARY_CLOUD_NAME && process.env.CLOUDINARY_API_KEY && process.env.CLOUDINARY_API_SECRET;

// Use Cloudinary if configured, otherwise local disk storage
let storage;
if (isCloudinaryConfigured) {
  storage = cloudinaryStorage;
} else {
  // Ensure uploads folder exists for local storage
  const uploadDir = path.join(__dirname, "..", "uploads");
  if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir, { recursive: true });
  }

  storage = multer.diskStorage({
    destination: (req, file, cb) => {
      console.log("Multer destination - saving to:", uploadDir);
      cb(null, uploadDir);
    },
    filename: (req, file, cb) => {
      const ext = path.extname(file.originalname);
      const filename = Date.now() + ext;
      console.log("Multer filename:", filename);
      cb(null, filename);
    },
  });
}

// Accept only common image types and limit size (5MB)
const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5MB
const ALLOWED_MIMETYPES = [
  "image/jpeg",
  "image/jpg",
  "image/png",
  "image/webp",
];

const profileUpload = multer({
  storage,
  limits: { fileSize: MAX_FILE_SIZE },
  fileFilter: (req, file, cb) => {
    console.log("Multer fileFilter - original name:", file.originalname, "mimetype:", file.mimetype);
    const mimetype = file.mimetype || "";
    if (mimetype.startsWith("image/") || mimetype === "application/octet-stream") {
      console.log("File accepted");
      return cb(null, true);
    }
    console.warn("Rejected upload mimetype:", mimetype);
    return cb(new Error(`Invalid file type: ${mimetype}`));
  },
});

// ================= ROUTES =================

// Upload profile picture
router.post(
  "/profile/picture/upload",
  (req, res, next) => {
    console.log("📍 POST /profile/picture/upload - Request received");
    console.log("Headers:", req.headers);
    next();
  },
  authMiddleware,
  (req, res, next) => {
    console.log("✅ Auth passed - User ID:", req.user?.id);
    next();
  },
  profileUpload.single("image"),
  (req, res, next) => {
    console.log("✅ File uploaded - Filename:", req.file?.filename);
    next();
  },
  profileController.uploadProfilePicture
);

// Delete profile picture
router.delete(
  "/profile/picture",
  authMiddleware,
  profileController.deleteProfilePicture
);

// Update profile picture (legacy - for setting URL directly)
router.put(
  "/profile/picture",
  authMiddleware,
  profileController.updateProfilePicture
);

// ================= ERROR HANDLING MIDDLEWARE =================
// Handle multer errors
router.use((err, req, res, next) => {
  if (err instanceof multer.MulterError) {
    console.error("MULTER ERROR:", err.code, err.message);
    
    if (err.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({
        success: false,
        error: 'File size too large. Maximum 5MB allowed.'
      });
    }
    
    if (err.code === 'LIMIT_PART_COUNT') {
      return res.status(400).json({
        success: false,
        error: 'Too many file parts.'
      });
    }
    
    return res.status(400).json({
      success: false,
      error: `Upload error: ${err.message}`
    });
  }
  
  if (err) {
    console.error("ROUTE ERROR:", err.message);
    return res.status(400).json({
      success: false,
      error: err.message || 'An error occurred'
    });
  }
  
  next();
});

module.exports = router;
