const pool = require("../config/db");

// ================= GET ALL USERS =================
const getUsers = async (req, res) => {
  try {
    const users = await pool.query(
      "SELECT id, name, email, role, status, created_at FROM users ORDER BY id DESC"
    );
    res.json(users.rows);
  } catch (err) {
    console.error("GET USERS ERROR:", err);
    res.status(500).json({ error: "Failed to fetch users" });
  }
};

// ================= GET ALL EVENTS =================
const getEvents = async (req, res) => {
  try {
    const events = await pool.query(
      `SELECT e.*, u.name AS organizer_name
       FROM events e
       JOIN users u ON e.organiser_id = u.id
       ORDER BY e.id DESC`
    );
    res.json(events.rows);
  } catch (err) {
    console.error("GET EVENTS ERROR:", err);
    res.status(500).json({ error: "Failed to fetch events" });
  }
};

// ================= GET ALL APPLICATIONS =================
const getApplications = async (req, res) => {
  try {
    const apps = await pool.query(
      `SELECT 
         a.id,
         a.status,
         u.name AS volunteer_name,
         u.email AS volunteer_email,
         e.title AS event_title
       FROM applications a
       JOIN users u ON a.volunteer_id = u.id
       JOIN events e ON a.event_id = e.id
       ORDER BY a.applied_at DESC`
    );

    res.json(apps.rows);
  } catch (err) {
    console.error("GET APPLICATIONS ERROR:", err);
    res.status(500).json({ error: "Failed to fetch applications" });
  }
};

const getStats = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT
        (SELECT COUNT(*) FROM users) AS total_users,
        (SELECT COUNT(*) FROM events) AS total_events,
        (SELECT COUNT(*) FROM events WHERE status = 'open') AS active_events,
        (SELECT COUNT(*) FROM applications) AS total_applications
    `);

    res.json({
      totalUsers: parseInt(result.rows[0].total_users),
      totalEvents: parseInt(result.rows[0].total_events),
      activeEvents: parseInt(result.rows[0].active_events),
      totalApplications: parseInt(result.rows[0].total_applications),
    });
  } catch (err) {
    res.status(500).json({ error: "Stats fetch failed" });
  }
 };

 const updateUserStatus = async (req, res) => {
  try {
    const userId = req.params.id;
    const { status } = req.body;

    if (!["active", "blocked"].includes(status)) {
      return res.status(400).json({ error: "Invalid status" });
    }

    const result = await pool.query(
      "UPDATE users SET status = $1 WHERE id = $2 RETURNING id, status",
      [status, userId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: "User not found" });
    }

    res.json({
      message: "User status updated",
      user: result.rows[0],
    });
  } catch (err) {
    console.error("UPDATE USER STATUS ERROR:", err);
    res.status(500).json({ error: "Failed to update user status" });
  }};


  const cancelApplication = async (req, res) => {
  try {
    const appId = req.params.id;

    const result = await pool.query(
      "UPDATE applications SET status = 'cancelled' WHERE id = $1",
      [appId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: "Application not found" });
    }

    res.json({ message: "Application cancelled" });
  } catch (err) {
    console.error("CANCEL APPLICATION ERROR:", err);
    res.status(500).json({ error: "Failed to cancel application" });
  }
};

const deleteEvent = async (req, res) => {
  try {
    const eventId = req.params.id;

    const result = await pool.query(
  "UPDATE events SET status = 'deleted' WHERE id = $1",
  [eventId]
);


    if (result.rowCount === 0) {
      return res.status(404).json({ error: "Event not found" });
    }

    res.json({ message: "Event deleted" });
  } catch (err) {
    console.error("DELETE EVENT ERROR:", err);
    res.status(500).json({ error: "Failed to delete event" });
  }
};

// Volunteer leaderboard
const getVolunteerLeaderboard = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT 
        u.id,
        u.name,
        COUNT(a.id) AS completed_events
      FROM users u
      JOIN applications a ON a.volunteer_id = u.id
      WHERE u.role = 'volunteer'
        AND a.status = 'completed'
      GROUP BY u.id
      ORDER BY completed_events DESC
    `);

    res.json(result.rows);
  } catch (err) {
    console.error("VOLUNTEER LEADERBOARD ERROR:", err);
    res.status(500).json({ error: "Failed to load volunteer leaderboard" });
  }
};

