const express = require("express");
const router = express.Router();
const authenticateToken = require("../middleware/auth");
const controller = require("../controllers/applicationController");

router.post("/events/:id/apply", authenticateToken, controller.applyToEvent);
router.get("/events/:id/applicants", authenticateToken, controller.viewApplicants);
router.post("/applications/:id/decision", authenticateToken, controller.decideApplication);
router.get("/my-applications", authenticateToken, controller.myApplications);

module.exports = router;
