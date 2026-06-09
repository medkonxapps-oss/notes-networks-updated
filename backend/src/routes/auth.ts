import { Router, Request, Response } from 'express';
import { createClient } from '@supabase/supabase-js';
import crypto from 'crypto';

const router = Router();

// Admin client with service role key
const supabaseAdmin = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  }
);

// Regular client for user operations
const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_ANON_KEY!
);

// In-memory OTP storage (use Redis in production)
const otpStore = new Map<string, { otp: string; expiresAt: number; email: string }>();

// Clean expired OTPs every 5 minutes
setInterval(() => {
  const now = Date.now();
  for (const [key, value] of otpStore.entries()) {
    if (value.expiresAt < now) {
      otpStore.delete(key);
    }
  }
}, 5 * 60 * 1000);

/**
 * Generate 6-digit OTP
 */
function generateOTP(): string {
  return crypto.randomInt(100000, 999999).toString();
}

/**
 * POST /auth/send-password-reset-otp
 * Generate and send OTP for password reset
 */
router.post('/send-password-reset-otp', async (req: Request, res: Response) => {
  try {
    const { email } = req.body;

    if (!email || typeof email !== 'string') {
      return res.status(400).json({ error: 'Email is required' });
    }

    const normalizedEmail = email.trim().toLowerCase();

    // Check if user exists
    const { data: userData, error: userError } = await supabaseAdmin
      .from('users')
      .select('id, email')
      .eq('email', normalizedEmail)
      .maybeSingle();

    if (userError && userError.code !== 'PGRST116') {
      console.error('Error checking user:', userError);
      return res.status(500).json({ error: 'Failed to process request' });
    }

    if (!userData) {
      // Don't reveal if user exists or not (security)
      return res.status(200).json({ 
        message: 'If the email exists, an OTP has been sent.' 
      });
    }

    // Generate 6-digit OTP
    const otp = generateOTP();
    const expiresAt = Date.now() + (10 * 60 * 1000); // 10 minutes

    // Store OTP
    otpStore.set(normalizedEmail, { otp, expiresAt, email: normalizedEmail });

    // Send email using Supabase Admin (bypassing magic link)
    try {
      // Use a simple REST call to send email via your email service
      // For now, we'll use Supabase's email system with a custom approach
      
      // Generate a temporary password reset link that we'll ignore
      const { data: linkData, error: linkError } = await supabaseAdmin.auth.admin.generateLink({
        type: 'recovery',
        email: normalizedEmail,
      });

      if (linkError) {
        console.error('Error generating link:', linkError);
      }

      // TODO: Send actual OTP email using SendGrid/NodeMailer
      // For now, log it to console for testing
      console.log(`\n🔐 PASSWORD RESET OTP for ${normalizedEmail}: ${otp}`);
      console.log(`📧 Valid for 10 minutes\n`);

    } catch (error) {
      console.error('Error sending email:', error);
    }

    return res.status(200).json({ 
      message: 'OTP has been sent to your email',
      // Remove this in production!
      debug: process.env.NODE_ENV === 'development' ? { otp } : undefined,
    });

  } catch (error) {
    console.error('Unexpected error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * POST /auth/verify-otp-and-reset
 * Verify OTP and reset password
 */
router.post('/verify-otp-and-reset', async (req: Request, res: Response) => {
  try {
    const { email, otp, newPassword } = req.body;

    if (!email || !otp || !newPassword) {
      return res.status(400).json({ error: 'Email, OTP, and new password are required' });
    }

    const normalizedEmail = email.trim().toLowerCase();

    // Get stored OTP
    const stored = otpStore.get(normalizedEmail);

    if (!stored) {
      return res.status(400).json({ error: 'Invalid or expired OTP' });
    }

    // Check if expired
    if (stored.expiresAt < Date.now()) {
      otpStore.delete(normalizedEmail);
      return res.status(400).json({ error: 'OTP has expired' });
    }

    // Verify OTP
    if (stored.otp !== otp.trim()) {
      return res.status(400).json({ error: 'Invalid OTP' });
    }

    // Get user
    const { data: userData, error: userError } = await supabaseAdmin
      .from('users')
      .select('id')
      .eq('email', normalizedEmail)
      .single();

    if (userError || !userData) {
      otpStore.delete(normalizedEmail);
      return res.status(400).json({ error: 'User not found' });
    }

    // Update password using Admin API
    const { error: updateError } = await supabaseAdmin.auth.admin.updateUserById(
      userData.id,
      { password: newPassword }
    );

    if (updateError) {
      console.error('Error updating password:', updateError);
      return res.status(500).json({ error: 'Failed to update password' });
    }

    // Delete OTP after successful reset
    otpStore.delete(normalizedEmail);

    return res.status(200).json({ 
      message: 'Password reset successful',
    });

  } catch (error) {
    console.error('Unexpected error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * POST /auth/resend-otp
 * Resend OTP for password reset
 */
router.post('/resend-otp', async (req: Request, res: Response) => {
  // Reuse the send-password-reset-otp logic
  try {
    const { email } = req.body;

    if (!email || typeof email !== 'string') {
      return res.status(400).json({ error: 'Email is required' });
    }

    const normalizedEmail = email.trim().toLowerCase();

    // Check if user exists
    const { data: userData, error: userError } = await supabaseAdmin
      .from('users')
      .select('id, email')
      .eq('email', normalizedEmail)
      .maybeSingle();

    if (userError && userError.code !== 'PGRST116') {
      console.error('Error checking user:', userError);
      return res.status(500).json({ error: 'Failed to process request' });
    }

    if (!userData) {
      return res.status(200).json({ 
        message: 'If the email exists, an OTP has been sent.' 
      });
    }

    // Generate 6-digit OTP
    const otp = generateOTP();
    const expiresAt = Date.now() + (10 * 60 * 1000); // 10 minutes

    // Store OTP
    otpStore.set(normalizedEmail, { otp, expiresAt, email: normalizedEmail });

    console.log(`\n🔐 PASSWORD RESET OTP for ${normalizedEmail}: ${otp}`);
    console.log(`📧 Valid for 10 minutes\n`);

    return res.status(200).json({ 
      message: 'OTP has been resent to your email',
      debug: process.env.NODE_ENV === 'development' ? { otp } : undefined,
    });

  } catch (error) {
    console.error('Unexpected error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
