const pool = require("../config/db");

// Volunteer applies to an event
exports.applyToEvent = async (req, res) => {
  try {
    const { event_id } = req.body;
    const volunteerId = req.user.id;

    const existing = await pool.query(
      "SELECT id FROM applications WHERE event_id = $1 AND volunteer_id = $2",
      [event_id, volunteerId]
    );

    if (existing.rows.length > 0) {
      return res.status(400).json({ error: "Already applied" });
    }

    await pool.query(
      `INSERT INTO applications (event_id, volunteer_id, status)
       VALUES ($1, $2, 'pending')`,
      [event_id, volunteerId]
    );

    res.status(201).json({ message: "Applied successfully" });
  } catch (err) {
    console.error("APPLY ERROR:", err);
    res.status(500).json({ error: "Application failed" });
  }
};

// Volunteer views their applications
exports.getMyApplications = async (req, res) => {
  try {
    const volunteerId = req.user.id;

    const result = await pool.query(
      `SELECT a.*, e.title, e.location, e.event_date
       FROM applications a
       JOIN events e ON a.event_id = e.id
       WHERE a.volunteer_id = $1
       ORDER BY a.applied_at DESC`,
      [volunteerId]
    );

    res.json(result.rows);
  } catch (err) {
    console.error("GET APPLICATIONS ERROR:", err);
    res.status(500).json({ error: "Failed to fetch applications" });
  }
};
