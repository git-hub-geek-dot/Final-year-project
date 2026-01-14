const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const pool = require("../config/db");

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

    // Basic validation
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

    // Check existing user
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

    // Hash password
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

    // 🔐 BLOCK INACTIVE / BANNED USERS
    if (user.status !== "active") {
      return res.status(403).json({
        success: false,
        message: "Account is deactivated. Please contact support.",
      });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: "Invalid credentials",
      });
    }

    // 🔑 JWT WITH USER ID + ROLE
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
