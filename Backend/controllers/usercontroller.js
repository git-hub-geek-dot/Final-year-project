const pool = require("../config/db");

const deleteUser = async (req, res) => {
  try {
    const userIdFromParams = Number(req.params.id);
    const userIdFromToken = req.user.id; // 🔐 FROM JWT

    // ❌ Invalid ID
    if (!userIdFromParams || isNaN(userIdFromParams)) {
      return res.status(400).json({
        success: false,
        message: "Invalid user ID",
      });
    }

    // 🔐 SECURITY CHECK
    if (userIdFromParams !== userIdFromToken) {
      return res.status(403).json({
        success: false,
        message: "You are not allowed to delete this account",
      });
    }

    console.log("SECURE DELETE USER:", userIdFromParams);

    const result = await pool.query(
      "UPDATE users SET status = $1 WHERE id = $2",
      ["inactive", userIdFromParams]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    return res.status(200).json({
      success: true,
      message: "Account deactivated successfully",
    });
  } catch (error) {
    console.error("Delete user error:", error);
    return res.status(500).json({
      success: false,
      message: "User deletion failed",
    });
  }
};

const getOrganiserProfile = async (req, res) => {
  try {
    const organiserId = Number(req.params.id);

    if (!organiserId || isNaN(organiserId)) {
      return res.status(400).json({ error: "Invalid organiser ID" });
    }

    const result = await pool.query(
      `
      SELECT
        u.id,
        u.name,
        u.email,
        u.city,
        u.contact_number,
        COALESCE(ev.events_count, 0) AS events_count,
        COALESCE(ve.volunteers_engaged, 0) AS volunteers_engaged
      FROM users u
      LEFT JOIN (
        SELECT organiser_id, COUNT(*)::int AS events_count
        FROM events
        WHERE status != 'deleted'
        GROUP BY organiser_id
      ) ev ON ev.organiser_id = u.id
      LEFT JOIN (
        SELECT e.organiser_id, COUNT(DISTINCT a.volunteer_id)::int AS volunteers_engaged
        FROM events e
        JOIN applications a ON a.event_id = e.id AND a.status = 'accepted'
        GROUP BY e.organiser_id
      ) ve ON ve.organiser_id = u.id
      WHERE u.id = $1 AND u.role = 'organiser'
      `,
      [organiserId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Organiser not found" });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error("Get organiser profile error:", error);
    res.status(500).json({ error: "Failed to fetch organiser profile" });
  }
};

module.exports = { deleteUser, getOrganiserProfile };
