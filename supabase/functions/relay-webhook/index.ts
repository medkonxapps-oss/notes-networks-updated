import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';

serve(async (req: Request) => {
  try {
    const payload = await req.json();

    // Process new notes with status: processing or active (for thumbnail generation)
    if (payload.type === 'INSERT' && 
        ['processing', 'active'].includes(payload.record?.status)) {
      
      const vpsUrl = Deno.env.get('VPS_URL');
      const webhookSecret = Deno.env.get('WEBHOOK_SECRET');

      if (!vpsUrl || !webhookSecret) {
        return new Response(JSON.stringify({ error: 'Missing env vars' }), { status: 500 });
      }

      // Relay to VPS worker
      const response = await fetch(`${vpsUrl}/webhook/note-published`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-webhook-secret': webhookSecret,
        },
        body: JSON.stringify(payload.record),
      });
      return new Response(JSON.stringify({ forwarded: response.ok }), { status: 200 });
    }

    // Process user updates (specifically teacher_status)
    if (payload.type === 'UPDATE' && 
        payload.table === 'users' && 
        payload.record?.teacher_status !== payload.old_record?.teacher_status) {
      
      const vpsUrl = Deno.env.get('VPS_URL');
      const webhookSecret = Deno.env.get('WEBHOOK_SECRET');

      if (!vpsUrl || !webhookSecret) {
        return new Response(JSON.stringify({ error: 'Missing env vars' }), { status: 500 });
      }

      // Relay to VPS for email notification
      const response = await fetch(`${vpsUrl}/webhook/teacher-status-updated`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-webhook-secret': webhookSecret,
        },
        body: JSON.stringify({
          user: payload.record,
          old_status: payload.old_record?.teacher_status,
          new_status: payload.record?.teacher_status,
        }),
      });
      return new Response(JSON.stringify({ forwarded: response.ok }), { status: 200 });
    }

    // Process new chat messages for push notifications
    if (payload.type === 'INSERT' && payload.table === 'messages') {
      const vpsUrl = Deno.env.get('VPS_URL');
      const webhookSecret = Deno.env.get('WEBHOOK_SECRET');

      if (vpsUrl && webhookSecret) {
        // We need to fetch sender and receiver info for the notification
        // Note: Edge functions have access to the DB via service role
        // For simplicity, we just relay the message record and let the VPS handle details or use a simple fetch
        const response = await fetch(`${vpsUrl}/webhook/chat-message`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'x-webhook-secret': webhookSecret,
          },
          body: JSON.stringify({
            message: payload.record,
            // These would ideally be fetched here or in VPS
            // To save time, we'll let VPS fetch them or use joins in payload if possible
            sender_id: payload.record.sender_id,
            receiver_id: payload.record.receiver_id
          }),
        });
        return new Response(JSON.stringify({ forwarded: response.ok }), { status: 200 });
      }
    }

    // Process new notification rows for push delivery
    if (payload.type === 'INSERT' && payload.table === 'notifications') {
      const vpsUrl = Deno.env.get('VPS_URL');
      const webhookSecret = Deno.env.get('WEBHOOK_SECRET');

      if (vpsUrl && webhookSecret) {
        const response = await fetch(`${vpsUrl}/webhook/system-notification`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'x-webhook-secret': webhookSecret,
          },
          body: JSON.stringify(payload.record),
        });
        return new Response(JSON.stringify({ forwarded: response.ok }), { status: 200 });
      }
    }

    return new Response(JSON.stringify({ message: 'ignored' }), { status: 200 });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }
});
