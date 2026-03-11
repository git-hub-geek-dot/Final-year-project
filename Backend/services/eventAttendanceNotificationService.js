const pool = require("../config/db");
const { notifyUser } = require("./notificationService");

const ATTENDANCE_FEEDBACK_REQUIRED_TYPE = "attendance_feedback_required";

const buildPayload = (event) => {
  const appeared = Number(event.appeared_count) || 0;
  const required = Number(event.volunteers_required) || 0;
  const ratio = required > 0 ? `${appeared}/${required}` : `${appeared}`;
  const absentExpected = required > appeared ? required - appeared : 0;
  const absentLine =
    required > 0
      ? ` Missing: ${absentExpected}.`
      : " Review absentees if any.";

  return {
    title: "Attendance feedback required",
    body: `${event.title}: ${ratio} volunteers marked present.${absentLine} Tap to submit attendance feedback to admin.`,
    data: {
      type: ATTENDANCE_FEEDBACK_REQUIRED_TYPE,
      eventId: String(event.id),
      appearedCount: String(appeared),
      volunteersRequired: String(required),
      absentExpected: String(absentExpected),
    },
  };
};

const notifyOngoingAttendanceUpdates = async () => {
  const result = await pool.query(
    `
    WITH ongoing_events AS (
      SELECT
        e.id,
        e.title,
        e.organiser_id,
        COALESCE(e.volunteers_required, 0)::int AS volunteers_required,
        COALESCE(
          COUNT(a.id) FILTER (WHERE a.status IN ('approved', 'accepted', 'completed')),
          0
        )::int AS appeared_count
      FROM events e
      LEFT JOIN applications a
        ON a.event_id = e.id
      WHERE e.status = 'open'
        AND NOW() BETWEEN
          (e.event_date + COALESCE(e.start_time, TIME '00:00:00'))
          AND
          (COALESCE(e.end_date, e.event_date) + COALESCE(e.end_time, TIME '23:59:59'))
      GROUP BY e.id, e.title, e.organiser_id, e.volunteers_required
    )
    SELECT
      o.id,
      o.title,
      o.organiser_id,
      o.volunteers_required,
      o.appeared_count
    FROM ongoing_events o
    WHERE o.appeared_count > 0
      AND NOT EXISTS (
        SELECT 1
        FROM notifications n
        WHERE n.user_id = o.organiser_id
          AND n.data ->> 'type' = $1
          AND n.data ->> 'eventId' = o.id::text
          AND n.data ->> 'appearedCount' = o.appeared_count::text
      )
    ORDER BY o.id ASC
    LIMIT 200
    `,
    [ATTENDANCE_FEEDBACK_REQUIRED_TYPE]
  );

  for (const event of result.rows) {
    await notifyUser(event.organiser_id, buildPayload(event));
  }

  return result.rowCount;
};

const notifyOngoingAttendanceUpdatesForOrganiser = async (organiserId) => {
  if (!organiserId) return 0;

  const result = await pool.query(
    `
    WITH ongoing_events AS (
      SELECT
        e.id,
        e.title,
        e.organiser_id,
        COALESCE(e.volunteers_required, 0)::int AS volunteers_required,
        COALESCE(
          COUNT(a.id) FILTER (WHERE a.status IN ('approved', 'accepted', 'completed')),
          0
        )::int AS appeared_count
      FROM events e
      LEFT JOIN applications a
        ON a.event_id = e.id
      WHERE e.status = 'open'
        AND e.organiser_id = $2
        AND NOW() BETWEEN
          (e.event_date + COALESCE(e.start_time, TIME '00:00:00'))
          AND
          (COALESCE(e.end_date, e.event_date) + COALESCE(e.end_time, TIME '23:59:59'))
      GROUP BY e.id, e.title, e.organiser_id, e.volunteers_required
    )
    SELECT
      o.id,
      o.title,
      o.organiser_id,
      o.volunteers_required,
      o.appeared_count
    FROM ongoing_events o
    WHERE o.appeared_count > 0
      AND NOT EXISTS (
        SELECT 1
        FROM notifications n
        WHERE n.user_id = o.organiser_id
          AND n.data ->> 'type' = $1
          AND n.data ->> 'eventId' = o.id::text
          AND n.data ->> 'appearedCount' = o.appeared_count::text
      )
    ORDER BY o.id ASC
    LIMIT 50
    `,
    [ATTENDANCE_FEEDBACK_REQUIRED_TYPE, organiserId]
  );

  for (const event of result.rows) {
    await notifyUser(event.organiser_id, buildPayload(event));
  }

  return result.rowCount;
};

module.exports = {
  notifyOngoingAttendanceUpdates,
  notifyOngoingAttendanceUpdatesForOrganiser,
};
