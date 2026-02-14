const express = require("express");
const router = express.Router();

const ratingController = require("../controllers/ratingController");
const authMiddleware = require("../middleware/auth");

// Give rating
router.post("/ratings", authMiddleware, ratingController.giveRating);

// Check if current user already rated
router.get(
	"/ratings/check",
	authMiddleware,
	ratingController.getMyRatingForEvent
);

// Get ratings for a user
router.get("/ratings/:id", authMiddleware, ratingController.getRatingsForUser);
router.get(
	"/ratings/:id/summary",
	authMiddleware,
	ratingController.getRatingSummary
);
router.get(
	"/ratings/:id/events",
	authMiddleware,
	ratingController.getEventRatings
);

module.exports = router;
