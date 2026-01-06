const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const pool = require("../config/db");

// ================= REGISTER =================
exports.register = async (req, res) => {
  try {
    let {
      name,
      email,
      password,
      role,
      username,
      contact,
      gov_id
    } = req.body;

    // Validate required fields
    if (!name || !email || !password) {
      return res
        .status(400)
        .json({ error: "Name, email and password are required" });
    }

    let finalRole = role ?? "volunteer";

// enforce allowed roles
if (!["volunteer", "organiser", "admin"].includes(finalRole)) {
  return res.status(400).json({ error: "Invalid role" });
}


// organiser-specific validation
if (finalRole === "organiser") {
  if (!username || !contact) {
    return res.status(400).json({
      error: "Username and contact are required for organiser"
    });
  }
}



   

    // Check existing user
    const existing = await pool.query(
      "SELECT id FROM users WHERE email = $1",
      [email]
    );

    if (existing.rows.length > 0) {
      return res.status(400).json({ error: "Email already exists" });
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);

    // Insert user
    await pool.query(
  `
  INSERT INTO users
  (name, email, password, role, username, contact, gov_id)
  VALUES ($1, $2, $3, $4, $5, $6, $7)
  `,
  [
    name,
    email,
    hashedPassword,
    finalRole,
    finalRole === "organiser" ? username : null,
    finalRole === "organiser" ? contact : null,
    finalRole === "organiser" ? gov_id : null
  ]
);


    res.status(201).json({ message: "User registered successfully" });
  } catch (err) {
    console.error("REGISTER ERROR:", err);
    res.status(500).json({ error: "Internal server error" });
  }
};

// ================= LOGIN =================
exports.login = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res
        .status(400)
        .json({ error: "Email and password are required" });
    }

    const result = await pool.query(
      "SELECT id, password, role FROM users WHERE email = $1",
      [email]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: "Invalid credentials" });
    }

    const user = result.rows[0];

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(401).json({ error: "Invalid credentials" });
    }

    const token = jwt.sign(
      { id: user.id, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: "1d" }
    );

    res.json({
  token,
  user: {
    id: user.id,
    role: user.role
  }
});

  } catch (err) {
    console.error("LOGIN ERROR:", err);
    res.status(500).json({ error: "Internal server error" });
  }
};
