import express from 'express';
import { deleteUser } from '../controllers/userController.js';

const router = express.Router();

// DELETE user by ID
router.delete('/users/:id', deleteUser);

export default router;
