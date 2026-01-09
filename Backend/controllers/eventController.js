const pool = require("../config/db");

// ================= CREATE EVENT (ORGANISER) =================
exports.createEvent = async (req, res) => {
  try {
    // 🔐 Role check
    if (req.user.role !== "organiser") {
      return res
        .status(403)
        .json({ error: "Only organisers can create events" });
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
      categories // array of category IDs
    } = req.body;

    // 🔴 Required field validation (matches DB constraints)
    if (
      !title ||
      !location ||
      !event_date ||
      !volunteers_required ||
      !application_deadline ||
      !event_type
    ) {
      return res.status(400).json({
        error: "Missing required event fields"
      });
    }

    // 💰 Paid event validation
    if (event_type === "paid") {
      if (!payment_per_day || payment_per_day <= 0) {
        return res.status(400).json({
          error: "Payment per day is required for paid events"
        });
      }
    }

    // 🟢 INSERT EVENT
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
        banner_url
      )
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
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
        banner_url ?? null
      ]
    );

    const createdEvent = eventResult.rows[0];

    // 🏷 INSERT EVENT CATEGORIES (if provided)
    if (Array.isArray(categories) && categories.length > 0) {
      const values = categories
        .map((_, i) => `($1, $${i + 2})`)
        .join(",");

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
      event: createdEvent
    });

  } catch (err) {
    console.error("CREATE EVENT ERROR:", err);
    res.status(500).json({ error: "Event creation failed" });
  }
};

// ================= ORGANISER → MY EVENTS =================
exports.getMyEvents = async (req, res) => {
  try {
    const events = await pool.query(
      `
      SELECT *
      FROM events
      WHERE organiser_id = $1
      ORDER BY id DESC
      `,
      [req.user.id]
    );

    res.json(events.rows);
  } catch (err) {
    console.error("MY EVENTS ERROR:", err);
    res.status(500).json({ error: "Failed to fetch events" });
  }
};

// ================= PUBLIC EVENTS (VOLUNTEERS) =================
exports.getAllEvents = async (req, res) => {
  try {
    const result = await pool.query(
      `
      SELECT
        id,
        title,
        description,
        location,
        event_date,
        event_type,
        volunteers_required,
        application_deadline,
        banner_url
      FROM events
      ORDER BY event_date ASC
      `
    );

    res.json(result.rows);
  } catch (err) {
    console.error("GET EVENTS ERROR:", err);
    res.status(500).json({ error: "Internal server error" });
  }
};
