const express = require("express");
const router = express.Router();

const authMiddleware = require("../middleware/auth");
const chatController = require("../controllers/chatController");

router.post("/chat/thread", authMiddleware, chatController.getOrCreateThread);
router.get("/chat/threads", authMiddleware, chatController.getThreads);
router.get(
  "/chat/thread/:threadId/messages",
  authMiddleware,
  chatController.getMessages
);
router.post(
  "/chat/thread/:threadId/messages",
  authMiddleware,
  chatController.sendMessage
);

module.exports = router;
