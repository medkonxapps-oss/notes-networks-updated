import { Router } from 'express';
import { redis } from '../config/redis';
import { supabase } from '../config/supabase';

const router = Router();

router.get('/health', async (_, res) => {
  const checks: Record<string, string> = {};

  // Redis
  try {
    await redis.ping();
    checks.redis = 'ok';
  } catch {
    checks.redis = 'error';
  }

  // Supabase
  try {
    await supabase.from('feature_flags').select('id').limit(1);
    checks.supabase = 'ok';
  } catch {
    checks.supabase = 'error';
  }

  const allOk = Object.values(checks).every((v) => v === 'ok');
  res.status(allOk ? 200 : 503).json({
    status: allOk ? 'healthy' : 'degraded',
    checks,
    timestamp: new Date().toISOString(),
  });
});

export default router;
