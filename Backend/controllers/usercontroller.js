const pool = require("../config/db");

// ================= DELETE USER =================
const deleteUser = async (req, res) => {
  try {
    const userIdFromParams = Number(req.params.id);
    const userIdFromToken = req.user.id;

    if (!userIdFromParams || isNaN(userIdFromParams)) {
      return res.status(400).json({
        success: false,
        message: "Invalid user ID",
      });
    }

    if (userIdFromParams !== userIdFromToken) {
      return res.status(403).json({
        success: false,
        message: "You are not allowed to delete this account",
      });
    }

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

// ================= GET ORGANISER PROFILE =================
const getOrganiserProfile = async (req, res) => {
  try {
    const organiserId = Number(req.params.id);

    if (!organiserId || isNaN(organiserId)) {
      return res.status(400).json({ error: "Invalid organiser ID" });
    }

    const result = await pool.query(
      `
      SELECT
        id,
        name,
        email,
        city,
        contact_number,
        government_id,
        profile_picture_url
      FROM users
      WHERE id = $1 AND role = 'organiser'
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

// ================= UPDATE USER PROFILE =================
const updateUser = async (req, res) => {
  try {
    const userIdFromParams = Number(req.params.id);
    const userIdFromToken = req.user.id;

    if (!userIdFromParams || isNaN(userIdFromParams)) {
      return res.status(400).json({
        success: false,
        message: "Invalid user ID",
      });
    }

    if (userIdFromParams !== userIdFromToken) {
      return res.status(403).json({
        success: false,
        message: "Not authorized",
      });
    }

    const {
      name,
      email,
      city,
      contact_number,
      government_id,
    } = req.body;

    const result = await pool.query(
      `
      UPDATE users
      SET
        name = $1,
        email = $2,
        city = $3,
        contact_number = $4,
        government_id = $5
      WHERE id = $6
      RETURNING id, name, email, city, contact_number, government_id
      `,
      [
        name,
        email,
        city,
        contact_number,
        government_id || null,
        userIdFromParams,
      ]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    return res.status(200).json({
      success: true,
      message: "Profile updated successfully",
      user: result.rows[0],
    });
  } catch (error) {
    console.error("Update user error:", error);
    return res.status(500).json({
      success: false,
      message: "Profile update failed",
    });
  }
};

// ================= VOLUNTEER DASHBOARD =================
const getVolunteerDashboard = async (req, res) => {
  try {
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: "Unauthorized",
      });
    }

    const [
      applicationsCount,
      approvedCount,
      ratingAvg,
      totalHours,
      upcomingEvent,
      preferences,
      activity,
    ] = await Promise.all([
      pool.query(
        `SELECT COUNT(*)::int AS total
         FROM applications
         WHERE volunteer_id = $1`,
        [userId]
      ),
      pool.query(
        `SELECT COUNT(*)::int AS total
         FROM applications
         WHERE volunteer_id = $1 AND status IN ('approved', 'accepted')`,
        [userId]
      ),
      pool.query(
        `SELECT COALESCE(AVG(score), 0)::numeric(10,2) AS avg_rating
         FROM ratings
         WHERE ratee_id = $1`,
        [userId]
      ),
      pool.query(
        `SELECT COALESCE(SUM(EXTRACT(EPOCH FROM (e.end_time - e.start_time)))/3600, 0) AS hours
         FROM applications a
         JOIN events e ON e.id = a.event_id
         WHERE a.volunteer_id = $1
           AND a.status IN ('approved', 'accepted')
           AND e.start_time IS NOT NULL
           AND e.end_time IS NOT NULL`,
        [userId]
      ),
      pool.query(
        `SELECT e.id, e.title, e.event_date, e.start_time, e.location
         FROM applications a
         JOIN events e ON e.id = a.event_id
         WHERE a.volunteer_id = $1
           AND a.status IN ('approved', 'accepted')
           AND e.event_date >= CURRENT_DATE
           AND e.status != 'deleted'
         ORDER BY e.event_date ASC
         LIMIT 1`,
        [userId]
      ),
      pool.query(
        `SELECT skills, interests
         FROM volunteer_preferences
         WHERE user_id = $1`,
        [userId]
      ),
      pool.query(
        `SELECT e.title, a.applied_at, a.status
         FROM applications a
         LEFT JOIN events e ON e.id = a.event_id
         WHERE a.volunteer_id = $1
         ORDER BY a.applied_at DESC
         LIMIT 3`,
        [userId]
      ),
    ]);

    let prefRow = preferences.rows[0];
    if (!prefRow) {
      const inserted = await pool.query(
        `INSERT INTO volunteer_preferences (user_id)
         VALUES ($1)
         RETURNING skills, interests`,
        [userId]
      );
      prefRow = inserted.rows[0];
    }

    return res.status(200).json({
      success: true,
      impact: {
        hours: Number(totalHours.rows[0]?.hours || 0).toFixed(1),
        events: approvedCount.rows[0]?.total || 0,
        rating: Number(ratingAvg.rows[0]?.avg_rating || 0).toFixed(1),
        applications: applicationsCount.rows[0]?.total || 0,
      },
      upcomingEvent: upcomingEvent.rows[0] || null,
      skills: prefRow.skills || [],
      interests: prefRow.interests || [],
      activity: activity.rows.map((row) => ({
        title: row.title || "Event",
        status: row.status || "pending",
        appliedAt: row.applied_at,
      })),
    });
  } catch (error) {
    console.error("Volunteer dashboard error:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch volunteer dashboard",
    });
  }
};

// ================= UPDATE VOLUNTEER PREFERENCES =================
const updateVolunteerPreferences = async (req, res) => {
  try {
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: "Unauthorized",
      });
    }

    const { skills, interests } = req.body;

    const normalizeList = (value) => {
      if (Array.isArray(value)) return value.filter(Boolean);
      if (typeof value === "string") {
        return value
          .split(",")
          .map((item) => item.trim())
          .filter((item) => item.length > 0);
      }
      return [];
    };

    const normalizedSkills = normalizeList(skills);
    const normalizedInterests = normalizeList(interests);

    const result = await pool.query(
      `
      INSERT INTO volunteer_preferences (user_id, skills, interests)
      VALUES ($1, $2, $3)
      ON CONFLICT (user_id)
      DO UPDATE SET
        skills = EXCLUDED.skills,
        interests = EXCLUDED.interests
      RETURNING skills, interests
      `,
      [
        userId,
        normalizedSkills,
        normalizedInterests,
      ]
    );

    return res.status(200).json({
      success: true,
      preferences: result.rows[0],
    });
  } catch (error) {
    console.error("Update volunteer preferences error:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to update preferences",
    });
  }
};

// ================= MY BADGES (AUTH USER) =================
const getMyBadges = async (req, res) => {
  try {
    const userId = req.user?.id;
    const role = req.user?.role;

    if (!userId || !role) {
      return res.status(401).json({
        success: false,
        message: "Unauthorized",
      });
    }

    let completedCountResult;

    if (role === "volunteer") {
      completedCountResult = await pool.query(
        `
        SELECT COUNT(a.id)::int AS completed_count
        FROM applications a
        JOIN events e ON e.id = a.event_id
        WHERE a.volunteer_id = $1
          AND a.status IN ('approved', 'accepted', 'completed')
          AND COALESCE(a.attendance_status, 'unmarked') <> 'absent'
          AND e.status != 'deleted'
          AND (
            e.status = 'completed'
            OR NOW() >= (
              COALESCE(e.end_date, e.event_date)
              + COALESCE(e.end_time, TIME '23:59:59')
            )
          )
        `,
        [userId]
      );
    } else if (role === "organiser") {
      completedCountResult = await pool.query(
        `
        SELECT COUNT(e.id)::int AS completed_count
        FROM events e
        WHERE e.organiser_id = $1
          AND e.status != 'deleted'
          AND (
            e.status = 'completed'
            OR NOW() >= (
              COALESCE(e.end_date, e.event_date)
              + COALESCE(e.end_time, TIME '23:59:59')
            )
          )
        `,
        [userId]
      );
    } else {
      return res.json({
        role,
        completedCount: 0,
        progress: 0,
        currentBadge: null,
        nextBadge: null,
        badges: [],
      });
    }

    const completedCount = completedCountResult.rows[0]?.completed_count ?? 0;

    // Keep earned badge rows up to date for this user and role.
    await pool.query(
      `
      INSERT INTO user_badges (user_id, badge_id)
      SELECT $1, b.id
      FROM badges b
      WHERE b.role = $2
        AND b.threshold <= $3
      ON CONFLICT DO NOTHING
      `,
      [userId, role, completedCount]
    );

    const allBadgesResult = await pool.query(
      `
      SELECT id, name, description, threshold
      FROM badges
      WHERE role = $1
      ORDER BY threshold ASC
      `,
      [role]
    );

    const earnedResult = await pool.query(
      `
      SELECT b.id, b.name, b.description, b.threshold, ub.awarded_at
      FROM user_badges ub
      JOIN badges b ON b.id = ub.badge_id
      WHERE ub.user_id = $1
        AND b.role = $2
      ORDER BY b.threshold ASC
      `,
      [userId, role]
    );

    const allBadges = allBadgesResult.rows;
    const earnedBadges = earnedResult.rows;
    const earnedSet = new Set(earnedBadges.map((b) => b.id));

    const badges = allBadges.map((badge) => ({
      ...badge,
      earned: earnedSet.has(badge.id),
    }));

    const currentBadge =
      earnedBadges.length > 0 ? earnedBadges[earnedBadges.length - 1] : null;
    const nextBadge =
      allBadges.find((badge) => badge.threshold > completedCount) || null;
    const progress = nextBadge
      ? Math.min(completedCount / nextBadge.threshold, 1)
      : 1;

    return res.json({
      role,
      completedCount,
      progress,
      currentBadge,
      nextBadge,
      badges,
    });
  } catch (error) {
    console.error("Get my badges error:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch badges",
    });
  }
};

module.exports = {
  deleteUser,
  getOrganiserProfile,
  updateUser,
  getVolunteerDashboard,
  updateVolunteerPreferences,
  getMyBadges,
};
