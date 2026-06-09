import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import cron from 'node-cron';
import webhookRouter from './routes/webhook';
import healthRouter from './routes/health';
import authRouter from './routes/auth';
import { processUploadWorker } from './jobs/processUpload';
import { pushNotificationWorker } from './jobs/sendPushNotification';
import { recomputeLeaderboard } from './jobs/recomputeLeaderboard';
import { runDailyStreakReset, sendStreakReminders, sendWeeklyLeaderboardNotification } from './jobs/streakJobs';

dotenv.config();

const app = express();
const PORT = parseInt(process.env.VPS_PORT || '3000', 10);

// ── Security Middleware ───────────────────────────────────────────────────────

// 1. Helmet: Secure HTTP headers
app.use(helmet());

// 2. Rate Limiting: Prevent DDoS/Brute Force
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per window
  standardHeaders: true,
  legacyHeaders: false,
  message: 'Too many requests from this IP, please try again after 15 minutes',
});

// Apply rate limiting to all requests
app.use(limiter);

// 3. CORS: Tighten origins
const allowedOrigins = [
  'https://notesnet.app',
  'https://admin.notesnet.app',
  'http://localhost:3000',
  'http://localhost:5173', // Common for local dev
];

app.use(cors({
  origin: (origin, callback) => {
    // Allow requests with no origin (like mobile apps)
    if (!origin) return callback(null, true);
    if (allowedOrigins.indexOf(origin) !== -1) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

// 4. Request Body Size Limit: Prevent large payload attacks
app.use(express.json({ limit: '1mb' }));  // Reduced from 5mb – webhook payloads should be small

// 5. Strip X-Powered-By header (already handled by helmet, but explicit)
app.disable('x-powered-by');

// 6. Request logging (non-sensitive)
app.use((req, _res, next) => {
  const id = Math.random().toString(36).slice(2, 9);
  (req as any)._reqId = id;
  console.log(`→ [${id}] ${req.method} ${req.path} from ${req.ip}`);
  next();
});

// ── Routes ────────────────────────────────────────────────────────────────────
app.use('/webhook', webhookRouter);
app.use('/auth', authRouter);
app.use('/', healthRouter);

// ── Cron Jobs ──────────────────────────────────────────────────────────────────

// Recompute leaderboard every hour
cron.schedule('0 * * * *', () => {
  recomputeLeaderboard();
});

// Reset broken streaks daily at midnight
cron.schedule('0 0 * * *', async () => {
  await runDailyStreakReset();
});

// Send streak reminders at 9 PM every day
cron.schedule('0 21 * * *', async () => {
  await sendStreakReminders();
});

// Weekly leaderboard notification — every Monday at 10 AM
cron.schedule('0 10 * * 1', async () => {
  await sendWeeklyLeaderboardNotification();
});

// ── Startup ───────────────────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`\n🚀 NotesNet Worker Server running on port ${PORT}`);
  console.log(`   Health: http://localhost:${PORT}/health`);
  console.log(`   Environment: ${process.env.NODE_ENV || 'development'}\n`);
});

// Run leaderboard on startup
recomputeLeaderboard();

export default app;
