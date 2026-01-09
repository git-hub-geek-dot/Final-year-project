const pool = require("../config/db");

/*
EVENTS TABLE (SOURCE OF TRUTH)

id
organizer_id
title
description
location
event_date
category
slots_total
slots_filled
status          -- 'open' | 'approved' | 'closed'
created_at
*/


// =======================================================
// CREATE EVENT (ORGANISER)
// =======================================================
exports.createEvent = async (req, res) => {
  try {
    // Role guard
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
      category,
      slots_total,
    } = req.body;

    // Required field validation (MATCHES DB)
    if (!title || !location || !event_date || !category || !slots_total) {
      return res.status(400).json({
        error: "Missing required event fields",
      });
    }

    const result = await pool.query(
      `
      INSERT INTO events (
        organizer_id,
        title,
        description,
        location,
        event_date,
        category,
        slots_total,
        slots_filled,
        status
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, 0, 'open')
      RETURNING *
      `,
      [
        req.user.id,
        title,
        description ?? null,
        location,
        event_date,
        category,
        slots_total,
      ]
    );

    res.status(201).json({
      message: "Event created successfully",
      event: result.rows[0],
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
        id,
        title,
        location,
        event_date,
        category,
        slots_total,
        slots_filled,
        status
      FROM events
      WHERE organizer_id = $1
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
// PUBLIC EVENTS (VOLUNTEERS)
// =======================================================
exports.getAllEvents = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT
        id,
        title,
        description,
        location,
        event_date,
        category,
        (slots_total - slots_filled) AS slots_left
      FROM events
      WHERE status IN ('open', 'approved')
      ORDER BY event_date ASC
    `);

    res.json(result.rows);
  } catch (err) {
    console.error("GET EVENTS ERROR:", err);
    res.status(500).json({ error: "Internal server error" });
  }
};
