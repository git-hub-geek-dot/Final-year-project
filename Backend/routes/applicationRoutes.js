const express = require("express");
const router = express.Router();

const authenticateToken = require("../middleware/auth");
const applicationController = require("../controllers/applicationController");

// Volunteer applies to event
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

module.exports = router;
