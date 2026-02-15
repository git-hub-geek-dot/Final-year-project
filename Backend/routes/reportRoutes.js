const express = require("express");
const router = express.Router();
const authenticateToken = require("../middleware/auth");
const reportController = require("../controllers/reportController");

// Create report (user)
router.post("/reports", authenticateToken, reportController.createReport);

module.exports = router;
