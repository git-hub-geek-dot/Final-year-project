const express = require("express");
const router = express.Router();

const ratingController = require("../controllers/ratingController");

// Give rating
router.post("/ratings", ratingController.giveRating);

// Get ratings for a user
router.get("/ratings/:id", ratingController.getRatingsForUser);

module.exports = router;
