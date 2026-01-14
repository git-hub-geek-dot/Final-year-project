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
      `
      INSERT INTO applications (event_id, volunteer_id, status)
      VALUES ($1, $2, 'pending')
      RETURNING id, status
      `,
      [eventId, volunteerId]
    );

    res.status(201).json({
      success: true,
      application_id: result.rows[0].id,
      status: result.rows[0].status,
    });
  } catch (err) {
    console.error("APPLY ERROR:", err);
    res.status(500).json({ error: "Failed to apply" });
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
    res.status(500).json({ error: "Failed to get status" });
  }
};

// ================= EVENT APPLICATIONS (ORGANISER) =================
exports.getEventApplications = async (req, res) => {
  try {
    const eventId = req.params.id;

    const result = await pool.query(
      `
      SELECT a.id, u.name, u.city, a.status
      FROM applications a
      JOIN users u ON u.id = a.volunteer_id
      WHERE a.event_id = $1
      ORDER BY a.created_at DESC
      `,
      [eventId]
    );

    res.json(result.rows);
  } catch (err) {
    console.error("GET APPLICATIONS ERROR:", err);
    res.status(500).json({ error: "Failed to fetch applications" });
  }
};

// ================= MY APPLICATIONS (VOLUNTEER) =================
exports.getMyApplications = async (req, res) => {
  try {
    const volunteerId = req.user.id;

    const result = await pool.query(
      `
      SELECT a.id, a.status, e.title, e.location, e.event_date
      FROM applications a
      JOIN events e ON e.id = a.event_id
      WHERE a.volunteer_id = $1
      ORDER BY a.created_at DESC
      `,
      [volunteerId]
    );

    res.json(result.rows);
  } catch (err) {
    console.error("MY APPLICATIONS ERROR:", err);
    res.status(500).json({ error: "Failed to fetch my applications" });
  }
};
