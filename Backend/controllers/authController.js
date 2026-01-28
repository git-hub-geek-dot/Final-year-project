const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const pool = require("../config/db");
const transporter = require("../config/email");

// ================= REGISTER =================
exports.register = async (req, res) => {
  try {
    const {
      name,
      email,
      password,
      role,
      contact_number,
      city,
      government_id,
    } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({
        success: false,
        message: "Name, email and password are required",
      });
    }

    const finalRole = role ?? "volunteer";

    // Allowed roles
    if (!["volunteer", "organiser", "admin"].includes(finalRole)) {
      return res.status(400).json({
        success: false,
        message: "Invalid role",
      });
    }

    // Organiser-specific validation
    if (finalRole === "organiser" && !contact_number) {
      return res.status(400).json({
        success: false,
        message: "Contact number is required for organiser",
      });
    }

    const existing = await pool.query(
      "SELECT id FROM users WHERE email = $1",
      [email]
    );

    if (existing.rows.length > 0) {
      return res.status(400).json({
        success: false,
        message: "Email already exists",
      });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    // Insert user (status defaults to 'active')
    await pool.query(
      `
      INSERT INTO users
      (name, email, password, role, contact_number, city, government_id, status)
      VALUES ($1, $2, $3, $4, $5, $6, $7, 'active')
      `,
      [
        name,
        email,
        hashedPassword,
        finalRole,
        finalRole === "organiser" ? contact_number ?? null : null,
        finalRole === "volunteer" ? city ?? null : null,
        finalRole === "organiser" ? government_id ?? null : null,
      ]
    );

    res.status(201).json({
      success: true,
      message: "User registered successfully",
    });
  } catch (err) {
    console.error("REGISTER ERROR:", err);
    res.status(500).json({
      success: false,
      message: "Internal server error",
    });
  }
};

// ================= LOGIN =================
exports.login = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: "Email and password are required",
      });
    }

    const result = await pool.query(
      `
      SELECT id, name, email, password, role, status
      FROM users
      WHERE email = $1
      `,
      [email]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({
        success: false,
        message: "Invalid credentials",
      });
    }

    const user = result.rows[0];

    // Block inactive / banned users
    if (user.status !== "active") {
      const isBanned = user.status === "banned";
      return res.status(403).json({
        success: false,
        message: isBanned
            ? "Account is banned. Please contact support."
            : "Account is inactive. Please contact support.",
      });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: "Invalid credentials",
      });
    }

    // JWT token
    const token = jwt.sign(
      { id: user.id, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: "1d" }
    );

    res.status(200).json({
      success: true,
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
      },
    });
  } catch (err) {
    console.error("LOGIN ERROR:", err);
    res.status(500).json({
      success: false,
      message: "Internal server error",
    });
  }
};

// ================= GET PROFILE =================
exports.getProfile = async (req, res) => {
  try {
    const userId = req.user.id;

    const result = await pool.query(
      `SELECT id, name, email, city, role, contact_number, profile_picture_url
       FROM users
       WHERE id = $1`,
      [userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ message: "User not found" });
    }

    res.status(200).json(result.rows[0]);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: "Failed to fetch profile" });
  }
};

// ================= UPDATE PROFILE =================
exports.updateProfile = async (req, res) => {
  try {
    const userId = req.user?.id;
    const { name, city, contact_number } = req.body;

    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    if (!name) {
      return res.status(400).json({ error: "Name is required" });
    }

    const result = await pool.query(
      `
      UPDATE users
      SET name = $1,
          city = $2,
          contact_number = $3
      WHERE id = $4
      RETURNING id, name, email, role, city, contact_number
      `,
      [name, city ?? null, contact_number ?? null, userId]
    );

    return res.status(200).json({
      message: "Profile updated successfully",
      user: result.rows[0],
    });
  } catch (err) {
    console.error("UPDATE PROFILE ERROR:", err);
    return res.status(500).json({ error: "Internal server error" });
  }
};

