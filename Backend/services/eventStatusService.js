const pool = require("../config/db");

const markOverdueEventsCompleted = async () => {
  const result = await pool.query(
    `
    UPDATE events
    SET status = 'completed'
    WHERE status = 'open'
      AND NOW() >= (
        COALESCE(end_date, event_date)
        + COALESCE(end_time, TIME '23:59:59')
      )
    RETURNING id
    `
  );

  return result.rowCount;
};

module.exports = {
  markOverdueEventsCompleted,
};

