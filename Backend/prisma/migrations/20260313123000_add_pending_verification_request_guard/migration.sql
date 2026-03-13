-- Keep the newest pending request per user so the unique partial index can be added safely.
WITH ranked_pending AS (
    SELECT
        id,
        user_id,
        ROW_NUMBER() OVER (
            PARTITION BY user_id
            ORDER BY created_at DESC, id DESC
        ) AS row_num
    FROM verification_requests
    WHERE status = 'pending'
)
UPDATE verification_requests AS vr
SET
    status = 'rejected',
    admin_remark = COALESCE(
        vr.admin_remark,
        'Superseded by a newer pending verification request.'
    ),
    updated_at = NOW()
FROM ranked_pending AS rp
WHERE vr.id = rp.id
  AND rp.row_num > 1;

CREATE UNIQUE INDEX IF NOT EXISTS verification_requests_one_pending_per_user_idx
ON verification_requests (user_id)
WHERE status = 'pending';
