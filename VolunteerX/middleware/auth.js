const jwt = require("jsonwebtoken");
const pool = require("../config/db");

const JWT_SECRET = "volunteerx_secret_key";

const authenticateToken = async (req, res, next) => {
  const authHeader = req.headers["authorization"];
  const token = authHeader && authHeader.split(" ")[1];

  if (!token) return res.status(401).json({ error: "Token missing" });

  jwt.verify(token, JWT_SECRET, async (err, user) => {
    if (err) return res.status(403).json({ error: "Invalid token" });

    const dbUser = await pool.query(
      "SELECT status FROM users WHERE id=$1",
      [user.id]
    );

    if (dbUser.rows[0]?.status === "blocked") {
      return res.status(403).json({ error: "User blocked by admin" });
    }

    req.user = user;
    next();
  });
};

module.exports = authenticateToken;
