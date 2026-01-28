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
});

module.exports = router;
