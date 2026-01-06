const pool = require("../config/db");

// ================= CREATE EVENT (ORGANISER) =================
exports.createEvent = async (req, res) => {
  try {
    if (req.user.role !== "organiser") {
      return res
        .status(403)
        .json({ error: "Only organisers can create events" });
    }

    const { title, description, location, event_date } = req.body;

    const event = await pool.query(
      `
      INSERT INTO events (organizer_id, title, description, location, event_date)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING *
      `,
      [req.user.id, title, description, location, event_date]
    );

    res.status(201).json(event.rows[0]);
  } catch (err) {
    console.error("CREATE EVENT ERROR:", err);
    res.status(500).json({ error: "Event creation failed" });
  }
};

// ================= ORGANISER → MY EVENTS =================
exports.getMyEvents = async (req, res) => {
  try {
    const events = await pool.query(
      `SELECT * FROM events WHERE organizer_id = $1 ORDER BY id DESC`,
      [req.user.id]
    );

    res.json(events.rows);
  } catch (err) {
    console.error("MY EVENTS ERROR:", err);
    res.status(500).json({ error: "Failed to fetch events" });
  }
};

// ================= PUBLIC EVENTS (VOLUNTEERS) =================
exports.getAllEvents = async (req, res) => {
  try {
    const result = await pool.query(
      `
      SELECT id, title, description, location, event_date
      FROM events
      ORDER BY event_date ASC
      `
    );

    res.json(result.rows);
  } catch (err) {
    console.error("GET EVENTS ERROR:", err);
    res.status(500).json({ error: "Internal server error" });
  }
};
