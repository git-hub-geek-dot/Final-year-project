const express = require("express");
const router = express.Router();
const authenticateToken = require("../middleware/auth");
const controller = require("../controllers/ratingController");

router.post("/ratings", authenticateToken, controller.giveRating);
router.get("/ratings/:id", controller.getRatingsForUser);

module.exports = router;
