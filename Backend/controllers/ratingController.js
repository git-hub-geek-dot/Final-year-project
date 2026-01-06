const pool = require("../config/db");

const giveRating = async (req, res) => {
  try {
    const { rated_user_id, rating, comment } = req.body;

    if (!rated_user_id || !rating) {
      return res.status(400).json({ error: "Missing required fields" });
    }

    await pool.query(
      `INSERT INTO ratings (rated_user_id, rating, comment)
       VALUES ($1, $2, $3)`,
      [rated_user_id, rating, comment]
    );

    res.status(201).json({ message: "Rating submitted" });
  } catch (err) {
    console.error("GIVE RATING ERROR:", err);
    res.status(500).json({ error: "Failed to submit rating" });
  }
};

const getRatingsForUser = async (req, res) => {
  try {
    const userId = req.params.id;

    const ratings = await pool.query(
      `SELECT * FROM ratings WHERE rated_user_id = $1`,
      [userId]
    );

    res.json(ratings.rows);
  } catch (err) {
    console.error("GET RATINGS ERROR:", err);
    res.status(500).json({ error: "Failed to fetch ratings" });
  }
};

module.exports = {
  giveRating,
  getRatingsForUser,
};
