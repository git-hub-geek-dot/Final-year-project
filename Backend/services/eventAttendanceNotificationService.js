const pool = require("../config/db");
const { notifyUser } = require("./notificationService");

const ATTENDANCE_FEEDBACK_REQUIRED_TYPE = "attendance_feedback_required";

const buildPayload = (event) => {
  const expected = Number(event.expected_count) || 0;
  const marked = Number(event.marked_count) || 0;
  const present = Number(event.present_count) || 0;
  const absent = Number(event.absent_count) || 0;
  const unmarked = Math.max(expected - marked, 0);

  return {
    title: "Attendance update pending",
    body: `${event.title}: ${marked}/${expected} volunteers marked. Present: ${present}. Absent: ${absent}. Remaining: ${unmarked}. Tap to complete attendance.`,
    data: {
      type: ATTENDANCE_FEEDBACK_REQUIRED_TYPE,
      eventId: String(event.id),
      expectedCount: String(expected),
      markedCount: String(marked),
      presentCount: String(present),
      absentCount: String(absent),
      unmarkedCount: String(unmarked),
    },
  };
};

const buildAttendanceQuery = () => `
  WITH ongoing_events AS (
    SELECT
      e.id,
      e.title,
      e.organiser_id,
      COALESCE(
        COUNT(a.id) FILTER (WHERE a.status IN ('approved', 'accepted', 'completed')),
        0
      )::int AS expected_count,
      COALESCE(
        COUNT(a.id) FILTER (
          WHERE a.status IN ('approved', 'accepted', 'completed')
            AND COALESCE(a.attendance_status, 'unmarked') IN ('present', 'absent')
        ),
        0
      )::int AS marked_count,
      COALESCE(
        COUNT(a.id) FILTER (
          WHERE a.status IN ('approved', 'accepted', 'completed')
            AND COALESCE(a.attendance_status, 'unmarked') = 'present'
        ),
        0
      )::int AS present_count,
      COALESCE(
        COUNT(a.id) FILTER (
          WHERE a.status IN ('approved', 'accepted', 'completed')
            AND COALESCE(a.attendance_status, 'unmarked') = 'absent'
        ),
        0
      )::int AS absent_count
    FROM events e
    LEFT JOIN applications a
      ON a.event_id = e.id
    WHERE e.status = 'open'
      AND NOW() BETWEEN
        (e.event_date + COALESCE(e.start_time, TIME '00:00:00'))
        AND
        (COALESCE(e.end_date, e.event_date) + COALESCE(e.end_time, TIME '23:59:59'))
    GROUP BY e.id, e.title, e.organiser_id
  )
  SELECT
    o.id,
    o.title,
    o.organiser_id,
    o.expected_count,
    o.marked_count,
    o.present_count,
    o.absent_count
  FROM ongoing_events o
  WHERE o.expected_count > 0
    AND o.marked_count < o.expected_count
`;

const notifyOngoingAttendanceUpdates = async () => {
  const result = await pool.query(
    `
    ${buildAttendanceQuery()}
      AND NOT EXISTS (
        SELECT 1
        FROM notifications n
        WHERE n.user_id = o.organiser_id
          AND n.data ->> 'type' = $1
          AND n.data ->> 'eventId' = o.id::text
          AND n.data ->> 'markedCount' = o.marked_count::text
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
    ${buildAttendanceQuery()}
      AND o.organiser_id = $2
      AND NOT EXISTS (
        SELECT 1
        FROM notifications n
        WHERE n.user_id = o.organiser_id
          AND n.data ->> 'type' = $1
          AND n.data ->> 'eventId' = o.id::text
          AND n.data ->> 'markedCount' = o.marked_count::text
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
