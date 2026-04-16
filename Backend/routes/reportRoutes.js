const express = require("express");
const router = express.Router();
const authenticateToken = require("../middleware/auth");
const reportController = require("../controllers/reportController");

// Create report (user)
router.post("/reports", authenticateToken, reportController.createReport);
router.get("/reports/me", authenticateToken, reportController.getMyReports);

module.exports = router;
