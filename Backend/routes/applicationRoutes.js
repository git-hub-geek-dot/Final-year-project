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

// 🔥 Flutter: Volunteer applies to event
router.post(
  "/events/:id/apply",
  authenticateToken,
  applicationController.applyToEvent
);

// 🔥 Flutter: Volunteer checks application status
router.get(
  "/events/:id/application-status",
  authenticateToken,
  applicationController.getApplicationStatus
);

// 🔥 Flutter: Organiser views applications for an event
router.get(
  "/events/:id/applications",
  authenticateToken,
  applicationController.getEventApplications
);

/* ================= NEW ROUTES (SAFE ADDITIONS) ================= */

// ✅ NEW: Get single application details (for ViewApplicationScreen)
router.get(
  "/applications/:id",
  authenticateToken,
  applicationController.getApplicationById
);

// ✅ NEW: Update application status (Approve / Reject)
router.put(
  "/applications/:id/status",
  authenticateToken,
  applicationController.updateApplicationStatus
);

module.exports = router;