// ================= DEACTIVATE ACCOUNT =================
exports.deactivateAccount = async (req, res) => {
  try {
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: "Unauthorized",
      });
    }

    const result = await pool.query(
      `
      UPDATE users
      SET status = 'inactive'
      WHERE id = $1
      RETURNING id, name, email, role, status
      `,
      [userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    return res.status(200).json({
      success: true,
      message: "Account deactivated successfully",
      user: result.rows[0],
    });
  } catch (err) {
    console.error("DEACTIVATE ERROR:", err);
    return res.status(500).json({
      success: false,
      message: "Internal server error",
    });
  }
};

// ================= FORGOT PASSWORD =================
exports.forgotPassword = async (req, res) => {
  try {
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({
        success: false,
        message: "Email is required",
      });
    }

    const result = await pool.query(
      "SELECT id, name, email FROM users WHERE email = $1",
      [email]
    );

    // Always respond success to avoid email enumeration
    if (result.rows.length === 0) {
      return res.status(200).json({
        success: true,
        message: "If the email exists, a reset link has been sent.",
      });
    }

    const user = result.rows[0];
    const resetSecret =
      process.env.RESET_PASSWORD_SECRET || process.env.JWT_SECRET;

    const token = jwt.sign(
      { id: user.id, email: user.email },
      resetSecret,
      { expiresIn: "15m" }
    );

    const resetUrlBase = process.env.RESET_PASSWORD_URL || "";
    const resetUrl = resetUrlBase
      ? `${resetUrlBase}?token=${encodeURIComponent(token)}`
      : null;

    if (!process.env.SMTP_HOST) {
      return res.status(500).json({
        success: false,
        message: "Email service not configured",
      });
    }

    const fromAddress =
      process.env.EMAIL_FROM || process.env.SMTP_USER || "no-reply@volunteerx";

    const text =
      `Hi ${user.name || ""},\n\n` +
      "We received a request to reset your password.\n" +
      "Use the token below in the app to reset your password.\n\n" +
      `Reset Token: ${token}\n\n` +
      (resetUrl ? `Or open this link: ${resetUrl}\n\n` : "") +
      "This token expires in 15 minutes. If you did not request this, ignore this email.";

    const html = `
      <p>Hi ${user.name || ""},</p>
      <p>We received a request to reset your password.</p>
      <p><strong>Reset Token:</strong> ${token}</p>
      ${resetUrl ? `<p><a href="${resetUrl}">Reset Password</a></p>` : ""}
      <p>This token expires in 15 minutes. If you did not request this, ignore this email.</p>
    `;

    await transporter.sendMail({
      from: fromAddress,
      to: user.email,
      subject: "Password Reset - VolunteerX",
      text,
      html,
    });

    return res.status(200).json({
      success: true,
      message: "If the email exists, a reset link has been sent.",
    });
  } catch (err) {
    console.error("FORGOT PASSWORD ERROR:", err);
    return res.status(500).json({
      success: false,
      message: "Internal server error",
    });
  }
};

// ================= RESET PASSWORD =================
exports.resetPassword = async (req, res) => {
  try {
    const { token, password } = req.body;

    if (!token || !password) {
      return res.status(400).json({
        success: false,
        message: "Token and new password are required",
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        message: "Password must be at least 6 characters",
      });
    }

    const resetSecret =
      process.env.RESET_PASSWORD_SECRET || process.env.JWT_SECRET;

    let payload;
    try {
      payload = jwt.verify(token, resetSecret);
    } catch (err) {
      return res.status(400).json({
        success: false,
        message: "Invalid or expired token",
      });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const result = await pool.query(
      `
      UPDATE users
      SET password = $1
      WHERE id = $2
      RETURNING id, email
      `,
      [hashedPassword, payload.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    return res.status(200).json({
      success: true,
      message: "Password reset successful",
    });
  } catch (err) {
    console.error("RESET PASSWORD ERROR:", err);
    return res.status(500).json({
      success: false,
      message: "Internal server error",
    });
  }
};