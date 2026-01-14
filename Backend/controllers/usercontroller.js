const deleteUser = async (req, res) => {
  const userId = parseInt(req.params.id);

  try {
    // TODO: add real DB deletion logic later

    return res.status(200).json({
      success: true,
      message: `User ${userId} deleted successfully (mock)`,
    });
  } catch (error) {
    console.error(error);

    return res.status(500).json({
      success: false,
      message: "User deletion failed",
    });
  }
};

module.exports = {
  deleteUser,
};
