const jwt = require("jsonwebtoken");

module.exports = (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    // ❌ No Authorization header
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return res.status(401).json({
        success: false,
        message: "Authorization token missing",
      });
    }

    const token = authHeader.split(" ")[1];

    // 🔐 Verify JWT
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // ❌ Token valid but no user ID
    if (!decoded.id) {
      return res.status(401).json({
        success: false,
        message: "Invalid token payload",
      });
    }

    // ✅ Attach only trusted fields
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
