const pool = require("../config/db");

/* ============ GIVE RATING ============ */
exports.giveRating = async (req, res) => {
  try {
    const { event_id, ratee_id, score, comment } = req.body;

    if (!event_id || !ratee_id || !score) {
      return res.status(400).json({ error: "Missing required fields" });
    }

    if (score < 1 || score > 5) {
      return res.status(400).json({ error: "Score must be between 1 and 5" });
    }

    // check valid approved relation
    const relation = await pool.query(
      `SELECT a.id
       FROM applications a
       JOIN events e ON a.event_id = e.id
       WHERE a.event_id = $1
         AND a.status = 'approved'
         AND (
           (a.volunteer_id = $2 AND e.organizer_id = $3)
           OR
           (a.volunteer_id = $3 AND e.organizer_id = $2)
         )`,
      [event_id, ratee_id, req.user.id]
    );

    if (!relation.rows.length) {
      return res.status(403).json({ error: "Rating not allowed" });
    }

    // prevent duplicate rating
    const alreadyRated = await pool.query(
      `SELECT id FROM ratings
       WHERE event_id=$1 AND rater_id=$2 AND ratee_id=$3`,
      [event_id, req.user.id, ratee_id]
    );

    if (alreadyRated.rows.length) {
      return res.status(400).json({ error: "Already rated" });
    }

    await pool.query(
      `INSERT INTO ratings (event_id, rater_id, ratee_id, score, comment)
       VALUES ($1,$2,$3,$4,$5)`,
      [event_id, req.user.id, ratee_id, score, comment || null]
    );

    res.json({ message: "Rating submitted successfully" });
  } catch (err) {
    res.status(500).json({ error: "Rating failed" });
  }
};

/* ============ VIEW RATINGS FOR USER ============ */
exports.getRatingsForUser = async (req, res) => {
  try {
    const userId = req.params.id;

    const ratings = await pool.query(
      `SELECT 
         r.score,
         r.comment,
         u.name AS rater_name,
         e.title AS event_title
       FROM ratings r
       JOIN users u ON r.rater_id = u.id
       JOIN events e ON r.event_id = e.id
       WHERE r.ratee_id = $1
       ORDER BY r.created_at DESC`,
      [userId]
    );

    res.json(ratings.rows);
  } catch (err) {
    res.status(500).json({ error: "Failed to fetch ratings" });
  }
};
