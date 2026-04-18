const { pool } = require("../config/db");

/**
 * Evaluates and awards badges to all users based on their completed events
 * - Volunteers: badges awarded for completed event applications
 * - Organisers: badges awarded for hosted/completed events
 */
const evaluateAndAwardBadges = async () => {
  try {
    // 1) Get all badges
    const badgesRes = await pool.query(
      "SELECT id, role, threshold FROM badges"
    );
    const badges = badgesRes.rows;

    for (const badge of badges) {
      if (badge.role === "volunteer") {
        // Volunteers: count applications for events that are completed or ended by time.
        const usersRes = await pool.query(`
          SELECT u.id, COUNT(a.id)::int AS completed
          FROM users u
          JOIN applications a ON a.volunteer_id = u.id
          JOIN events e ON e.id = a.event_id
          WHERE u.role = 'volunteer'
            AND a.status IN ('approved', 'accepted', 'completed')
            AND COALESCE(a.attendance_status, 'unmarked') <> 'absent'
            AND e.status != 'deleted'
            AND (
              e.status = 'completed'
              OR NOW() >= (
                COALESCE(e.end_date, e.event_date) + COALESCE(e.end_time, TIME '23:59:59')
              )
            )
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
        // Organisers: count events that are completed or ended by time.
        const usersRes = await pool.query(`
          SELECT u.id, COUNT(e.id)::int AS completed
          FROM users u
          JOIN events e ON e.organiser_id = u.id
          WHERE u.role = 'organiser'
            AND e.status != 'deleted'
            AND (
              e.status = 'completed'
              OR NOW() >= (
                COALESCE(e.end_date, e.event_date) + COALESCE(e.end_time, TIME '23:59:59')
              )
            )
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

    console.log("Badge evaluation completed successfully");
  } catch (err) {
    console.error("BADGE EVALUATION ERROR:", err);
    throw err;
  }
};

module.exports = {
  evaluateAndAwardBadges,
};
