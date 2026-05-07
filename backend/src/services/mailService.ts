import sgMail from '@sendgrid/mail';
import dotenv from 'dotenv';

dotenv.config();

if (process.env.SENDGRID_API_KEY) {
  sgMail.setApiKey(process.env.SENDGRID_API_KEY);
}

export class MailService {
  private static systemEmail = process.env.SYSTEM_EMAIL || 'noreply@notesnet.app';

  static async sendTeacherApprovalEmail(email: string, fullName: string) {
    const msg = {
      to: email,
      from: this.systemEmail,
      subject: 'Account Approved! 🎉 - NotesNet',
      text: `Hello ${fullName}, your teacher account has been verified. You can now login and start uploading notes!`,
      html: `
        <div style=\"font-family: sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e2e8f0; border-radius: 8px;\">
          <h2 style=\"color: #4f46e5;\">Account Approved! 🎉</h2>
          <p>Hello <strong>${fullName}</strong>,</p>
          <p>Great news! Your teacher account on <strong>NotesNet</strong> has been verified by our team.</p>
          <p>You can now log in to the app and start sharing your knowledge by uploading notes.</p>
          <div style=\"margin-top: 30px; padding-top: 20px; border-top: 1px solid #e2e8f0; font-size: 12px; color: #64748b;\">
            <p>If you didn't request this, please ignore this email.</p>
            <p>&copy; ${new Date().getFullYear()} NotesNet</p>
          </div>
        </div>
      `,
    };

    try {
      if (!process.env.SENDGRID_API_KEY) {
        console.warn('⚠️ SENDGRID_API_KEY not set. Skipping email.');
        return;
      }
      await sgMail.send(msg);
      console.log(`📧 Approval email sent to ${email}`);
    } catch (error: any) {
      console.error('❌ Error sending approval email:', error);
      if (error.response) {
        console.error(error.response.body);
      }
    }
  }

  static async sendTeacherRejectionEmail(email: string, fullName: string) {
    const msg = {
      to: email,
      from: this.systemEmail,
      subject: 'Verification Update - NotesNet',
      text: `Hello ${fullName}, unfortunately, your teacher verification was not successful. Please ensure your ID card and LinkedIn profile are valid.`,
      html: `
        <div style=\"font-family: sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e2e8f0; border-radius: 8px;\">
          <h2 style=\"color: #ef4444;\">Verification Update</h2>
          <p>Hello <strong>${fullName}</strong>,</p>
          <p>Thank you for your interest in joining <strong>NotesNet</strong> as a teacher.</p>
          <p>Unfortunately, your teacher verification was not successful at this time. This could be due to invalid or unclear documents provided.</p>
          <p>Please ensure your ID card is clearly visible and your LinkedIn profile link is correct, then you can reach out to support if you believe this was an error.</p>
          <div style=\"margin-top: 30px; padding-top: 20px; border-top: 1px solid #e2e8f0; font-size: 12px; color: #64748b;\">
            <p>&copy; ${new Date().getFullYear()} NotesNet</p>
          </div>
        </div>
      `,
    };

    try {
      if (!process.env.SENDGRID_API_KEY) {
        console.warn('⚠️ SENDGRID_API_KEY not set. Skipping email.');
        return;
      }
      await sgMail.send(msg);
      console.log(`📧 Rejection email sent to ${email}`);
    } catch (error: any) {
      console.error('❌ Error sending rejection email:', error);
    }
  }
}
