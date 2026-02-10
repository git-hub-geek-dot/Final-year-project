const express = require("express");
const multer = require("multer");
const { storage } = require("../config/cloudinary");

const router = express.Router();

// Accept only common image types and limit size (5MB)
const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5MB

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

    // Cloudinary provides the URL directly
    const url = req.file.path; // This is the Cloudinary URL
    res.json({ url });
  } catch (err) {
    console.error("Upload error:", err);
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
