const pool = require("../config/db");
const { applyStrike } = require("./strikeService");
const { notifyUser } = require("./notificationService");

const applyAttendanceCompletionEffects = async (client, event) => {
  const absentNotifications = [];

  await client.query(
    `
    UPDATE applications
    SET status = 'completed'
    WHERE event_id = $1
      AND status IN ('approved', 'accepted')
    `,
    [event.id]
  );

  const absentApplicationsResult = await client.query(
    `
    SELECT id, volunteer_id
    FROM applications
    WHERE event_id = $1
      AND status = 'completed'
      AND COALESCE(attendance_status, 'unmarked') = 'absent'
      AND strike_issued = FALSE
    FOR UPDATE
    `,
    [event.id]
  );

  for (const application of absentApplicationsResult.rows) {
    const strikeResult = await applyStrike(client, {
      userId: application.volunteer_id,
      adminId: event.organiser_id,
      reason: `Absent when event completed: ${event.title}`,
    });

    await client.query(
      `
      UPDATE applications
      SET strike_issued = TRUE,
          strike_appeal_status = CASE
            WHEN COALESCE(strike_appeal_status, 'none') IN ('none', '')
              THEN 'eligible'
            ELSE strike_appeal_status
          END
      WHERE id = $1
      `,
      [application.id]
    );

    absentNotifications.push({
      userId: application.volunteer_id,
      applicationId: application.id,
      eventId: event.id,
      eventTitle: event.title,
      strikeCount: strikeResult.strikeCount,
    });
  }

  return absentNotifications;
};

const markOverdueEventsCompleted = async () => {
  const client = await pool.connect();
  const absentNotifications = [];

  try {
    await client.query("BEGIN");

    const completedEventsResult = await client.query(
      `
      UPDATE events
      SET status = 'completed'
      WHERE status = 'open'
        AND NOW() >= (
          COALESCE(end_date, event_date)
          + COALESCE(end_time, TIME '23:59:59')
        )
      RETURNING id, title, organiser_id
      `
    );

    const completedEvents = completedEventsResult.rows;

    for (const event of completedEvents) {
      absentNotifications.push(
        ...(await applyAttendanceCompletionEffects(client, event))
      );
    }

    await client.query("COMMIT");

    for (const item of absentNotifications) {
      try {
        await notifyUser(item.userId, {
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

    return completedEvents.length;
  } catch (err) {
    try {
      await client.query("ROLLBACK");
    } catch (_) {}
    throw err;
  } finally {
    client.release();
  }
};

module.exports = {
  applyAttendanceCompletionEffects,
  markOverdueEventsCompleted,
};
