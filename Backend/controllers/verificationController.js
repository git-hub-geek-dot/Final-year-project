const pool = require("../config/db");

function normalizeRole(value) {
  return typeof value === "string" ? value.trim().toLowerCase() : "";
}

// ================= SUBMIT VERIFICATION REQUEST =================
exports.submitRequest = async (req, res) => {
  const client = await pool.connect();
  try {
    const userId = req.user.id;

    await client.query("BEGIN");

    // Lock the user row so duplicate submit attempts are serialized.
    const userResult = await client.query(
      'SELECT role, "isVerified" AS "isVerified" FROM users WHERE id = $1 FOR UPDATE',
      [userId]
    );

    if (userResult.rowCount === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ message: "User not found" });
    }

    const user = userResult.rows[0];
    const accountRole = normalizeRole(user.role);

    if (!["volunteer", "organiser"].includes(accountRole)) {
      await client.query("ROLLBACK");
      return res.status(403).json({
        message: "Only volunteers and organisers can request verification",
      });
    }

    if (user.isVerified) {
      await client.query("ROLLBACK");
      return res.status(400).json({ message: "User already verified" });
    }

    const {
      role,
      idType,
      idNumber,
      idDocumentUrl,
      selfieUrl,
      organisationName,
      eventProofUrl,
      websiteLink,
    } = req.body;

    const requestedRole = normalizeRole(role);
    if (requestedRole && requestedRole !== accountRole) {
      await client.query("ROLLBACK");
      return res.status(400).json({
        message: "Verification role must match your account role",
      });
    }

    const trimmedIdType =
      typeof idType === "string" ? idType.trim().toLowerCase() : "";
    const trimmedIdNumber = String(idNumber || "").trim();
    const trimmedIdDocumentUrl =
      typeof idDocumentUrl === "string" ? idDocumentUrl.trim() : "";
    const trimmedSelfieUrl =
      typeof selfieUrl === "string" ? selfieUrl.trim() : "";
    const trimmedOrganisationName =
      typeof organisationName === "string" ? organisationName.trim() : "";
    const trimmedEventProofUrl =
      typeof eventProofUrl === "string" ? eventProofUrl.trim() : "";
    const trimmedWebsiteLink =
      typeof websiteLink === "string" ? websiteLink.trim() : "";

    // ------------------ SERVER-SIDE VALIDATION ------------------
    if (!trimmedIdType) {
      await client.query("ROLLBACK");
      return res.status(400).json({ message: "ID type is required" });
    }

    if (!trimmedIdNumber || trimmedIdNumber.length < 3) {
      await client.query("ROLLBACK");
      return res.status(400).json({ message: "Valid ID number is required" });
    }

    if (!trimmedIdDocumentUrl) {
      await client.query("ROLLBACK");
      return res.status(400).json({ message: "ID document URL is required" });
    }

    if (!trimmedSelfieUrl) {
      await client.query("ROLLBACK");
      return res.status(400).json({ message: "Selfie URL is required" });
    }

    if (accountRole === "organiser" && !trimmedOrganisationName) {
      await client.query("ROLLBACK");
      return res.status(400).json({
        message: "Organisation name is required for organisers",
      });
    }
    // ------------------------------------------------------------

    const existing = await client.query(
      "SELECT id FROM verification_requests WHERE user_id = $1 AND status = 'pending' LIMIT 1",
      [userId]
    );

    if (existing.rowCount > 0) {
      await client.query("ROLLBACK");
      return res
        .status(400)
        .json({ message: "Verification already under review" });
    }

    const insertQuery = `
      INSERT INTO verification_requests
      (user_id, role, id_type, id_number, id_document_url, selfie_url,
       organisation_name, event_proof_url, website_link, status, created_at, updated_at)
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,'pending',NOW(),NOW())
      RETURNING *
    `;

    const values = [
      userId,
      accountRole,
      trimmedIdType,
      trimmedIdNumber,
      trimmedIdDocumentUrl,
      trimmedSelfieUrl,
      trimmedOrganisationName || null,
      trimmedEventProofUrl || null,
      trimmedWebsiteLink || null,
    ];

    const result = await client.query(insertQuery, values);
    await client.query("COMMIT");

    res.status(201).json({
      message: "Verification request submitted",
      request: result.rows[0],
    });
  } catch (err) {
    try {
      await client.query("ROLLBACK");
    } catch (_) {}

    if (err?.code === "23505") {
      return res
        .status(400)
        .json({ message: "Verification already under review" });
    }

    console.error("VERIFICATION SUBMIT ERROR:", err);
    res.status(500).json({ message: "Server error" });
  } finally {
    client.release();
  }
};

// ================= GET VERIFICATION STATUS =================
exports.getStatus = async (req, res) => {
  try {
    const userId = req.user.id;

    const userResult = await pool.query(
      'SELECT "isVerified" AS "isVerified" FROM users WHERE id = $1',
      [userId]
    );

    if (userResult.rows[0]?.isVerified === true) {
      return res.json({ status: "approved" });
    }

    const result = await pool.query(
      `SELECT status
       FROM verification_requests
       WHERE user_id = $1
       ORDER BY created_at DESC
       LIMIT 1`,
      [userId]
    );

    if (result.rows.length === 0) {
      return res.json({ status: "not_requested" });
    }

    res.json({ status: result.rows[0].status });
  } catch (err) {
    console.error("VERIFICATION STATUS ERROR:", err);
    res.status(500).json({ message: "Server error" });
  }
};
