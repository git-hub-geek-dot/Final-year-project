const express = require("express");
const router = express.Router();

const authController = require("../controllers/authController");
const authMiddleware = require("../middleware/auth");

router.post("/register", authController.register);
router.post("/login", authController.login);
router.post("/auth/request-otp", authController.requestOtp);
router.post("/auth/verify-otp", authController.verifyOtp);
router.post("/auth/verify-phone", authController.verifyPhoneToken);
router.post("/forgot-password", authController.forgotPassword);
router.post("/reset-password", authController.resetPassword);

router.put("/profile/update", authMiddleware, authController.updateProfile);
router.get("/profile", authMiddleware, authController.getProfile);

// ✅ Only this one route (Deactivate Account)
router.put("/account/deactivate", authMiddleware, authController.deactivateAccount);

module.exports = router;