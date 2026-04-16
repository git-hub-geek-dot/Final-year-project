const pool = require("../config/db");
const { notifyUser } = require("./notificationService");

const ATTENDANCE_FEEDBACK_REQUIRED_TYPE = "attendance_feedback_required";
const ONGOING_PHASE = "ongoing";
const COMPLETED_GRACE_PHASE = "completed_grace";
const COMPLETED_REMINDER_INTERVAL = "6 hours";

const buildPayload = (event, { phase = ONGOING_PHASE } = {}) => {
  const expected = Number(event.expected_count) || 0;
  const marked = Number(event.marked_count) || 0;
  const present = Number(event.present_count) || 0;
  const absent = Number(event.absent_count) || 0;
  const unmarked = Math.max(expected - marked, 0);
  const isCompletedGrace = phase === COMPLETED_GRACE_PHASE;

  return {
    title: isCompletedGrace
      ? "Attendance reminder"
      : "Attendance update pending",
    body: isCompletedGrace
      ? `${event.title}: ${marked}/${expected} volunteers marked. Remaining: ${unmarked}. Event is completed and attendance is currently open.`
      : `${event.title}: ${marked}/${expected} volunteers marked. Present: ${present}. Absent: ${absent}. Remaining: ${unmarked}. Tap to complete attendance.`,
    data: {
      type: ATTENDANCE_FEEDBACK_REQUIRED_TYPE,
      phase,
      eventId: String(event.id),
      expectedCount: String(expected),
      markedCount: String(marked),
      presentCount: String(present),
      absentCount: String(absent),
      unmarkedCount: String(unmarked),
      ...(event.grace_deadline
        ? { graceDeadline: new Date(event.grace_deadline).toISOString() }
        : {}),
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

const buildCompletedGraceAttendanceQuery = () => `
  WITH completed_events AS (
    SELECT
      e.id,
      e.title,
      e.organiser_id,
      (
        COALESCE(e.end_date, e.event_date) + COALESCE(e.end_time, TIME '23:59:59')
        + INTERVAL '48 hours'
      ) AS grace_deadline,
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
    WHERE e.status = 'completed'
      AND (
        NOW() <= (
          COALESCE(e.end_date, e.event_date) + COALESCE(e.end_time, TIME '23:59:59')
          + INTERVAL '48 hours'
        )
        OR EXISTS (
          SELECT 1
          FROM reports r
          WHERE r.target_type = 'event'
            AND r.target_id = e.id
            AND r.reporter_id = e.organiser_id
            AND r.status = 'resolved'
            AND r.action_taken = 'reopen_attendance'
            AND r.resolved_at >= NOW() - INTERVAL '24 hours'
        )
      )
    GROUP BY e.id, e.title, e.organiser_id
  )
  SELECT
    c.id,
    c.title,
    c.organiser_id,
    c.expected_count,
    c.marked_count,
    c.present_count,
    c.absent_count,
    c.grace_deadline
  FROM completed_events c
  LEFT JOIN LATERAL (
    SELECT n.created_at
    FROM notifications n
    WHERE n.user_id = c.organiser_id
      AND n.data ->> 'type' = $1
      AND n.data ->> 'eventId' = c.id::text
      AND n.data ->> 'phase' = $2
    ORDER BY n.created_at DESC
    LIMIT 1
  ) last_notice ON TRUE
  WHERE c.expected_count > 0
    AND c.marked_count < c.expected_count
    AND (
      last_notice.created_at IS NULL
      OR last_notice.created_at <= NOW() - INTERVAL '${COMPLETED_REMINDER_INTERVAL}'
    )
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
          AND COALESCE(n.data ->> 'phase', $2) = $2
      )
    ORDER BY o.id ASC
    LIMIT 200
    `,
    [ATTENDANCE_FEEDBACK_REQUIRED_TYPE, ONGOING_PHASE]
  );

  for (const event of result.rows) {
    await notifyUser(event.organiser_id, buildPayload(event, { phase: ONGOING_PHASE }));
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
          AND COALESCE(n.data ->> 'phase', $3) = $3
      )
    ORDER BY o.id ASC
    LIMIT 50
    `,
    [ATTENDANCE_FEEDBACK_REQUIRED_TYPE, organiserId, ONGOING_PHASE]
  );

  for (const event of result.rows) {
    await notifyUser(event.organiser_id, buildPayload(event, { phase: ONGOING_PHASE }));
  }

  return result.rowCount;
};

const notifyCompletedAttendanceGraceReminders = async () => {
  const result = await pool.query(
    `
    ${buildCompletedGraceAttendanceQuery()}
    ORDER BY c.id ASC
    LIMIT 200
    `,
    [ATTENDANCE_FEEDBACK_REQUIRED_TYPE, COMPLETED_GRACE_PHASE]
  );

  for (const event of result.rows) {
    await notifyUser(
      event.organiser_id,
      buildPayload(event, { phase: COMPLETED_GRACE_PHASE })
    );
  }

  return result.rowCount;
};

module.exports = {
  notifyOngoingAttendanceUpdates,
  notifyOngoingAttendanceUpdatesForOrganiser,
  notifyCompletedAttendanceGraceReminders,
};
