const express = require("express");
const router = express.Router();

const authController = require("../controllers/authController");
const authMiddleware = require("../middleware/auth"); // ✅ ADD

router.post("/register", authController.register);
router.post("/login", authController.login);

// ✅ FIX: Apply middleware so req.user is available
router.put("/profile/update", authMiddleware, authController.updateProfile);
router.get("/profile", authMiddleware, authController.getProfile);

module.exports = router;