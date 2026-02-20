const pool = require("../config/db");
const { notifyUser } = require("./notificationService");

const EVENT_COMPLETED_TYPE = "event_completed";

const buildPayload = (event) => ({
  title: "Event completed",
  body: `${event.title || "Your event"} is completed. Please submit your rating.`,
  data: {
    type: EVENT_COMPLETED_TYPE,
    eventId: String(event.id),
  },
});

const notifyCompletedEventsForVolunteer = async (volunteerId) => {
  if (!volunteerId) return;

  const result = await pool.query(
    `
    SELECT
      e.id,
      e.title
    FROM applications a
    JOIN events e ON e.id = a.event_id
    WHERE a.volunteer_id = $1
      AND a.status IN ('approved', 'accepted', 'completed')
      AND e.status NOT IN ('draft', 'deleted')
      AND (
        e.status = 'completed'
        OR NOW() >= (
          COALESCE(e.end_date, e.event_date) + COALESCE(e.end_time, TIME '23:59:59')
        )
      )
      AND NOT EXISTS (
        SELECT 1
        FROM notifications n
        WHERE n.user_id = $1
          AND n.data ->> 'type' = $2
          AND n.data ->> 'eventId' = e.id::text
      )
    GROUP BY e.id, e.title, e.end_date, e.event_date
    ORDER BY COALESCE(e.end_date, e.event_date) DESC
    LIMIT 20
    `,
    [volunteerId, EVENT_COMPLETED_TYPE]
  );

  for (const event of result.rows) {
    await notifyUser(volunteerId, buildPayload(event));
  }
};

const notifyCompletedEventsForOrganiser = async (organiserId) => {
  if (!organiserId) return;

  const result = await pool.query(
    `
    SELECT
      e.id,
      e.title
    FROM events e
    WHERE e.organiser_id = $1
      AND e.status NOT IN ('draft', 'deleted')
      AND (
        e.status = 'completed'
        OR NOW() >= (
          COALESCE(e.end_date, e.event_date) + COALESCE(e.end_time, TIME '23:59:59')
        )
      )
      AND NOT EXISTS (
        SELECT 1
        FROM notifications n
        WHERE n.user_id = $1
          AND n.data ->> 'type' = $2
          AND n.data ->> 'eventId' = e.id::text
      )
    ORDER BY COALESCE(e.end_date, e.event_date) DESC
    LIMIT 20
    `,
    [organiserId, EVENT_COMPLETED_TYPE]
  );

  for (const event of result.rows) {
    await notifyUser(organiserId, buildPayload(event));
  }
};

module.exports = {
  notifyCompletedEventsForVolunteer,
  notifyCompletedEventsForOrganiser,
};

