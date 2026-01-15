const express = require("express");
const router = express.Router();

const authMiddleware = require("../middleware/auth");
const authController = require("../controllers/authController");

// deactivate
router.put("/account/deactivate", authMiddleware, authController.deactivateAccount);

module.exports = router;