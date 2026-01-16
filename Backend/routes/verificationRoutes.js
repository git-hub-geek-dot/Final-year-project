const express = require("express");
const authenticateToken = require("../middleware/auth");
const verificationController = require("../controllers/verificationController");

const router = express.Router();

router.post(
  "/request",
  authenticateToken,
  verificationController.submitRequest
);

router.get(
  "/status",
  authenticateToken,
  verificationController.getStatus
);

module.exports = router;
