const pool = require("../config/db");

/* ================= CREATE EVENT (Organizer) ================= */
exports.createEvent = async (req, res) => {
  try {
    if (req.user.role !== "organizer") {
      return res.status(403).json({ error: "Only organizers can create events" });
    }

    const { title, description, location, event_date } = req.body;

    if (!title || !event_date) {
      return res.status(400).json({ error: "Title and date required" });
    }

    const event = await pool.query(
      `INSERT INTO events (organizer_id, title, description, location, event_date)
       VALUES ($1,$2,$3,$4,$5)
       RETURNING *`,
      [req.user.id, title, description, location, event_date]
    );

    res.json(event.rows[0]);
  } catch (err) {
    res.status(500).json({ error: "Event creation failed" });
  }
};

/* ================= GET ALL EVENTS (Public) ================= */
exports.getAllEvents = async (req, res) => {
  try {
    const events = await pool.query(
      `SELECT e.*, u.name AS organizer_name
       FROM events e
       JOIN users u ON e.organizer_id = u.id
       ORDER BY e.id DESC`
    );

    res.json(events.rows);
  } catch (err) {
    res.status(500).json({ error: "Failed to fetch events" });
  }
};
