const express = require("express");
const router = express.Router();

const authController = require("../controllers/authController");
const authMiddleware = require("../middleware/auth");
const { getConfigurationStatus } = require("../config/email");

router.post("/register", authController.register);
router.post("/login", authController.login);
router.post("/auth/request-otp", authController.requestOtp);
router.post("/auth/verify-otp", authController.verifyOtp);

// Check email service configuration
router.get("/email-status", (req, res) => {
  const status = getConfigurationStatus();

  let message = "Email service is configured";
  if (!status.configured) {
    if (!status.hasApiKey && !status.hasFromAddress) {
      message = "Missing SENDGRID_API_KEY and SENDGRID_FROM configuration";
    } else if (!status.hasApiKey) {
      message = "Missing SENDGRID_API_KEY configuration";
    } else if (!status.hasFromAddress) {
      message = "Missing SENDGRID_FROM configuration";
    } else {
      message = "Email service not configured";
    }
  }

  res.json({
    ...status,
    message,
  });
});
router.post("/auth/verify-phone", authController.verifyPhoneToken);
router.post("/forgot-password", authController.forgotPassword);
router.post("/reset-password", authController.resetPassword);

router.put("/profile/update", authMiddleware, authController.updateProfile);
router.get("/profile", authMiddleware, authController.getProfile);

// ✅ Only this one route (Deactivate Account)
router.put("/account/deactivate", authMiddleware, authController.deactivateAccount);

module.exports = router;
