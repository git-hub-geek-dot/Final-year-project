// controllers/organiserController.js
const pool = require("../config/db");

// PUBLIC: Get organiser profile for volunteers
exports.getOrganiserPublicProfile = async (req, res) => {
  try {
    const organiserId = req.params.id;

    // organiser basic info
    const userResult = await pool.query(
      `
      SELECT id, name, email, city, role
      FROM users
      WHERE id = $1 AND role = 'organiser'
      `,
      [organiserId]
    );

    if (userResult.rows.length === 0) {
      return res.status(404).json({ error: "Organiser not found" });
    }

    // total events by organiser
    const eventsResult = await pool.query(
      `SELECT COUNT(*) FROM events WHERE organiser_id = $1`,
      [organiserId]
    );

    // total volunteers who applied to this organiser's events
    const volunteersResult = await pool.query(
      `
      SELECT COUNT(DISTINCT a.volunteer_id)
      FROM applications a
      JOIN events e ON e.id = a.event_id
      WHERE e.organiser_id = $1
      `,
      [organiserId]
    );

    res.json({
      organiser: userResult.rows[0],
      stats: {
        events: parseInt(eventsResult.rows[0].count, 10),
        volunteers: parseInt(volunteersResult.rows[0].count, 10),
        rating: null, // you can wire this later from ratings table
      },
    });
  } catch (err) {
    console.error("GET ORGANISER PROFILE ERROR:", err);
    res.status(500).json({ error: "Failed to load organiser profile" });
  }
};
