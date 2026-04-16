const pool = require("../config/db");
const { notifyUsers } = require("../services/notificationService");
const {
  notifyCompletedEventsForOrganiser,
} = require("../services/eventCompletionNotificationService");
const {
  notifyOngoingAttendanceUpdatesForOrganiser,
} = require("../services/eventAttendanceNotificationService");
const {
  applyAttendanceCompletionEffects,
} = require("../services/eventStatusService");

const VALID_PAYMENT_RATE_TYPES = new Set(["per_day", "per_hour", "fixed"]);
const VALID_ATTENDANCE_STATUSES = new Set(["unmarked", "present", "absent"]);

function normalizeDateOnly(value) {
  if (value === undefined || value === null) {
    return null;
  }

  const raw =
    value instanceof Date ? value.toISOString().slice(0, 10) : value.toString().trim();

  if (!raw || !/^\d{4}-\d{2}-\d{2}$/.test(raw)) {
    return null;
  }

  const parsed = new Date(`${raw}T00:00:00Z`);
  if (Number.isNaN(parsed.getTime())) {
    return null;
  }

  return raw;
}

function normalizePaymentRateType(value) {
  if (typeof value !== "string") {
    return null;
  }

  const normalized = value.trim().toLowerCase();
  return VALID_PAYMENT_RATE_TYPES.has(normalized) ? normalized : null;
}

function isDateOnOrAfter(leftDate, rightDate) {
  const left = normalizeDateOnly(leftDate);
  const right = normalizeDateOnly(rightDate);

  if (!left || !right) {
    return false;
  }

  return new Date(`${left}T00:00:00Z`).getTime() >= new Date(`${right}T00:00:00Z`).getTime();
}

function normalizeAttendanceStatus(value) {
  const normalized = (value ?? "").toString().trim().toLowerCase();
  return VALID_ATTENDANCE_STATUSES.has(normalized) ? normalized : "unmarked";
}

