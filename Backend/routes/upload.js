const express = require("express");
const multer = require("multer");
const path = require("path");
const fs = require("fs");

const router = express.Router();

// Ensure uploads folder exists
const uploadDir = path.join(__dirname, "..", "uploads");
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir);
}

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, Date.now() + ext);
  },
});

<<<<<<< HEAD
const upload = multer({ 
  storage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB limit
});

router.post("/upload", upload.single("image"), (req, res) => {
  console.log("Upload request received");
  console.log("File object:", req.file);
  console.log("Body:", req.body);
  
  if (!req.file) {
    console.error("No file received in request");
    return res.status(400).json({ error: "No file uploaded" });
  }

  console.log("File uploaded:", req.file.filename);
  const url = `${req.protocol}://${req.get("host")}/uploads/${req.file.filename}`;
  res.json({ url });
=======
// Accept only common image types and limit size (5MB)
const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5MB
const ALLOWED_MIMETYPES = [
  "image/jpeg",
  "image/jpg",
  "image/png",
  "image/webp",
];

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
>>>>>>> 06e37bfcd58b7a8cd746d5f3ef0e239616c2b0f2
});

const sharp = require("sharp");

router.post("/upload", upload.single("image"), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: "No file uploaded" });
    }

    const filepath = path.join(uploadDir, req.file.filename);

    // Use sharp to validate and re-encode image (strip metadata)
    const safeFilename = `${Date.now()}-safe.jpg`;
    const safePath = path.join(uploadDir, safeFilename);

    await sharp(filepath)
      .rotate() // auto-rotate based on EXIF
      .jpeg({ quality: 85 })
      .toFile(safePath);

    // remove original uploaded file
    try { fs.unlinkSync(filepath); } catch (e) { /* ignore */ }

    const url = `${req.protocol}://${req.get("host")}/uploads/${safeFilename}`;
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
