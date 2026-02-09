const pool = require("../config/db");

const giveRating = async (req, res) => {
  try {
    const raterId = req.user.id;
    const raterRole = req.user.role;
    const { event_id, ratee_id, score, comment } = req.body;

    if (!event_id || !ratee_id || !score) {
      return res.status(400).json({ error: "Missing required fields" });
    }

    if (raterId === ratee_id) {
      return res.status(400).json({ error: "Cannot rate yourself" });
    }

    const scoreValue = parseInt(score, 10);
    if (Number.isNaN(scoreValue) || scoreValue < 1 || scoreValue > 5) {
      return res.status(400).json({ error: "Score must be 1-5" });
    }

    const eventResult = await pool.query(
      `
      SELECT
        id,
        organiser_id,
        status,
        (
          status NOT IN ('draft', 'deleted')
          AND (
            status = 'completed'
            OR NOW() >= (
              COALESCE(end_date, event_date) + COALESCE(end_time, TIME '23:59:59')
            )
          )
        ) AS is_completed
      FROM events
      WHERE id = $1
      `,
      [event_id]
    );
    if (eventResult.rows.length === 0) {
      return res.status(404).json({ error: "Event not found" });
    }

    const event = eventResult.rows[0];
    if (!event.is_completed) {
      return res.status(400).json({ error: "Event not completed" });
    }

    if (raterRole === "volunteer") {
      if (ratee_id !== event.organiser_id) {
        return res.status(400).json({ error: "Invalid organiser" });
      }

      const appResult = await pool.query(
        `
        SELECT id
        FROM applications
        WHERE event_id = $1 AND volunteer_id = $2
          AND status IN ('accepted', 'completed')
        `,
        [event_id, raterId]
      );
      if (appResult.rows.length === 0) {
        return res.status(403).json({ error: "Not eligible to rate" });
      }
    } else if (raterRole === "organiser") {
      if (event.organiser_id !== raterId) {
        return res.status(403).json({ error: "Not your event" });
      }

      const appResult = await pool.query(
        `
        SELECT id
        FROM applications
        WHERE event_id = $1 AND volunteer_id = $2
          AND status IN ('accepted', 'completed')
        `,
        [event_id, ratee_id]
      );
      if (appResult.rows.length === 0) {
        return res.status(403).json({ error: "Volunteer not eligible" });
      }
    } else {
      return res.status(403).json({ error: "Role not allowed" });
    }

    const existing = await pool.query(
      `
      SELECT id
      FROM ratings
      WHERE event_id = $1 AND rater_id = $2 AND ratee_id = $3
      `,
      [event_id, raterId, ratee_id]
    );

    if (existing.rows.length > 0) {
      return res.status(409).json({ error: "Rating already submitted" });
    }

    await pool.query(
      `
      INSERT INTO ratings (event_id, rater_id, ratee_id, score, comment)
      VALUES ($1, $2, $3, $4, $5)
      `,
      [event_id, raterId, ratee_id, scoreValue, comment || null]
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
      `
      SELECT r.id, r.event_id, r.rater_id, r.ratee_id, r.score, r.comment, r.created_at,
             u.name AS rater_name
      FROM ratings r
      LEFT JOIN users u ON u.id = r.rater_id
      WHERE r.ratee_id = $1
      ORDER BY r.created_at DESC
      `,
      [userId]
    );

    res.json(ratings.rows);
  } catch (err) {
    console.error("GET RATINGS ERROR:", err);
    res.status(500).json({ error: "Failed to fetch ratings" });
  }
};

const getRatingSummary = async (req, res) => {
  try {
    const userId = req.params.id;

    const result = await pool.query(
      `
      SELECT
        COALESCE(AVG(score), 0) AS avg_rating,
        COUNT(*)::int AS review_count
      FROM ratings
      WHERE ratee_id = $1
      `,
      [userId]
    );

    const row = result.rows[0];

    res.json({
      rating: Number(row.avg_rating).toFixed(1),
      review_count: row.review_count,
    });
  } catch (err) {
    console.error("GET RATING SUMMARY ERROR:", err);
    res.status(500).json({ error: "Failed to fetch rating summary" });
  }
};

module.exports = {
  giveRating,
  getRatingsForUser,
  getRatingSummary,
};
