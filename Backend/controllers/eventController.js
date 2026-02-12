const pool = require("../config/db");
const { notifyUsers } = require("../services/notificationService");

/*
EVENTS TABLE (SOURCE OF TRUTH)

id
organiser_id
title
description
location
event_date
category
slots_total
slots_filled
status          -- 'draft' | 'open' | 'closed' | 'completed' | 'deleted'
created_at
*/

// =======================================================
// CREATE EVENT (ORGANISER)
// =======================================================
exports.createEvent = async (req, res) => {
  try {
    if (req.user.role !== "organiser") {
      return res.status(403).json({
        error: "Only organisers can create events",
      });
    }

    const {
      title,
      description,
      location,
      event_date,
      end_date,
      volunteers_required,
      application_deadline,
      event_type,
      payment_per_day,
      banner_url,
      categories,
      responsibilities,
      start_time,
      end_time,
      is_draft,
    } = req.body;

    if (!title) {
      return res.status(400).json({
        error: "Event title is required",
      });
    }

    const saveAsDraft = is_draft === true;

    if (
      !saveAsDraft &&
      (!location ||
        !event_date ||
        !end_date ||
        !volunteers_required ||
        !application_deadline ||
        !event_type ||
        !start_time ||
        !end_time)
    ) {
      return res.status(400).json({
        error: "Missing required event fields",
      });
    }

    if (
      !saveAsDraft &&
      event_type === "paid" &&
      (!payment_per_day || payment_per_day <= 0)
    ) {
      return res.status(400).json({
        error: "Payment per day is required for paid events",
      });
    }

    const safeEventType = event_type === "paid" ? "paid" : "unpaid";
    const parsedVolunteers = Number.parseInt(volunteers_required, 10);
    const safeVolunteersRequired =
      Number.isInteger(parsedVolunteers) && parsedVolunteers >= 0
        ? parsedVolunteers
        : 0;
    const safePaymentPerDay =
      safeEventType === "paid" && payment_per_day ? payment_per_day : null;

    const eventResult = await pool.query(
      `
      INSERT INTO events (
        organiser_id,
        title,
        description,
        location,
        event_date,
        end_date,
        volunteers_required,
        application_deadline,
        event_type,
        payment_per_day,
        banner_url,
        start_time,
        end_time,
        status
      )
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
      RETURNING *
      `,
      [
        req.user.id,
        title,
        description ?? null,
        location ?? null,
        event_date ?? null,
        end_date ?? null,
        safeVolunteersRequired,
        application_deadline ?? null,
        safeEventType,
        safePaymentPerDay,
        banner_url ?? null,
        start_time ?? null,
        end_time ?? null,
        saveAsDraft ? "draft" : "open",
      ]
    );

    const createdEvent = eventResult.rows[0];

    const cleanedResponsibilities = Array.isArray(responsibilities)
      ? responsibilities
          .map((item) => (typeof item === "string" ? item.trim() : ""))
          .filter(Boolean)
      : [];

    if (cleanedResponsibilities.length > 0) {
      const values = cleanedResponsibilities
        .map((_, i) => `($1, $${i + 2})`)
        .join(",");

      await pool.query(
        `
        INSERT INTO event_responsibilities (event_id, responsibility)
        VALUES ${values}
        `,
        [createdEvent.id, ...cleanedResponsibilities]
      );
    }

    if (Array.isArray(categories) && categories.length > 0) {
      const numericIds = [];
      const names = [];

      for (const item of categories) {
        if (typeof item === "number" && Number.isInteger(item)) {
          numericIds.push(item);
        } else if (typeof item === "string" && item.trim().length > 0) {
          names.push(item.trim());
        }
      }

      if (names.length > 0) {
        const nameResult = await pool.query(
          `
          SELECT id FROM categories
          WHERE name = ANY($1)
          `,
          [names]
        );
        for (const row of nameResult.rows) {
          numericIds.push(row.id);
        }
      }

      const uniqueIds = [...new Set(numericIds)];

      if (uniqueIds.length > 0) {
        const values = uniqueIds.map((_, i) => `($1, $${i + 2})`).join(",");
        await pool.query(
          `
          INSERT INTO event_categories (event_id, category_id)
          VALUES ${values}
          `,
          [createdEvent.id, ...uniqueIds]
        );
      }
    }

    res.status(201).json({
      message: "Event created successfully",
      event: createdEvent,
    });
  } catch (err) {
    console.error("CREATE EVENT ERROR:", err);
    res.status(500).json({ error: "Event creation failed" });
  }
};

