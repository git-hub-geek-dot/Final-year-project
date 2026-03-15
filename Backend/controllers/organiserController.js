// controllers/organiserController.js
const pool = require("../config/db");

// PUBLIC: Get organiser profile for volunteers
exports.getOrganiserPublicProfile = async (req, res) => {
  try {
    const organiserId = req.params.id;
    const viewerId = req.user?.id;
    const viewerRole = req.user?.role;

    // organiser basic info
    const userResult = await pool.query(
      `
      SELECT
        id,
        name,
        email,
        city,
        role,
        profile_picture_url,
        show_contact_to_volunteers,
        CASE
          WHEN show_contact_to_volunteers THEN contact_number
          ELSE NULL
        END AS contact_number
      FROM users
      WHERE id = $1 AND role = 'organiser'
      `,
      [organiserId]
    );

    if (userResult.rows.length === 0) {
      return res.status(404).json({ error: "Organiser not found" });
    }

    const organiser = { ...userResult.rows[0] };
    const organiserWantsToShare = organiser.show_contact_to_volunteers === true;
    let canViewContact = false;

    if (viewerId && Number(viewerId) === Number(organiserId)) {
      canViewContact = true;
    } else if (viewerRole === "admin") {
      canViewContact = true;
    } else if (viewerRole === "volunteer" && organiserWantsToShare) {
      const approvedViewerRes = await pool.query(
        `
        SELECT 1
        FROM applications a
        JOIN events e ON e.id = a.event_id
        WHERE e.organiser_id = $1
          AND a.volunteer_id = $2
          AND a.status IN ('approved', 'accepted', 'completed')
        LIMIT 1
        `,
        [organiserId, viewerId]
      );
      canViewContact = approvedViewerRes.rowCount > 0;
    }

    if (!canViewContact) {
      organiser.contact_number = null;
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
      organiser,
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
