const express = require("express");
const router = express.Router();

const authMiddleware = require("../middleware/auth");
const groupChatController = require("../controllers/groupChatController");

router.get(
  "/chat/group/:eventId/messages",
  authMiddleware,
  groupChatController.getEventGroupMessages
);

router.post(
  "/chat/group/:eventId/messages",
  authMiddleware,
  groupChatController.sendEventGroupMessage
);

module.exports = router;
