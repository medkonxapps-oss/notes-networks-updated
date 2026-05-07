import { Redis } from 'ioredis';
import dotenv from 'dotenv';
dotenv.config();

export const redis = new Redis(process.env.REDIS_URL || 'redis://127.0.0.1:6379', {
  maxRetriesPerRequest: null, // Required for BullMQ
});

redis.on('error', (err) => console.error('Redis error:', err));
redis.on('connect', () => console.log('✅ Redis connected'));
