-- Convert legacy no_show status to completed + absent attendance
UPDATE applications
SET status = 'completed',
    attendance_status = 'absent',
    attendance_marked_at = COALESCE(attendance_marked_at, NOW())
WHERE status = 'no_show';
