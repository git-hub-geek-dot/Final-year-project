const express = require("express");
const multer = require("multer");
const path = require("path");
const { storage: cloudinaryStorage } = require("../config/cloudinary");

const router = express.Router();

// Accept only common image types and limit size (5MB)
const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5MB

// Check if Cloudinary is configured
const isCloudinaryConfigured = process.env.CLOUDINARY_CLOUD_NAME && process.env.CLOUDINARY_API_KEY && process.env.CLOUDINARY_API_SECRET;

// Use Cloudinary if configured, otherwise local disk storage
let storage;
if (isCloudinaryConfigured) {
  storage = cloudinaryStorage;
} else {
  storage = multer.diskStorage({
    destination: (req, file, cb) => {
      cb(null, 'uploads/'); // Save to uploads folder
    },
    filename: (req, file, cb) => {
      const uniqueName = `upload_${Date.now()}_${Math.random().toString(36).substring(2, 15)}${path.extname(file.originalname)}`;
      cb(null, uniqueName);
    },
  });
}

const upload = multer({
  storage,
  limits: { fileSize: MAX_FILE_SIZE },
  fileFilter: (req, file, cb) => {
    const mimetype = file.mimetype || "";
    // Accept common image/* mimetypes; fall back to application/octet-stream
    if (mimetype.startsWith("image/") || mimetype === "application/octet-stream") {
      return cb(null, true);
    }
    console.warn("Rejected upload mimetype:", mimetype);
    return cb(new Error(`Invalid file type: ${mimetype}`));
  },
});

router.post("/upload", upload.single("image"), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: "No file uploaded" });
    }

    let url;
    if (isCloudinaryConfigured) {
      // Cloudinary provides the URL directly
      url = req.file.path;
      console.log('Upload successful! Cloudinary URL:', url);
    } else {
      // Local storage: construct URL
      url = `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`;
      console.log('Upload successful! Local URL:', url);
    }

    res.json({ url });
  } catch (err) {
    console.error("Upload error:", err);
    console.error("Error details:", err.message);

    // Check if it's a Cloudinary configuration error
    if (err.message && err.message.includes('Invalid Signature')) {
      return res.status(500).json({
        error: "Cloudinary configuration error. Please check your API credentials.",
        details: "Invalid API secret or key. Verify your Cloudinary environment variables."
      });
    }

    return res.status(400).json({ error: "Invalid image or upload failed" });
  }
});

// Upload error handler (returns JSON for multer/file-filter errors)
router.use((err, req, res, next) => {
  if (!err) return next();
  console.error("Upload route error:", err.message || err);
  return res.status(400).json({ error: err.message || "Upload error" });
});

module.exports = router;
