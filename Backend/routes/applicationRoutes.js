const express = require("express");
const router = express.Router();

const authenticateToken = require("../middleware/auth");
const applicationController = require("../controllers/applicationController");

/* ================= EXISTING ROUTES (UNCHANGED) ================= */

// Volunteer applies (OLD — kept to avoid breaking anything)
router.post(
  "/applications",
  authenticateToken,
  applicationController.applyToEvent
);

// Volunteer views own applications
router.get(
  "/applications/my",
  authenticateToken,
  applicationController.getMyApplications
);

/* ================= REQUIRED ROUTES (ADDED) ================= */

// 🔥 REQUIRED: Flutter Apply API
router.post(
  "/events/:id/apply",
  authenticateToken,
  applicationController.applyToEvent
);

// 🔥 REQUIRED: Flutter Application Status API
router.get(
  "/events/:id/application-status",
  authenticateToken,
  applicationController.getApplicationStatus
);

module.exports = router;