// =======================================================
// ORGANISER → MY EVENTS
// =======================================================
exports.getMyEvents = async (req, res) => {
  try {
    const result = await pool.query(
      `
      SELECT
        e.*,
        COALESCE(
          array_agg(er.responsibility) FILTER (WHERE er.responsibility IS NOT NULL),
          '{}'
        ) AS responsibilities,
       CASE
  WHEN status = 'draft' THEN 'draft'
  WHEN status = 'deleted' THEN 'deleted_by_admin'
  WHEN NOW() < (event_date + COALESCE(start_time, TIME '00:00:00')) THEN 'upcoming'
  WHEN NOW() BETWEEN (event_date + COALESCE(start_time, TIME '00:00:00'))
                  AND (COALESCE(end_date, event_date) + COALESCE(end_time, TIME '23:59:59')) THEN 'ongoing'
  ELSE 'completed'
END AS computed_status

      FROM events e
      LEFT JOIN event_responsibilities er ON er.event_id = e.id
      WHERE organiser_id = $1
        AND status IN ('draft', 'open', 'closed', 'completed', 'deleted')
      GROUP BY e.id
      ORDER BY event_date DESC
      `,
      [req.user.id]
    );

    res.json(result.rows);
  } catch (err) {
    console.error("MY EVENTS ERROR:", err);
    res.status(500).json({ error: "Failed to fetch organiser events" });
  }
};

