const jwt = require("jsonwebtoken");
const pool = require("../config/db");

module.exports = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return res.status(401).json({
        success: false,
        message: "Authorization token missing",
      });
    }

    const token = authHeader.split(" ")[1];
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    if (!decoded.id) {
      return res.status(401).json({
        success: false,
        message: "Invalid token payload",
      });
    }

    const userResult = await pool.query(
      `SELECT status, suspended_until, suspension_reason
       FROM users
       WHERE id = $1`,
      [decoded.id]
    );

    if (userResult.rowCount === 0) {
      return res.status(401).json({
        success: false,
        message: "Invalid token",
      });
    }

    const user = userResult.rows[0];
    if (user.status !== "active") {
      return res.status(403).json({
        success: false,
        message:
          user.status === "banned"
            ? "Account is banned. Please contact support."
            : "Account is inactive. Please contact support.",
      });
    }

    if (user.suspended_until) {
      const until = new Date(user.suspended_until);
      if (until.getTime() > Date.now()) {
        return res.status(403).json({
          success: false,
          message: user.suspension_reason
            ? `Account suspended until ${until.toISOString()}. Reason: ${user.suspension_reason}`
            : `Account suspended until ${until.toISOString()}`,
        });
      }
    }

    req.user = {
      id: decoded.id,
      role: decoded.role,
    };

    next();
  } catch (err) {
    console.error("AUTH ERROR:", err.message);

    return res.status(401).json({
      success: false,
      message: "Invalid or expired token",
    });
  }
};
