const pool = require("../config/db");

/**
 * Auto-reject pending applications where the application deadline has passed
 * Volunteer sees: "Your application was not reviewed by the organiser before the deadline"
 */
const autoRejectExpiredPendingApplications = async () => {
  try {
    const result = await pool.query(
      `
      UPDATE applications
      SET 
        status = 'rejected',
        admin_cancel_reason = 'Your application was not reviewed by the organiser before the deadline'
      WHERE 
        status = 'pending'
        AND application_deadline IS NOT NULL
        AND application_deadline < CURRENT_DATE
      RETURNING id, volunteer_id, event_id, status
      `
    );

    if (result.rows.length > 0) {
      console.log(
        `[AUTO-REJECT] Rejected ${result.rows.length} pending applications past deadline`
      );
      result.rows.forEach((app) => {
        console.log(
          `  - App ID ${app.id}: Volunteer ${app.volunteer_id}, Event ${app.event_id}`
        );
      });
    }

    return result.rows;
  } catch (err) {
    console.error("AUTO-REJECT PENDING APPLICATIONS ERROR:", err);
    throw err;
  }
};

/**
 * Auto-reject pending applications for events that have already completed
 * Volunteer sees: "This event has already completed and applications are no longer being reviewed"
 */
const autoRejectPendingForCompletedEvents = async () => {
  try {
    const result = await pool.query(
      `
      UPDATE applications
      SET 
        status = 'rejected',
        admin_cancel_reason = 'This event has already completed and applications are no longer being reviewed'
      WHERE 
        status = 'pending'
        AND event_id IN (
          SELECT id FROM events WHERE status = 'completed'
        )
      RETURNING id, volunteer_id, event_id, status
      `
    );

    if (result.rows.length > 0) {
      console.log(
        `[AUTO-REJECT] Rejected ${result.rows.length} pending applications for completed events`
      );
    }

    return result.rows;
  } catch (err) {
    console.error("AUTO-REJECT PENDING FOR COMPLETED EVENTS ERROR:", err);
    throw err;
  }
};

/**
 * Run all pending application auto-reject logic
 * Call this periodically (e.g., daily via cron job) or after event completion
 */
const processPendingApplications = async () => {
  try {
    console.log("[PENDING APPS] Starting automatic processing...");

    const rejectedByDeadline = await autoRejectExpiredPendingApplications();
    const rejectedByCompletion = await autoRejectPendingForCompletedEvents();

    const total = rejectedByDeadline.length + rejectedByCompletion.length;
    console.log(`[PENDING APPS] Processed ${total} applications total`);

    return {
      success: true,
      rejectedByDeadline: rejectedByDeadline.length,
      rejectedByCompletion: rejectedByCompletion.length,
      total,
    };
  } catch (err) {
    console.error("PROCESS PENDING APPLICATIONS ERROR:", err);
    return {
      success: false,
      error: err.message,
    };
  }
};

module.exports = {
  autoRejectExpiredPendingApplications,
  autoRejectPendingForCompletedEvents,
  processPendingApplications,
};
