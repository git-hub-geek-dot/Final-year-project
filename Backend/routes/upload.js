const express = require("express");
const multer = require("multer");
const path = require("path");
const fs = require("fs");
const { storage } = require("../config/cloudinary");

const router = express.Router();

// Accept only common image types and limit size (5MB)
const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5MB

const hasCloudinaryConfig =
  Boolean(process.env.CLOUDINARY_CLOUD_NAME) &&
  Boolean(process.env.CLOUDINARY_API_KEY) &&
  Boolean(process.env.CLOUDINARY_API_SECRET);

const uploadDir = path.join(__dirname, "..", "uploads");
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const diskStorage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadDir),
  filename: (_req, file, cb) => {
    const original = file.originalname || "image.jpg";
    const ext = path.extname(original) || ".jpg";
    cb(null, `upload_${Date.now()}_${Math.round(Math.random() * 1e9)}${ext}`);
  },
});

const upload = multer({
  storage: hasCloudinaryConfig ? storage : diskStorage,
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

    const protocol = req.headers["x-forwarded-proto"] || req.protocol;
    const host = req.get("host");

    const url = hasCloudinaryConfig
      ? req.file.path
      : `${protocol}://${host}/uploads/${req.file.filename}`;

    console.log("Upload successful! URL:", url);
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
