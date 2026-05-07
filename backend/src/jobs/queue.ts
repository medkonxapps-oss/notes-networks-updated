import { Queue } from 'bullmq';
import { redis } from '../config/redis';

const connection = redis;

export const processUploadQueue = new Queue('process-upload', { connection });
export const notifyFollowersQueue = new Queue('notify-followers', { connection });
export const leaderboardQueue = new Queue('leaderboard', { connection });
export const emailQueue = new Queue('email', { connection });

console.log('✅ BullMQ queues initialized');
