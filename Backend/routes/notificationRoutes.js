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

router.get(
  "/notifications/unread-count",
  authMiddleware,
  notificationController.getUnreadCount
);

router.get(
  "/notifications",
  authMiddleware,
  notificationController.getNotifications
);

router.patch(
  "/notifications/:id/read",
  authMiddleware,
  notificationController.markNotificationRead
);

router.post(
  "/notifications/read-all",
  authMiddleware,
  notificationController.markAllRead
);

router.delete(
  "/notifications",
  authMiddleware,
  notificationController.clearNotifications
);

router.post(
  "/notifications/send-test",
  authMiddleware,
  adminOnly,
  notificationController.sendTestNotification
);

module.exports = router;
