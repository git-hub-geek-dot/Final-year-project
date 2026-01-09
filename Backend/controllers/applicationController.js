const pool = require("../config/db");

// ================= APPLY =================
exports.applyToEvent = async (req, res) => {
  try {
    const eventId = req.params.id;
    const volunteerId = req.user.id;

    const existing = await pool.query(
      "SELECT id FROM applications WHERE event_id = $1 AND volunteer_id = $2",
      [eventId, volunteerId]
    );

    if (existing.rows.length > 0) {
      return res.status(409).json({ error: "Already applied" });
    }

    const result = await pool.query(
      `INSERT INTO applications (event_id, volunteer_id, status)
       VALUES ($1, $2, 'pending')
       RETURNING *`,
      [eventId, volunteerId]
    );

    res.status(201).json({
      success: true,
      status: result.rows[0].status,
    });
  } catch (err) {
    console.error("APPLY ERROR:", err);
    res.status(500).json({ error: err.message });
  }
};

// ================= STATUS =================
exports.getApplicationStatus = async (req, res) => {
  try {
    const eventId = req.params.id;
    const volunteerId = req.user.id;

    const result = await pool.query(
      "SELECT status FROM applications WHERE event_id = $1 AND volunteer_id = $2",
      [eventId, volunteerId]
    );

    if (result.rows.length === 0) {
      return res.json({ applied: false });
    }

    res.json({
      applied: true,
      status: result.rows[0].status,
    });
  } catch (err) {
    console.error("STATUS ERROR:", err);
    res.status(500).json({ error: err.message });
  }
};

// ================= MY APPLICATIONS =================
exports.getMyApplications = async (req, res) => {
  try {
    const volunteerId = req.user.id;

    const result = await pool.query(
      `SELECT a.*, e.title, e.location, e.event_date
       FROM applications a
       JOIN events e ON e.id = a.event_id
       WHERE a.volunteer_id = $1
       ORDER BY a.applied_at DESC`,
      [volunteerId]
    );

    res.json(result.rows);
  } catch (err) {
    console.error("MY APPLICATIONS ERROR:", err);
    res.status(500).json({ error: err.message });
  }
};
