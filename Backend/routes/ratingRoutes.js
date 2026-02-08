const express = require("express");
const router = express.Router();

const ratingController = require("../controllers/ratingController");
const authMiddleware = require("../middleware/auth");

// Give rating
router.post("/ratings", authMiddleware, ratingController.giveRating);

// Get ratings for a user
router.get("/ratings/:id", authMiddleware, ratingController.getRatingsForUser);
router.get(
	"/ratings/:id/summary",
	authMiddleware,
	ratingController.getRatingSummary
);

module.exports = router;
