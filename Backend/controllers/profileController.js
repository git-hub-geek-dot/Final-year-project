const pool = require("../config/db");
const fs = require("fs");
const path = require("path");

// ================= UPLOAD PROFILE PICTURE =================
exports.uploadProfilePicture = async (req, res) => {
  try {
    const userId = req.user?.id;

    console.log("UPLOAD PROFILE PICTURE - userId:", userId, "file:", req.file?.filename);

    if (!userId) {
      if (req.file) {
        try {
          fs.unlinkSync(path.join(__dirname, "..", "uploads", req.file.filename));
        } catch (e) {
          console.log("Could not delete file:", e.message);
        }
      }
      return res.status(401).json({ 
        success: false, 
        error: "Unauthorized" 
      });
    }

    if (!req.file) {
      return res.status(400).json({ 
        success: false, 
        error: "No file uploaded" 
      });
    }

    try {
      // Get old profile picture URL to delete old file if exists
      const oldUserResult = await pool.query(
        `SELECT profile_picture_url FROM users WHERE id = $1`,
        [userId]
      );

      const oldPictureUrl = oldUserResult.rows[0]?.profile_picture_url;

      // Build the image URL - handle localhost and production
      const host = req.get("host");
      const protocol = req.protocol || (req.secure ? "https" : "http");
      const imageUrl = `${protocol}://${host}/uploads/${req.file.filename}`;

      console.log("Image URL:", imageUrl);

      // Update database with new profile picture URL
      const result = await pool.query(
        `
        UPDATE users
        SET profile_picture_url = $1
        WHERE id = $2
        RETURNING id, name, email, role, city, contact_number, profile_picture_url
        `,
        [imageUrl, userId]
      );

      if (result.rowCount === 0) {
        console.log("User not found for id:", userId);
        // Delete uploaded file if user not found
        if (req.file) {
          try {
            fs.unlinkSync(path.join(__dirname, "..", "uploads", req.file.filename));
          } catch (e) {
            console.log("Could not delete file:", e.message);
          }
        }
        return res.status(404).json({ 
          success: false, 
          error: "User not found" 
        });
      }

      // Delete old profile picture file if it exists
      if (oldPictureUrl) {
        try {
          const oldFilename = oldPictureUrl.split("/").pop();
          const oldFilePath = path.join(__dirname, "..", "uploads", oldFilename);
          if (fs.existsSync(oldFilePath)) {
            fs.unlinkSync(oldFilePath);
            console.log("Old profile picture deleted:", oldFilePath);
          }
        } catch (err) {
          console.log("Could not delete old profile picture:", err.message);
        }
      }

      console.log("Profile picture uploaded successfully for user:", userId);
      return res.status(200).json({
        success: true,
        message: "Profile picture uploaded successfully",
        user: result.rows[0],
      });
    } catch (dbErr) {
      console.error("DATABASE ERROR:", dbErr);
      // Delete uploaded file on DB error
      if (req.file) {
        try {
          fs.unlinkSync(path.join(__dirname, "..", "uploads", req.file.filename));
        } catch (e) {
          console.log("Could not delete file:", e.message);
        }
      }
      throw dbErr;
    }
  } catch (err) {
    console.error("UPLOAD PROFILE PICTURE ERROR:", err);
    // Delete uploaded file on error
    if (req.file) {
      try {
        fs.unlinkSync(path.join(__dirname, "..", "uploads", req.file.filename));
      } catch (e) {
        console.log("Could not delete file:", e.message);
      }
    }
    return res.status(500).json({ 
      success: false, 
      error: "Internal server error",
      details: err.message
    });
  }
};

// ================= DELETE PROFILE PICTURE =================
exports.deleteProfilePicture = async (req, res) => {
  try {
    const userId = req.user?.id;

    console.log("DELETE PROFILE PICTURE - userId:", userId);

    if (!userId) {
      return res.status(401).json({ 
        success: false, 
        error: "Unauthorized" 
      });
    }

    // Get current profile picture URL
    const userResult = await pool.query(
      `SELECT profile_picture_url FROM users WHERE id = $1`,
      [userId]
    );

    if (userResult.rowCount === 0) {
      return res.status(404).json({ 
        success: false, 
        error: "User not found" 
      });
    }

    const profilePictureUrl = userResult.rows[0]?.profile_picture_url;

    // Delete the file from uploads folder
    if (profilePictureUrl) {
      try {
        const filename = profilePictureUrl.split("/").pop();
        const filePath = path.join(__dirname, "..", "uploads", filename);
        if (fs.existsSync(filePath)) {
          fs.unlinkSync(filePath);
          console.log("Profile picture file deleted:", filePath);
        }
      } catch (err) {
        console.log("Could not delete file from uploads:", err.message);
      }
    }

    // Clear profile picture URL from database
    const result = await pool.query(
      `
      UPDATE users
      SET profile_picture_url = NULL
      WHERE id = $1
      RETURNING id, name, email, role, city, contact_number, profile_picture_url
      `,
      [userId]
    );

    console.log("Profile picture removed successfully for user:", userId);
    return res.status(200).json({
      success: true,
      message: "Profile picture removed successfully",
      user: result.rows[0],
    });
  } catch (err) {
    console.error("DELETE PROFILE PICTURE ERROR:", err);
    return res.status(500).json({ 
      success: false, 
      error: "Internal server error",
      details: err.message
    });
  }
};

// ================= UPDATE PROFILE PICTURE =================
exports.updateProfilePicture = async (req, res) => {
  try {
    const userId = req.user?.id;
    const profilePictureUrl = req.body?.profilePictureUrl;

    console.log("UPDATE PROFILE PICTURE - userId:", userId, "url:", profilePictureUrl);

    if (!userId) {
      return res.status(401).json({ 
        success: false, 
        error: "Unauthorized" 
      });
    }

    if (!profilePictureUrl) {
      return res.status(400).json({ 
        success: false, 
        error: "Profile picture URL is required" 
      });
    }

    const result = await pool.query(
      `
      UPDATE users
      SET profile_picture_url = $1
      WHERE id = $2
      RETURNING id, name, email, role, city, contact_number, profile_picture_url
      `,
      [profilePictureUrl, userId]
    );

    if (result.rowCount === 0) {
      console.log("User not found for id:", userId);
      return res.status(404).json({ 
        success: false, 
        error: "User not found" 
      });
    }

    console.log("Profile picture updated successfully for user:", userId);
    return res.status(200).json({
      success: true,
      message: "Profile picture updated successfully",
      user: result.rows[0],
    });
  } catch (err) {
    console.error("UPDATE PROFILE PICTURE ERROR:", err);
    return res.status(500).json({ 
      success: false, 
      error: "Internal server error",
      details: err.message
    });
  }
};
