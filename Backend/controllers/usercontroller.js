const pool = require("../config/db");

// ================= DELETE USER =================
const deleteUser = async (req, res) => {
  try {
    const userIdFromParams = Number(req.params.id);
    const userIdFromToken = req.user.id;

    if (!userIdFromParams || isNaN(userIdFromParams)) {
      return res.status(400).json({
        success: false,
        message: "Invalid user ID",
      });
    }

    if (userIdFromParams !== userIdFromToken) {
      return res.status(403).json({
        success: false,
        message: "You are not allowed to delete this account",
      });
    }

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

// ================= GET ORGANISER PROFILE =================
const getOrganiserProfile = async (req, res) => {
  try {
    const organiserId = Number(req.params.id);

    if (!organiserId || isNaN(organiserId)) {
      return res.status(400).json({ error: "Invalid organiser ID" });
    }

    const result = await pool.query(
      `
      SELECT
        id,
        name,
        email,
        city,
        contact_number,
        government_id
      FROM users
      WHERE id = $1 AND role = 'organiser'
      `,
      [organiserId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Organiser not found" });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error("Get organiser profile error:", error);
    res.status(500).json({ error: "Failed to fetch organiser profile" });
  }
};

// ================= UPDATE USER PROFILE =================
const updateUser = async (req, res) => {
  try {
    const userIdFromParams = Number(req.params.id);
    const userIdFromToken = req.user.id;

    if (!userIdFromParams || isNaN(userIdFromParams)) {
      return res.status(400).json({
        success: false,
        message: "Invalid user ID",
      });
    }

    if (userIdFromParams !== userIdFromToken) {
      return res.status(403).json({
        success: false,
        message: "Not authorized",
      });
    }

    const {
      name,
      email,
      city,
      contact_number,
      government_id,
    } = req.body;

    const result = await pool.query(
      `
      UPDATE users
      SET
        name = $1,
        email = $2,
        city = $3,
        contact_number = $4,
        government_id = $5
      WHERE id = $6
      RETURNING id, name, email, city, contact_number, government_id
      `,
      [
        name,
        email,
        city,
        contact_number,
        government_id || null,
        userIdFromParams,
      ]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    return res.status(200).json({
      success: true,
      message: "Profile updated successfully",
      user: result.rows[0],
    });
  } catch (error) {
    console.error("Update user error:", error);
    return res.status(500).json({
      success: false,
      message: "Profile update failed",
    });
  }
};

module.exports = {
  deleteUser,
  getOrganiserProfile,
  updateUser,
};
