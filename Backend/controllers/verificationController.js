const pool = require("../config/db");

// ================= SUBMIT VERIFICATION REQUEST =================
exports.submitRequest = async (req, res) => {
  try {
    const userId = req.user.id;

    // 🔒 Check if user already verified
    const userResult = await pool.query(
      'SELECT "isVerified" AS "isVerified" FROM users WHERE id = $1',
      [userId]
    );

    if (userResult.rows[0]?.isVerified) {
      return res.status(400).json({ message: "User already verified" });
    }

    // 🔒 Check for existing pending request
    const existing = await pool.query(
      "SELECT id FROM verification_requests WHERE user_id = $1 AND status = 'pending'",
      [userId]
    );

    if (existing.rows.length > 0) {
      return res
        .status(400)
        .json({ message: "Verification already under review" });
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

    // ------------------ SERVER-SIDE VALIDATION ------------------
    if (!role) {
      return res.status(400).json({ message: "Role is required" });
    }

    if (!idType) {
      return res.status(400).json({ message: "ID type is required" });
    }

    if (!idNumber || idNumber.toString().trim().length < 3) {
      return res.status(400).json({ message: "Valid ID number is required" });
    }

    if (!idDocumentUrl || idDocumentUrl.toString().trim() === "") {
      return res.status(400).json({ message: "ID document URL is required" });
    }

    if (!selfieUrl || selfieUrl.toString().trim() === "") {
      return res.status(400).json({ message: "Selfie URL is required" });
    }
    // ------------------------------------------------------------

    const insertQuery = `
      INSERT INTO verification_requests
      (user_id, role, id_type, id_number, id_document_url, selfie_url,
       organisation_name, event_proof_url, website_link, status, created_at, updated_at)
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,'pending',NOW(),NOW())
      RETURNING *
    `;

    const values = [
      userId,
      role,
      idType,
      idNumber,
      idDocumentUrl,
      selfieUrl,
      organisationName,
      eventProofUrl,
      websiteLink,
    ];

    const result = await pool.query(insertQuery, values);

    res.status(201).json({
      message: "Verification request submitted",
      request: result.rows[0],
    });
  } catch (err) {
    console.error("VERIFICATION SUBMIT ERROR:", err);
    res.status(500).json({ message: "Server error" });
  }
};

// ================= GET VERIFICATION STATUS =================
exports.getStatus = async (req, res) => {
  try {
    const userId = req.user.id;

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