// =======================================================
// VOLUNTEER → PUBLIC EVENTS
// =======================================================
exports.getAllEvents = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT
        e.*,
        u.name AS organiser_name,
        u.profile_picture_url AS organiser_profile_picture_url,
        COALESCE(
          array_agg(DISTINCT er.responsibility) FILTER (WHERE er.responsibility IS NOT NULL),
          '{}'
        ) AS responsibilities,
        COALESCE(
          array_agg(DISTINCT c.name) FILTER (WHERE c.name IS NOT NULL),
          '{}'
        ) AS categories,
        CASE
          WHEN NOW() < (event_date + COALESCE(start_time, TIME '00:00:00')) THEN 'upcoming'
          WHEN NOW() BETWEEN (event_date + COALESCE(start_time, TIME '00:00:00'))
                          AND (COALESCE(end_date, event_date) + COALESCE(end_time, TIME '23:59:59')) THEN 'ongoing'
          ELSE 'completed'
        END AS computed_status
      FROM events e
      JOIN users u ON e.organiser_id = u.id
      LEFT JOIN event_responsibilities er ON er.event_id = e.id
      LEFT JOIN event_categories ec ON ec.event_id = e.id
      LEFT JOIN categories c ON c.id = ec.category_id
      WHERE e.status = 'open'
      GROUP BY e.id, u.name, u.profile_picture_url
      ORDER BY event_date ASC
    `);

    res.json(result.rows);
  } catch (err) {
    console.error("GET EVENTS ERROR:", err);
    res.status(500).json({ error: "Internal server error" });
  }
};

// =======================================================
// PUBLIC: SINGLE EVENT DETAILS
// =======================================================
exports.getEventById = async (req, res) => {
  try {
    const eventId = req.params.id;

    const result = await pool.query(
      `
      SELECT
        e.*,
        u.name AS organiser_name,
        u.profile_picture_url AS organiser_profile_picture_url,
        COALESCE(
          array_agg(er.responsibility) FILTER (WHERE er.responsibility IS NOT NULL),
          '{}'
        ) AS responsibilities,
        CASE
          WHEN NOW() < (event_date + COALESCE(start_time, TIME '00:00:00')) THEN 'upcoming'
          WHEN NOW() BETWEEN (event_date + COALESCE(start_time, TIME '00:00:00'))
                          AND (COALESCE(end_date, event_date) + COALESCE(end_time, TIME '23:59:59')) THEN 'ongoing'
          ELSE 'completed'
        END AS computed_status
      FROM events e
      JOIN users u ON e.organiser_id = u.id
      LEFT JOIN event_responsibilities er ON er.event_id = e.id
      WHERE e.id = $1 AND e.status != 'deleted'
      GROUP BY e.id, u.name, u.profile_picture_url
      `,
      [eventId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Event not found" });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error("GET EVENT ERROR:", err);
    res.status(500).json({ error: "Failed to fetch event" });
  }
};

// =======================================================
// LEADERBOARD (AUTHENTICATED)
// =======================================================
exports.getVolunteerLeaderboard = async (req, res) => {
  try {
    const period = req.query.period === "weekly" ? "weekly" : "monthly";
    const days = period === "weekly" ? 7 : 30;

    const result = await pool.query(
      `
      SELECT
        u.id,
        u.name,
        COUNT(a.id)::int AS completed_events
      FROM users u
      JOIN applications a ON a.volunteer_id = u.id
      JOIN events e ON e.id = a.event_id
      WHERE u.role = 'volunteer'
        AND a.status = 'completed'
        AND e.status = 'completed'
        AND COALESCE(e.end_date, e.event_date) >= CURRENT_DATE - ($1::int - 1)
      GROUP BY u.id, u.name
      ORDER BY completed_events DESC, u.name ASC
      `,
      [days]
    );

    res.json(result.rows);
  } catch (err) {
    console.error("VOLUNTEER LEADERBOARD ERROR:", err);
    res.status(500).json({ error: "Failed to load volunteer leaderboard" });
  }
};

exports.getOrganiserLeaderboard = async (req, res) => {
  try {
    const period = req.query.period === "weekly" ? "weekly" : "monthly";
    const days = period === "weekly" ? 7 : 30;

    const result = await pool.query(
      `
      SELECT
        u.id,
        u.name,
        COUNT(e.id)::int AS completed_events
      FROM users u
      JOIN events e ON e.organiser_id = u.id
      WHERE u.role = 'organiser'
        AND e.status = 'completed'
        AND COALESCE(e.end_date, e.event_date) >= CURRENT_DATE - ($1::int - 1)
      GROUP BY u.id, u.name
      ORDER BY completed_events DESC, u.name ASC
      `,
      [days]
    );

    res.json(result.rows);
  } catch (err) {
    console.error("ORGANISER LEADERBOARD ERROR:", err);
    res.status(500).json({ error: "Failed to load organiser leaderboard" });
  }
};

// =======================================================
// UPDATE EVENT (ORGANISER)
// =======================================================
exports.updateEvent = async (req, res) => {
  try {
    const organiserId = req.user.id;
    const eventId = req.params.id;

    const {
      title,
      description,
      location,
      event_date,
      end_date,
      application_deadline,
      volunteers_required,
      event_type,
      payment_per_day,
      banner_url,
      start_time,
      end_time,
    } = req.body;

    const result = await pool.query(
      `
      UPDATE events
      SET
        title = $1,
        description = $2,
        location = $3,
        event_date = $4,
        end_date = $5,
        application_deadline = $6,
        volunteers_required = $7,
        event_type = $8,
        payment_per_day = $9,
        banner_url = $10,
        start_time = $11,
        end_time = $12
      WHERE id = $13 AND organiser_id = $14
      RETURNING *
      `,
      [
        title,
        description,
        location,
        event_date,
        end_date,
        application_deadline,
        volunteers_required,
        event_type,
        payment_per_day,
        banner_url,
        start_time,
        end_time,
        eventId,
        organiserId,
      ]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: "Event not found" });
    }

    const updatedEvent = result.rows[0];

    res.json(updatedEvent);

    try {
      const volunteerResult = await pool.query(
        "SELECT volunteer_id FROM applications WHERE event_id = $1",
        [eventId]
      );
      const volunteerIds = volunteerResult.rows.map((r) => r.volunteer_id);

      await notifyUsers(volunteerIds, {
        title: "Event update",
        body: `${updatedEvent.title} details were updated.`,
        data: { type: "event_update", eventId: String(eventId) },
      });
    } catch (notifyErr) {
      console.error("EVENT UPDATE NOTIFY ERROR:", notifyErr);
    }
  } catch (err) {
    console.error("UPDATE EVENT ERROR:", err);
    res.status(500).json({ error: "Failed to update event" });
  }
};
