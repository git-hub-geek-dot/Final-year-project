const express = require("express");
const router = express.Router();

const authMiddleware = require("../middleware/auth");
const adminOnly = require("../middleware/admin");
const notificationController = require("../controllers/notificationController");

router.post(
  "/notifications/register-token",
  authMiddleware,
  notificationController.registerDeviceToken
);

router.post(
  "/notifications/send-test",
  authMiddleware,
  adminOnly,
  notificationController.sendTestNotification
);

module.exports = router;
