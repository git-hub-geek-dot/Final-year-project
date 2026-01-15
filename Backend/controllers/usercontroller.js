const pool = require("../config/db");

const deleteUser = async (req, res) => {
  try {
    const userIdFromParams = Number(req.params.id);
    const userIdFromToken = req.user.id; // 🔐 FROM JWT

    // ❌ Invalid ID
    if (!userIdFromParams || isNaN(userIdFromParams)) {
      return res.status(400).json({
        success: false,
        message: "Invalid user ID",
      });
    }

    // 🔐 SECURITY CHECK
    if (userIdFromParams !== userIdFromToken) {
      return res.status(403).json({
        success: false,
        message: "You are not allowed to delete this account",
      });
    }

    console.log("SECURE DELETE USER:", userIdFromParams);

    const result = await pool.query(
      "UPDATE users SET status = $1 WHERE id = $2",
      ["inactive", userIdFromParams]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    return res.status(200).json({
      success: true,
      message: "Account deactivated successfully",
    });
  } catch (error) {
    console.error("Delete user error:", error);
    return res.status(500).json({
      success: false,
      message: "User deletion failed",
    });
  }
};

module.exports = { deleteUser };