function hasMeaningfulText(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function hasSelectedCategoriesInput(categories) {
  if (!Array.isArray(categories)) {
    return false;
  }

  return categories.some((item) => {
    if (typeof item === "number") {
      return Number.isInteger(item);
    }

    return typeof item === "string" && item.trim().length > 0;
  });
}

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

    const verificationResult = await pool.query(
      `
      SELECT "isVerified"
      FROM users
      WHERE id = $1 AND role = 'organiser'
      `,
      [req.user.id]
    );

    if (verificationResult.rowCount === 0) {
      return res.status(404).json({ error: "Organiser not found" });
    }

    const isVerified = verificationResult.rows[0]?.isVerified === true;
    if (!isVerified) {
      return res.status(403).json({
        error:
          "You need to be a verified organiser to create events. Please complete verification first.",
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
      payment_amount,
      payment_rate_type,
      payment_clearance_date,
      banner_url,
      categories,
      responsibilities,
      start_time,
      end_time,
      is_draft,
      daily_schedules, // NEW: array of {date, start_time, end_time}
    } = req.body;

    if (!title) {
      return res.status(400).json({
        error: "Event title is required",
      });
    }

    const saveAsDraft = is_draft === true;
    const hasVolunteersInput =
      volunteers_required !== undefined &&
      volunteers_required !== null &&
      volunteers_required.toString().trim() !== "";
    const parsedVolunteers = hasVolunteersInput
      ? Number.parseInt(volunteers_required, 10)
      : null;
    const hasValidVolunteers =
      Number.isInteger(parsedVolunteers) && parsedVolunteers >= 1;
    const hasPaymentRateTypeInput =
      payment_rate_type !== undefined &&
      payment_rate_type !== null &&
      payment_rate_type.toString().trim() !== "";
    const normalizedPaymentRateType =
      normalizePaymentRateType(payment_rate_type);
    const hasPaymentClearanceDateInput =
      payment_clearance_date !== undefined &&
      payment_clearance_date !== null &&
      payment_clearance_date.toString().trim() !== "";
    const normalizedPaymentClearanceDate =
      normalizeDateOnly(payment_clearance_date);
    const missingFields = [];

    if (!saveAsDraft) {
      if (!hasMeaningfulText(location)) missingFields.push("location");
      if (!hasMeaningfulText(description)) missingFields.push("description");
      if (!event_date) missingFields.push("event_date");
      if (!end_date) missingFields.push("end_date");
      if (!hasVolunteersInput) missingFields.push("volunteers_required");
      if (!application_deadline) missingFields.push("application_deadline");
      if (!event_type) missingFields.push("event_type");
      if (!start_time) missingFields.push("start_time");
      if (!end_time) missingFields.push("end_time");
      if (!hasSelectedCategoriesInput(categories)) missingFields.push("categories");
    }

    if (missingFields.length > 0) {
      return res.status(400).json({
        error: "Missing required event fields",
        missing_fields: missingFields,
      });
    }

    if (hasVolunteersInput && !hasValidVolunteers) {
      return res.status(400).json({
        error: "volunteers_required must be at least 1",
      });
    }

    if (hasPaymentClearanceDateInput && !normalizedPaymentClearanceDate) {
      return res.status(400).json({
        error: "Payment clearance date must be a valid date",
      });
    }

    if (hasPaymentRateTypeInput && !normalizedPaymentRateType) {
      return res.status(400).json({
        error: "Payment rate type must be per_day, per_hour, or fixed",
      });
    }

    if (
      !saveAsDraft &&
      event_type === "paid" &&
      (!payment_amount || payment_amount <= 0)
    ) {
      return res.status(400).json({
        error: "Payment amount is required for paid events",
      });
    }

    if (
      !saveAsDraft &&
      event_type === "paid" &&
      !normalizedPaymentRateType
    ) {
      return res.status(400).json({
        error: "Payment rate type is required for paid events",
      });
    }

    if (
      !saveAsDraft &&
      event_type === "paid" &&
      !normalizedPaymentClearanceDate
    ) {
      return res.status(400).json({
        error: "Payment clearance date is required for paid events",
      });
    }

    const safeEventType = event_type === "paid" ? "paid" : "unpaid";
    const safeVolunteersRequired = hasVolunteersInput ? parsedVolunteers : 0;
    const safePaymentAmount =
      safeEventType === "paid" && payment_amount ? payment_amount : null;
    const safePaymentRateType =
      safeEventType === "paid" ? normalizedPaymentRateType : null;
    const safePaymentClearanceDate =
      safeEventType === "paid" ? normalizedPaymentClearanceDate : null;

    if (
      safeEventType === "paid" &&
      end_date &&
      safePaymentClearanceDate &&
      !isDateOnOrAfter(safePaymentClearanceDate, end_date)
    ) {
      return res.status(400).json({
        error: "Payment clearance date cannot be before the event end date",
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
        end_date,
        volunteers_required,
        application_deadline,
        event_type,
        payment_amount,
        payment_rate_type,
        payment_clearance_date,
        banner_url,
        start_time,
        end_time,
        status
      )
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16)
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
        safePaymentAmount,
        safePaymentRateType,
        safePaymentClearanceDate,
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

    // Insert daily schedules if provided
    if (Array.isArray(daily_schedules) && daily_schedules.length > 0) {
      const validSchedules = daily_schedules.filter(
        (schedule) => schedule.date && schedule.start_time && schedule.end_time
      );

      if (validSchedules.length > 0) {
        const scheduleValues = validSchedules
          .map(
            (_, i) =>
              `($1, $${i * 3 + 2}, $${i * 3 + 3}, $${i * 3 + 4})`
          )
          .join(",");

        const scheduleParams = [createdEvent.id];
        validSchedules.forEach((schedule) => {
          scheduleParams.push(schedule.date, schedule.start_time, schedule.end_time);
        });

        await pool.query(
          `
          INSERT INTO daily_schedules (event_id, date, start_time, end_time)
          VALUES ${scheduleValues}
          `,
          scheduleParams
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
    try {
      await notifyOngoingAttendanceUpdatesForOrganiser(req.user.id);
    } catch (attendanceNotifyErr) {
      console.error("ORGANISER ATTENDANCE NOTIFY ERROR:", attendanceNotifyErr);
    }

    try {
      await notifyCompletedEventsForOrganiser(req.user.id);
    } catch (notifyErr) {
      console.error("ORGANISER COMPLETION NOTIFY ERROR:", notifyErr);
    }

    const result = await pool.query(
      `
      SELECT
        e.*,
        COALESCE(COUNT(DISTINCT a.id), 0)::int AS applications_count,
        COALESCE(
          COUNT(DISTINCT a.id) FILTER (WHERE a.status IN ('accepted', 'approved')),
          0
        )::int AS approved_count,
        COALESCE(
          array_agg(DISTINCT er.responsibility) FILTER (WHERE er.responsibility IS NOT NULL),
          '{}'
        ) AS responsibilities,
        COALESCE(
          array_agg(DISTINCT c.name) FILTER (WHERE c.name IS NOT NULL),
          '{}'
        ) AS categories,
        COALESCE(
          jsonb_agg(
            jsonb_build_object(
              'date', ds.date,
              'start_time', ds.start_time,
              'end_time', ds.end_time
            ) ORDER BY ds.date
          ) FILTER (WHERE ds.date IS NOT NULL),
          '[]'::jsonb
        ) AS daily_schedules,
       CASE
  WHEN e.status = 'draft' THEN 'draft'
  WHEN e.status = 'deleted' THEN 'deleted_by_admin'
  WHEN e.status = 'closed' THEN 'cancelled'
  WHEN NOW() < (e.event_date + COALESCE(e.start_time, TIME '00:00:00')) THEN 'upcoming'
  WHEN NOW() BETWEEN (e.event_date + COALESCE(e.start_time, TIME '00:00:00'))
                  AND (COALESCE(e.end_date, e.event_date) + COALESCE(e.end_time, TIME '23:59:59')) THEN 'ongoing'
  ELSE 'completed'
END AS computed_status

      FROM events e
      LEFT JOIN applications a ON a.event_id = e.id
      LEFT JOIN event_responsibilities er ON er.event_id = e.id
      LEFT JOIN event_categories ec ON ec.event_id = e.id
      LEFT JOIN categories c ON c.id = ec.category_id
      LEFT JOIN daily_schedules ds ON ds.event_id = e.id
      WHERE e.organiser_id = $1
        AND e.status IN ('draft', 'open', 'closed', 'completed', 'deleted')
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
        COALESCE(COUNT(DISTINCT a.id), 0)::int AS approved_count,
        COALESCE(
          array_agg(DISTINCT er.responsibility) FILTER (WHERE er.responsibility IS NOT NULL),
          '{}'
        ) AS responsibilities,
        COALESCE(
          array_agg(DISTINCT c.name) FILTER (WHERE c.name IS NOT NULL),
          '{}'
        ) AS categories,
        COALESCE(
          jsonb_agg(
            jsonb_build_object(
              'date', ds.date,
              'start_time', ds.start_time,
              'end_time', ds.end_time
            ) ORDER BY ds.date
          ) FILTER (WHERE ds.date IS NOT NULL),
          '[]'::jsonb
        ) AS daily_schedules,
        CASE
          WHEN e.status = 'closed' THEN 'cancelled'
          WHEN NOW() < (e.event_date + COALESCE(e.start_time, TIME '00:00:00')) THEN 'upcoming'
          WHEN NOW() BETWEEN (e.event_date + COALESCE(e.start_time, TIME '00:00:00'))
                          AND (COALESCE(e.end_date, e.event_date) + COALESCE(e.end_time, TIME '23:59:59')) THEN 'ongoing'
          ELSE 'completed'
        END AS computed_status
      FROM events e
      JOIN users u ON e.organiser_id = u.id
      LEFT JOIN applications a
        ON a.event_id = e.id AND a.status IN ('accepted', 'approved')
      LEFT JOIN event_responsibilities er ON er.event_id = e.id
      LEFT JOIN event_categories ec ON ec.event_id = e.id
      LEFT JOIN categories c ON c.id = ec.category_id
      LEFT JOIN daily_schedules ds ON ds.event_id = e.id
      WHERE e.status = 'open'
        AND (
          e.application_deadline IS NULL
          OR ((NOW() AT TIME ZONE 'Asia/Kolkata')::date <= e.application_deadline)
        )
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
          array_agg(DISTINCT er.responsibility) FILTER (WHERE er.responsibility IS NOT NULL),
          '{}'
        ) AS responsibilities,
        COALESCE(
          array_agg(DISTINCT c.name) FILTER (WHERE c.name IS NOT NULL),
          '{}'
        ) AS categories,
        COALESCE(
          jsonb_agg(
            jsonb_build_object(
              'date', ds.date,
              'start_time', ds.start_time,
              'end_time', ds.end_time
            ) ORDER BY ds.date
          ) FILTER (WHERE ds.date IS NOT NULL),
          '[]'::jsonb
        ) AS daily_schedules,
        CASE
          WHEN e.status = 'closed' THEN 'cancelled'
          WHEN NOW() < (e.event_date + COALESCE(e.start_time, TIME '00:00:00')) THEN 'upcoming'
          WHEN NOW() BETWEEN (e.event_date + COALESCE(e.start_time, TIME '00:00:00'))
                          AND (COALESCE(e.end_date, e.event_date) + COALESCE(e.end_time, TIME '23:59:59')) THEN 'ongoing'
          ELSE 'completed'
        END AS computed_status
      FROM events e
      JOIN users u ON e.organiser_id = u.id
      LEFT JOIN event_responsibilities er ON er.event_id = e.id
      LEFT JOIN event_categories ec ON ec.event_id = e.id
      LEFT JOIN categories c ON c.id = ec.category_id
      LEFT JOIN daily_schedules ds ON ds.event_id = e.id
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
        AND a.status IN ('approved', 'accepted', 'completed')
        AND COALESCE(a.attendance_status, 'unmarked') <> 'absent'
        AND e.status != 'deleted'
        AND (
          e.status = 'completed'
          OR NOW() >= (
            COALESCE(e.end_date, e.event_date) + COALESCE(e.end_time, TIME '23:59:59')
          )
        )
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
        AND e.status != 'deleted'
        AND (
          e.status = 'completed'
          OR NOW() >= (
            COALESCE(e.end_date, e.event_date) + COALESCE(e.end_time, TIME '23:59:59')
          )
        )
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
  const client = await pool.connect();
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
      payment_amount,
      payment_rate_type,
      payment_clearance_date,
      banner_url,
      start_time,
      end_time,
      publish,
      categories,
      responsibilities,
      daily_schedules, // NEW: array of {date, start_time, end_time}
    } = req.body;

    const publishNow = publish === true;
    const parsedVolunteers = Number.parseInt(volunteers_required, 10);
    const hasValidVolunteers =
      Number.isInteger(parsedVolunteers) && parsedVolunteers >= 1;
    const safeEventType = event_type === "paid" ? "paid" : "unpaid";
    const hasPaymentRateTypeInput =
      payment_rate_type !== undefined &&
      payment_rate_type !== null &&
      payment_rate_type.toString().trim() !== "";
    const normalizedPaymentRateType =
      normalizePaymentRateType(payment_rate_type);
    const hasPaymentClearanceDateInput =
      payment_clearance_date !== undefined &&
      payment_clearance_date !== null &&
      payment_clearance_date.toString().trim() !== "";
    const normalizedPaymentClearanceDate =
      normalizeDateOnly(payment_clearance_date);
    const safePaymentAmount =
      safeEventType === "paid" && payment_amount ? payment_amount : null;
    const safePaymentRateType =
      safeEventType === "paid" ? normalizedPaymentRateType : null;
    const safePaymentClearanceDate =
      safeEventType === "paid" ? normalizedPaymentClearanceDate : null;
    const missingFields = [];

    if (!hasMeaningfulText(description)) {
      missingFields.push("description");
    }

    if (publishNow && !hasSelectedCategoriesInput(categories)) {
      missingFields.push("categories");
    }

    if (!hasValidVolunteers) {
      return res.status(400).json({
        error: "volunteers_required must be at least 1",
      });
    }

    if (hasPaymentClearanceDateInput && !normalizedPaymentClearanceDate) {
      return res.status(400).json({
        error: "Payment clearance date must be a valid date",
      });
    }

    if (hasPaymentRateTypeInput && !normalizedPaymentRateType) {
      return res.status(400).json({
        error: "Payment rate type must be per_day, per_hour, or fixed",
      });
    }

    if (
      safeEventType === "paid" &&
      (!safePaymentAmount || Number(safePaymentAmount) <= 0)
    ) {
      return res.status(400).json({
        error: "Payment amount is required for paid events",
      });
    }

    if (safeEventType === "paid" && !safePaymentRateType) {
      return res.status(400).json({
        error: "Payment rate type is required for paid events",
      });
    }

    if (safeEventType === "paid" && !safePaymentClearanceDate) {
      return res.status(400).json({
        error: "Payment clearance date is required for paid events",
      });
    }

    if (
      safeEventType === "paid" &&
      end_date &&
      safePaymentClearanceDate &&
      !isDateOnOrAfter(safePaymentClearanceDate, end_date)
    ) {
      return res.status(400).json({
        error: "Payment clearance date cannot be before the event end date",
      });
    }

    if (publishNow && missingFields.length > 0) {
      return res.status(400).json({
        error: "Complete required event fields before publishing",
        missing_fields: missingFields,
      });
    }

    await client.query("BEGIN");

    const eventStateResult = await client.query(
      `
      SELECT
        id,
        status,
        (
          status = 'completed'
          OR (
            status NOT IN ('draft', 'deleted')
            AND NOW() >= (
              COALESCE(end_date, event_date) + COALESCE(end_time, TIME '23:59:59')
            )
          )
        ) AS is_completed
      FROM events
      WHERE id = $1 AND organiser_id = $2
      FOR UPDATE
      `,
      [eventId, organiserId]
    );

    if (eventStateResult.rowCount === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ error: "Event not found" });
    }

    if (eventStateResult.rows[0]?.is_completed === true) {
      await client.query("ROLLBACK");
      return res.status(400).json({
        error: "Completed events cannot be edited",
      });
    }

    const approvedCountResult = await client.query(
      `
      SELECT COUNT(*)::int AS approved_count
      FROM applications
      WHERE event_id = $1
        AND status IN ('approved', 'accepted')
      `,
      [eventId]
    );
    const approvedCount = approvedCountResult.rows[0]?.approved_count ?? 0;

    if (parsedVolunteers < approvedCount) {
      await client.query("ROLLBACK");
      return res.status(400).json({
        error:
          "volunteers_required cannot be less than approved volunteers",
        approved_count: approvedCount,
        volunteers_required: parsedVolunteers,
      });
    }

    const result = await client.query(
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
        payment_amount = $9,
        payment_rate_type = $10,
        payment_clearance_date = $11,
        banner_url = $12,
        start_time = $13,
        end_time = $14,
        status = CASE
          WHEN $15::boolean = true AND status = 'draft' THEN 'open'
          ELSE status
        END
      WHERE id = $16 AND organiser_id = $17
      RETURNING *
      `,
      [
        title,
        description,
        location,
        event_date,
        end_date,
        application_deadline,
        parsedVolunteers,
        safeEventType,
        safePaymentAmount,
        safePaymentRateType,
        safePaymentClearanceDate,
        banner_url,
        start_time,
        end_time,
        publishNow,
        eventId,
        organiserId,
      ]
    );

    if (result.rowCount === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ error: "Event not found" });
    }

    const hasResponsibilitiesPayload = Array.isArray(responsibilities);
    const cleanedResponsibilities = hasResponsibilitiesPayload
      ? responsibilities
          .map((item) => (typeof item === "string" ? item.trim() : ""))
          .filter(Boolean)
      : null;

    if (hasResponsibilitiesPayload) {
      await client.query(
        "DELETE FROM event_responsibilities WHERE event_id = $1",
        [eventId]
      );

      if (cleanedResponsibilities.length > 0) {
        const responsibilityValues = cleanedResponsibilities
          .map((_, i) => `($1, $${i + 2})`)
          .join(",");

        await client.query(
          `
          INSERT INTO event_responsibilities (event_id, responsibility)
          VALUES ${responsibilityValues}
          `,
          [eventId, ...cleanedResponsibilities]
        );
      }
    }

    const hasCategoriesPayload = Array.isArray(categories);
    const numericCategoryIds = [];
    const categoryNames = [];

    if (hasCategoriesPayload) {
      for (const item of categories) {
        if (typeof item === "number" && Number.isInteger(item)) {
          numericCategoryIds.push(item);
        } else if (typeof item === "string" && item.trim().length > 0) {
          categoryNames.push(item.trim());
        }
      }
    }

    if (categoryNames.length > 0) {
      const categoryNameResult = await client.query(
        `
        SELECT id
        FROM categories
        WHERE name = ANY($1)
        `,
        [categoryNames]
      );

      for (const row of categoryNameResult.rows) {
        numericCategoryIds.push(row.id);
      }
    }

    const uniqueCategoryIds = [...new Set(numericCategoryIds)];

    if (hasCategoriesPayload) {
      await client.query("DELETE FROM event_categories WHERE event_id = $1", [
        eventId,
      ]);

      if (uniqueCategoryIds.length > 0) {
        const categoryValues = uniqueCategoryIds
          .map((_, i) => `($1, $${i + 2})`)
          .join(",");

        await client.query(
          `
          INSERT INTO event_categories (event_id, category_id)
          VALUES ${categoryValues}
          `,
          [eventId, ...uniqueCategoryIds]
        );
      }
    }

    // Update daily schedules if provided
    if (Array.isArray(daily_schedules)) {
      // Delete existing schedules
      await client.query(
        "DELETE FROM daily_schedules WHERE event_id = $1",
        [eventId]
      );

      // Insert new schedules
      const validSchedules = daily_schedules.filter(
        (schedule) => schedule.date && schedule.start_time && schedule.end_time
      );

      if (validSchedules.length > 0) {
        const scheduleValues = validSchedules
          .map(
            (_, i) =>
              `($1, $${i * 3 + 2}, $${i * 3 + 3}, $${i * 3 + 4})`
          )
          .join(",");

        const scheduleParams = [eventId];
        validSchedules.forEach((schedule) => {
          scheduleParams.push(schedule.date, schedule.start_time, schedule.end_time);
        });

        await client.query(
          `
          INSERT INTO daily_schedules (event_id, date, start_time, end_time)
          VALUES ${scheduleValues}
          `,
          scheduleParams
        );
      }
    }

    const categoryListResult = await client.query(
      `
      SELECT c.name
      FROM event_categories ec
      JOIN categories c ON c.id = ec.category_id
      WHERE ec.event_id = $1
      ORDER BY c.name ASC
      `,
      [eventId]
    );

    await client.query("COMMIT");

    const updatedEvent = result.rows[0];
    const updatedCategories = categoryListResult.rows.map((r) => r.name);
    const responsibilityListResult = await pool.query(
      `
      SELECT responsibility
      FROM event_responsibilities
      WHERE event_id = $1
      ORDER BY id ASC
      `,
      [eventId]
    );
    const updatedResponsibilities = responsibilityListResult.rows.map(
      (r) => r.responsibility
    );

    res.json({
      ...updatedEvent,
      categories: updatedCategories,
      responsibilities: updatedResponsibilities,
    });

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
    try {
      await client.query("ROLLBACK");
    } catch (_) {}
    console.error("UPDATE EVENT ERROR:", err);
    res.status(500).json({ error: "Failed to update event" });
  } finally {
    client.release();
  }
};

// =======================================================
// CANCEL EVENT (ORGANISER)
// =======================================================
exports.cancelEvent = async (req, res) => {
  const client = await pool.connect();
  try {
    const organiserId = req.user.id;
    const eventId = req.params.id;
    const reason = (req.body?.reason || "").toString().trim();

    if (!reason) {
      return res.status(400).json({
        error: "Cancellation reason is required",
      });
    }

    if (reason.length > 500) {
      return res.status(400).json({
        error: "Cancellation reason is too long",
      });
    }

    await client.query("BEGIN");

    const eventResult = await client.query(
      `
      SELECT
        id,
        title,
        status,
        (
          NOW() >= (
            COALESCE(end_date, event_date)
            + COALESCE(end_time, TIME '23:59:59')
          )
        ) AS has_ended
      FROM events
      WHERE id = $1 AND organiser_id = $2
      FOR UPDATE
      `,
      [eventId, organiserId]
    );

    if (eventResult.rowCount === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ error: "Event not found" });
    }

    const event = eventResult.rows[0];
    const hasEnded = event.has_ended === true;

    if (event.status === "deleted") {
      await client.query("ROLLBACK");
      return res.status(400).json({ error: "Event is deleted by admin" });
    }

    if (event.status === "closed") {
      await client.query("ROLLBACK");
      return res.status(400).json({ error: "Event is already cancelled" });
    }

    if (event.status === "completed") {
      await client.query("ROLLBACK");
      return res.status(400).json({ error: "Completed events cannot be cancelled" });
    }

    if (hasEnded) {
      if (event.status === "open") {
        await client.query(
          `
          UPDATE events
          SET status = 'completed'
          WHERE id = $1 AND organiser_id = $2 AND status = 'open'
          `,
          [eventId, organiserId]
        );
        await client.query("COMMIT");
      } else {
        await client.query("ROLLBACK");
      }
      return res.status(400).json({ error: "Completed events cannot be cancelled" });
    }

    await client.query(
      `
      UPDATE events
      SET status = 'closed'
      WHERE id = $1 AND organiser_id = $2
      `,
      [eventId, organiserId]
    );

    const cancelledApplications = await client.query(
      `
      UPDATE applications
      SET status = 'cancelled',
          admin_cancel_reason = $1
      WHERE event_id = $2
        AND status IN ('pending', 'accepted', 'approved', 'waitlisted')
      RETURNING volunteer_id
      `,
      [reason, eventId]
    );

    await client.query("COMMIT");

    res.json({
      message: "Event cancelled successfully",
      reason,
    });

    try {
      const volunteerIds = [
        ...new Set(cancelledApplications.rows.map((r) => r.volunteer_id)),
      ];
      if (volunteerIds.length > 0) {
        await notifyUsers(volunteerIds, {
          title: "Event cancelled",
          body: `${event.title} was cancelled by organiser. Reason: ${reason}`,
          data: { type: "event_cancelled", eventId: String(eventId), reason },
        });
      }
    } catch (notifyErr) {
      console.error("EVENT CANCEL NOTIFY ERROR:", notifyErr);
    }
  } catch (err) {
    try {
      await client.query("ROLLBACK");
    } catch (_) {}
    console.error("CANCEL EVENT ERROR:", err);
    res.status(500).json({ error: "Failed to cancel event" });
  } finally {
    client.release();
  }
};

// =======================================================
// ANNOUNCE EVENT (ORGANISER)
// =======================================================
exports.announceEvent = async (req, res) => {
  try {
    if (req.user?.role !== "organiser") {
      return res.status(403).json({ error: "Only organisers can announce events" });
    }

    const organiserId = req.user.id;
    const eventId = Number.parseInt(req.params.id, 10);
    const message = (req.body?.message || "").toString().trim();

    if (!Number.isInteger(eventId) || eventId <= 0) {
      return res.status(400).json({ error: "Invalid event id" });
    }

    if (!message) {
      return res.status(400).json({ error: "Announcement message is required" });
    }

    if (message.length > 500) {
      return res.status(400).json({ error: "Announcement message is too long" });
    }

    const eventResult = await pool.query(
      `
      SELECT id, title, status
      FROM events
      WHERE id = $1 AND organiser_id = $2
      `,
      [eventId, organiserId]
    );

    if (eventResult.rowCount === 0) {
      return res.status(404).json({ error: "Event not found" });
    }

    const event = eventResult.rows[0];
    if (event.status === "draft") {
      return res.status(400).json({ error: "Draft events cannot send announcements" });
    }
    if (event.status === "deleted") {
      return res.status(400).json({ error: "Deleted events cannot send announcements" });
    }

    const volunteerResult = await pool.query(
      `
      SELECT DISTINCT volunteer_id
      FROM applications
      WHERE event_id = $1
        AND status IN ('approved', 'accepted', 'completed')
      `,
      [eventId]
    );

    const volunteerIds = volunteerResult.rows
      .map((row) => row.volunteer_id)
      .filter(Boolean);

    await notifyUsers(volunteerIds, {
      title: `Announcement: ${event.title}`,
      body: message,
      data: {
        type: "event_announcement",
        eventId: String(eventId),
        eventTitle: event.title,
      },
    });

    res.json({
      message: "Announcement sent successfully",
      recipients: volunteerIds.length,
    });
  } catch (err) {
    console.error("ANNOUNCE EVENT ERROR:", err);
    res.status(500).json({ error: "Failed to send announcement" });
  }
};

// =======================================================
// SUBMIT ATTENDANCE (ORGANISER)
// =======================================================
exports.submitAttendanceFeedback = async (req, res) => {
  const client = await pool.connect();
  try {
    if (req.user?.role !== "organiser") {
      return res.status(403).json({
        error: "Only organisers can submit attendance feedback",
      });
    }

    const organiserId = req.user.id;
    const eventId = Number.parseInt(req.params.id, 10);
    const attendanceRaw = req.body?.attendance;
    const absentVolunteerIdsRaw = req.body?.absentVolunteerIds;
    const summary = (req.body?.summary || "").toString().trim();

    if (!Number.isInteger(eventId) || eventId <= 0) {
      return res.status(400).json({ error: "Invalid event id" });
    }

    if (attendanceRaw != null && !Array.isArray(attendanceRaw)) {
      return res.status(400).json({ error: "attendance must be an array" });
    }

    if (summary.length > 1000) {
      return res.status(400).json({ error: "Summary is too long" });
    }

    const eventResult = await pool.query(
      `
      SELECT
        id,
        title,
        status,
        (
          NOW() >= (
            event_date + COALESCE(start_time, TIME '00:00:00')
          )
        ) AS has_started,
        (
          NOW() <= (
            COALESCE(end_date, event_date) + COALESCE(end_time, TIME '23:59:59')
            + INTERVAL '48 hours'
          )
        ) AS within_attendance_grace
      FROM events
      WHERE id = $1 AND organiser_id = $2
      `,
      [eventId, organiserId]
    );

    if (eventResult.rowCount === 0) {
      return res.status(404).json({ error: "Event not found" });
    }

    const event = eventResult.rows[0];
    if (event.status === "draft") {
      return res.status(400).json({
        error: "Attendance is not available for draft events",
      });
    }
    if (event.status === "deleted") {
      return res.status(400).json({
        error: "Attendance is not available for deleted events",
      });
    }
    if (event.status === "closed") {
      return res.status(400).json({
        error: "Attendance is not available for cancelled events",
      });
    }
    if (event.has_started !== true) {
      return res.status(400).json({
        error: "Attendance is available after event starts",
      });
    }
    if (event.status === "completed" && event.within_attendance_grace !== true) {
      const reopenAccessRes = await pool.query(
        `
        SELECT 1
        FROM reports
        WHERE target_type = 'event'
          AND target_id = $1
          AND reporter_id = $2
          AND status = 'resolved'
          AND action_taken = 'reopen_attendance'
          AND resolved_at >= NOW() - INTERVAL '24 hours'
        LIMIT 1
        `,
        [eventId, organiserId]
      );

      if (reopenAccessRes.rowCount === 0) {
        return res.status(400).json({
          error:
            "Attendance grace window has ended (48 hours after event end). Ask admin to reopen attendance.",
        });
      }
    }

    const approvedVolunteersResult = await pool.query(
      `
      SELECT
        a.id AS application_id,
        a.volunteer_id,
        u.name,
        COALESCE(a.attendance_status, 'unmarked') AS attendance_status,
        a.attendance_marked_at
      FROM applications a
      JOIN users u ON u.id = a.volunteer_id
      WHERE a.event_id = $1
        AND a.status IN ('approved', 'accepted', 'completed')
      ORDER BY u.name ASC
      `,
      [eventId]
    );

    const approvedRows = approvedVolunteersResult.rows;
    if (approvedRows.length === 0) {
      return res.json({
        message: "No approved volunteers found for this event.",
        absent_count: 0,
        present_count: 0,
        updated: 0,
      });
    }

    if (
      event.status === "completed" &&
      approvedRows.some((row) => row.attendance_marked_at != null)
    ) {
      return res.status(400).json({
        error: "Attendance is locked once it has been finalised for a completed event",
      });
    }

    const approvedIds = approvedRows.map((row) => Number(row.volunteer_id));
    const approvedIdSet = new Set(approvedIds);
    const attendanceMap = new Map();

    if (Array.isArray(attendanceRaw) && attendanceRaw.length > 0) {
      for (const item of attendanceRaw) {
        const volunteerId = Number.parseInt(
          item?.volunteerId ?? item?.volunteer_id,
          10
        );
        const status = normalizeAttendanceStatus(item?.status);

        if (!Number.isInteger(volunteerId) || volunteerId <= 0) {
          return res.status(400).json({
            error: "Each attendance row must include a valid volunteerId",
          });
        }

        if (!approvedIdSet.has(volunteerId)) {
          return res.status(400).json({
            error: "Attendance can only be submitted for approved volunteers",
          });
        }

        if (!["present", "absent"].includes(status)) {
          return res.status(400).json({
            error: "Attendance status must be either present or absent",
          });
        }

        attendanceMap.set(volunteerId, status);
      }

      const missingVolunteerIds = approvedIds.filter(
        (volunteerId) => !attendanceMap.has(volunteerId)
      );

      if (missingVolunteerIds.length > 0) {
        return res.status(400).json({
          error: "Attendance must be marked for every approved volunteer",
        });
      }
    } else if (Array.isArray(absentVolunteerIdsRaw)) {
      const uniqueAbsentIds = [
        ...new Set(
          absentVolunteerIdsRaw
            .map((id) => Number.parseInt(id, 10))
            .filter((id) => Number.isInteger(id) && id > 0)
        ),
      ];

      const invalidAbsentIds = uniqueAbsentIds.filter(
        (id) => !approvedIdSet.has(id)
      );
      if (invalidAbsentIds.length > 0) {
        return res.status(400).json({
          error:
            "All absent volunteers must be part of the approved volunteer list",
        });
      }

      for (const volunteerId of approvedIds) {
        attendanceMap.set(
          volunteerId,
          uniqueAbsentIds.includes(volunteerId) ? "absent" : "present"
        );
      }
    } else {
      return res.status(400).json({
        error: "Attendance data is required",
      });
    }

    const attendanceNotifications = approvedRows
      .map((row) => {
        const volunteerId = Number(row.volunteer_id);
        const applicationId = Number(row.application_id);
        const previousStatus = normalizeAttendanceStatus(row.attendance_status);
        const nextStatus = attendanceMap.get(volunteerId);

        if (
          !Number.isInteger(volunteerId) ||
          volunteerId <= 0 ||
          !Number.isInteger(applicationId) ||
          applicationId <= 0 ||
          !["present", "absent"].includes(nextStatus) ||
          previousStatus === nextStatus
        ) {
          return null;
        }

        return {
          volunteerId,
          applicationId,
          status: nextStatus,
        };
      })
      .filter(Boolean);

    await client.query("BEGIN");

    const caseStatusParts = [];
    const caseParams = [eventId];
    let parameterIndex = 2;

    for (const volunteerId of approvedIds) {
      const status = attendanceMap.get(volunteerId);
      caseStatusParts.push(
        `WHEN volunteer_id = $${parameterIndex} THEN $${parameterIndex + 1}`
      );
      caseParams.push(volunteerId, status);
      parameterIndex += 2;
    }

    await client.query(
      `
      UPDATE applications
      SET attendance_status = CASE
            ${caseStatusParts.join("\n            ")}
            ELSE COALESCE(attendance_status, 'unmarked')
          END,
          attendance_marked_at = NOW()
      WHERE event_id = $1
        AND volunteer_id = ANY($${parameterIndex}::int[])
        AND status IN ('approved', 'accepted', 'completed')
      `,
      [...caseParams, approvedIds]
    );

    let absentNotifications = [];
    if (event.status === "completed") {
      absentNotifications = await applyAttendanceCompletionEffects(client, {
        id: event.id,
        title: event.title,
        organiser_id: organiserId,
      });
    }

    await client.query("COMMIT");

    for (const item of attendanceNotifications) {
      if (event.status === "completed" && item.status === "absent") {
        continue;
      }

      try {
        await notifyUsers([item.volunteerId], {
          title: "Attendance updated",
          body:
            item.status === "present"
              ? `Your attendance for ${event.title} was marked present.`
              : `Your attendance for ${event.title} was marked absent.`,
          data: {
            type: "attendance_updated",
            eventId: String(eventId),
            applicationId: String(item.applicationId),
            attendanceStatus: item.status,
          },
        });
      } catch (notifyErr) {
        console.error("ATTENDANCE UPDATE NOTIFY ERROR:", notifyErr);
      }
    }

    for (const item of absentNotifications) {
      try {
        await notifyUsers([item.userId], {
          title: "Absent attendance recorded",
          body: `You were marked absent for ${item.eventTitle}. A strike was applied after the event was completed. You can submit an appeal with supporting documents.`,
          data: {
            type: "attendance_absent_strike",
            eventId: String(item.eventId),
            applicationId: String(item.applicationId),
            strikeCount: String(item.strikeCount ?? ""),
          },
        });
      } catch (notifyErr) {
        console.error("ATTENDANCE ABSENT NOTIFY ERROR:", notifyErr);
      }
    }

    const absentCount = approvedIds.filter(
      (volunteerId) => attendanceMap.get(volunteerId) === "absent"
    ).length;
    const presentCount = approvedIds.length - absentCount;

    res.json({
      message:
        absentCount > 0 && event.status === "completed"
          ? "Attendance saved. Absent volunteers were penalized because the event is already completed."
          : absentCount > 0
          ? "Attendance saved. Absent volunteers will receive a strike if the event completes with this attendance."
          : "Attendance saved. All volunteers marked present.",
      absent_count: absentCount,
      present_count: presentCount,
      updated: approvedIds.length,
    });
  } catch (err) {
    try {
      await client.query("ROLLBACK");
    } catch (_) {}
    console.error("SUBMIT ATTENDANCE FEEDBACK ERROR:", err);
    res.status(500).json({ error: "Failed to submit attendance feedback" });
  } finally {
    client.release();
  }
};

// =======================================================
// PUBLISH DRAFT EVENT (ORGANISER)
// =======================================================
exports.publishEvent = async (req, res) => {
  try {
    const organiserId = req.user.id;
    const eventId = req.params.id;

    const eventResult = await pool.query(
      `
      SELECT
        id,
        title,
        description,
        location,
        event_date,
        end_date,
        application_deadline,
        volunteers_required,
        event_type,
        payment_amount,
        payment_rate_type,
        payment_clearance_date,
        start_time,
        end_time,
        status,
        (
          SELECT COUNT(*)::int
          FROM event_categories ec
          WHERE ec.event_id = events.id
        ) AS category_count
      FROM events
      WHERE id = $1 AND organiser_id = $2
      `,
      [eventId, organiserId]
    );

    if (eventResult.rowCount === 0) {
      return res.status(404).json({ error: "Event not found" });
    }

    const event = eventResult.rows[0];
    if (event.status !== "draft") {
      return res
        .status(400)
        .json({ error: "Only draft events can be published" });
    }

    const missingFields = [];
    if (!hasMeaningfulText(event.description)) {
      missingFields.push("description");
    }
    if (!event.location || event.location.toString().trim() === "") {
      missingFields.push("location");
    }
    if (!event.event_date) missingFields.push("event_date");
    if (!event.end_date) missingFields.push("end_date");
    if (!event.application_deadline) {
      missingFields.push("application_deadline");
    }
    if (
      event.volunteers_required == null ||
      Number(event.volunteers_required) < 1
    ) {
      missingFields.push("volunteers_required");
    }
    if (!event.event_type || !["paid", "unpaid"].includes(event.event_type)) {
      missingFields.push("event_type");
    }
    if (!event.start_time) missingFields.push("start_time");
    if (!event.end_time) missingFields.push("end_time");
    if ((event.category_count ?? 0) < 1) {
      missingFields.push("categories");
    }
    if (
      event.event_type === "paid" &&
      (!event.payment_amount || Number(event.payment_amount) <= 0)
    ) {
      missingFields.push("payment_amount");
    }
    if (
      event.event_type === "paid" &&
      !normalizePaymentRateType(event.payment_rate_type)
    ) {
      missingFields.push("payment_rate_type");
    }
    if (
      event.event_type === "paid" &&
      !event.payment_clearance_date
    ) {
      missingFields.push("payment_clearance_date");
    }
    if (
      event.event_type === "paid" &&
      event.payment_clearance_date &&
      !isDateOnOrAfter(event.payment_clearance_date, event.end_date)
    ) {
      return res.status(400).json({
        error: "Payment clearance date cannot be before the event end date",
      });
    }

    if (missingFields.length > 0) {
      return res.status(400).json({
        error: "Complete required event fields before publishing",
        missing_fields: missingFields,
      });
    }

    const updatedResult = await pool.query(
      `
      UPDATE events
      SET status = 'open'
      WHERE id = $1 AND organiser_id = $2
      RETURNING *
      `,
      [eventId, organiserId]
    );

    return res.status(200).json({
      message: "Event published successfully",
      event: updatedResult.rows[0],
    });
  } catch (err) {
    console.error("PUBLISH EVENT ERROR:", err);
    res.status(500).json({ error: "Failed to publish event" });
  }
};