// Organiser leaderboard
const getOrganiserLeaderboard = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT 
        u.id,
        u.name,
        COUNT(e.id) AS completed_events
      FROM users u
      JOIN events e ON e.organiser_id = u.id
      WHERE u.role = 'organiser'
        AND e.status = 'completed'
      GROUP BY u.id
      ORDER BY completed_events DESC
    `);

    res.json(result.rows);
  } catch (err) {
    console.error("ORGANISER LEADERBOARD ERROR:", err);
    res.status(500).json({ error: "Failed to load organiser leaderboard" });
  }
};
 const evaluateBadges = async (req, res) => {
  try {
    // 1) Get all badges
    const badgesRes = await pool.query(
      "SELECT id, role, threshold FROM badges"
    );
    const badges = badgesRes.rows;

    for (const badge of badges) {
      if (badge.role === "volunteer") {
        // Volunteers: count completed applications
        const usersRes = await pool.query(`
          SELECT u.id, COUNT(a.id)::int AS completed
          FROM users u
          JOIN applications a ON a.volunteer_id = u.id
          WHERE u.role = 'volunteer'
            AND a.status = 'completed'
          GROUP BY u.id
        `);

        for (const u of usersRes.rows) {
          if (u.completed >= badge.threshold) {
            await pool.query(
              `
              INSERT INTO user_badges (user_id, badge_id)
              VALUES ($1, $2)
              ON CONFLICT DO NOTHING
              `,
              [u.id, badge.id]
            );
          }
        }
      }

      if (badge.role === "organiser") {
        // Organisers: count completed events
        const usersRes = await pool.query(`
          SELECT u.id, COUNT(e.id)::int AS completed
          FROM users u
          JOIN events e ON e.organiser_id = u.id
          WHERE u.role = 'organiser'
            AND e.status = 'completed'
          GROUP BY u.id
        `);

        for (const u of usersRes.rows) {
          if (u.completed >= badge.threshold) {
            await pool.query(
              `
              INSERT INTO user_badges (user_id, badge_id)
              VALUES ($1, $2)
              ON CONFLICT DO NOTHING
              `,
              [u.id, badge.id]
            );
          }
        }
      }
    }

    res.json({ message: "Badges evaluated and awarded" });
  } catch (err) {
    console.error("EVALUATE BADGES ERROR:", err);
    res.status(500).json({ error: "Failed to evaluate badges" });
  }
};

const getBadges = async (req, res) => {
  try {
    const result = await pool.query(
      "SELECT * FROM badges ORDER BY role, threshold"
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: "Failed to load badges" });
  }
};

const createBadge = async (req, res) => {
  try {
    const { name, description, role, threshold } = req.body;

    await pool.query(
      `INSERT INTO badges (name, description, role, threshold)
       VALUES ($1, $2, $3, $4)`,
      [name, description, role, threshold]
    );

    res.status(201).json({ message: "Badge created" });
  } catch (err) {
    res.status(500).json({ error: "Failed to create badge" });
  }
};

const getUserBadges = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT 
        ub.user_id,
        b.name
      FROM user_badges ub
      JOIN badges b ON b.id = ub.badge_id
    `);

    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: "Failed to load user badges" });
  }
};






module.exports = {
  getUsers,
  getEvents,
  getApplications,
  getStats,
  updateUserStatus,
  cancelApplication,
  deleteEvent,
  getVolunteerLeaderboard,
  getOrganiserLeaderboard,
  evaluateBadges,
  getBadges,
  createBadge,
  getUserBadges,
};
