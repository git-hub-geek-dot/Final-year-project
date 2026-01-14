const pool = require("../config/db");

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
status          -- 'upcoming' | 'closed'
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
      volunteers_required,
      application_deadline,
      event_type,
      payment_per_day,
      banner_url,
      categories,
      start_time,
      end_time,
    } = req.body;

    if (
      !title ||
      !location ||
      !event_date ||
      !volunteers_required ||
      !application_deadline ||
      !event_type
    ) {
      return res.status(400).json({
        error: "Missing required event fields",
      });
    }

    if (event_type === "paid" && (!payment_per_day || payment_per_day <= 0)) {
      return res.status(400).json({
        error: "Payment per day is required for paid events",
      });
    }

    const eventResult = await pool.query(
      `
      INSERT INTO events (
        organiser_id,
        title,
        description,
        location,
        event_date,
        volunteers_required,
        application_deadline,
        event_type,
        payment_per_day,
        banner_url,
        start_time,
        end_time
      )
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
      RETURNING *
      `,
      [
        req.user.id,
        title,
        description ?? null,
        location,
        event_date,
        volunteers_required,
        application_deadline,
        event_type,
        event_type === "paid" ? payment_per_day : null,
        banner_url ?? null,
        start_time ?? null,
        end_time ?? null,
      ]
    );

    const createdEvent = eventResult.rows[0];

    if (Array.isArray(categories) && categories.length > 0) {
      const values = categories.map((_, i) => `($1, $${i + 2})`).join(",");
      await pool.query(
        `
        INSERT INTO event_categories (event_id, category_id)
        VALUES ${values}
        `,
        [createdEvent.id, ...categories]
      );
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
        *,
        CASE
          WHEN NOW() < (event_date + start_time) THEN 'upcoming'
          WHEN NOW() BETWEEN (event_date + start_time)
                          AND (event_date + end_time) THEN 'ongoing'
          ELSE 'completed'
        END AS computed_status
      FROM events
      WHERE organiser_id = $1
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
        *,
        CASE
          WHEN NOW() < (event_date + start_time) THEN 'upcoming'
          WHEN NOW() BETWEEN (event_date + start_time)
                          AND (event_date + end_time) THEN 'ongoing'
          ELSE 'completed'
        END AS computed_status
      FROM events
      WHERE status = 'open'
      ORDER BY event_date ASC
    `);

    res.json(result.rows);
  } catch (err) {
    console.error("GET EVENTS ERROR:", err);
    res.status(500).json({ error: "Internal server error" });
  }

};
exports.updateEvent = async (req, res) => {
  const { id } = req.params;
  const {
    title,
    description,
    location,
    event_date,
    application_deadline,
    volunteers_required,
    event_type,
    payment_per_day,
    banner_url,
  } = req.body;

  try {
    await pool.query(
      `UPDATE events SET
        title = $1,
        description = $2,
        location = $3,
        event_date = $4,
        application_deadline = $5,
        volunteers_required = $6,
        event_type = $7,
        payment_per_day = $8,
        banner_url = $9
       WHERE id = $10`,
      [
        title,
        description,
        location,
        event_date,
        application_deadline,
        volunteers_required,
        event_type,
        payment_per_day,
        banner_url,
        id,
      ]
    );

    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Update failed" });
  }
};
