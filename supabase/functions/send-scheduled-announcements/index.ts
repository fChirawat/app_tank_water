// Edge Function: send-scheduled-announcements
// หน้าที่: หาประกาศที่ "ตั้งเวลาส่งล่วงหน้า" ไว้และถึงเวลาส่งแล้ว -> ยิง push ให้
//
// เรียกโดย pg_cron (ทุก 5 นาที ผ่าน pg_net) ไม่ใช่ผู้ใช้เรียกตรงเอง
// จึงไม่มีการเช็ค LINE token — ป้องกันด้วย SCHEDULER_SECRET แทน (เหมือน
// push-send ที่ป้องกันด้วย PUSH_SECRET)

import { createClient } from 'jsr:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const PUSH_SECRET = Deno.env.get('PUSH_SECRET') ?? '';
const SCHEDULER_SECRET = Deno.env.get('SCHEDULER_SECRET') ?? '';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const body = await req.json().catch(() => ({}));

    // กันคนนอกยิงเล่น — ต้องตั้ง SCHEDULER_SECRET ไว้เสมอ (fail-closed)
    if (!SCHEDULER_SECRET || body.secret !== SCHEDULER_SECRET) {
      return json({ error: 'ไม่มีสิทธิ์เรียกใช้' }, 403);
    }

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    // หาประกาศที่ยังไม่ส่ง + ถึงเวลาส่งแล้ว
    const { data: due, error } = await admin
      .from('announcements')
      .select('id, title, event_date, start_time, end_time, villages')
      .eq('push_sent', false)
      .lte('push_scheduled_at', new Date().toISOString());

    if (error) {
      return json(
        { error: 'โหลดประกาศที่รอส่งไม่สำเร็จ', detail: error.message },
        500,
      );
    }

    let processed = 0;

    for (const ann of due ?? []) {
      const targetVillages = ann.villages as string[] | null;

      // หาคนที่ต้องแจ้ง (ดูจากหมู่บ้านในโปรไฟล์) — เหมือน action 'create'
      const { data: people } = await admin
        .from('profiles')
        .select('id, village');

      const targetIds = (people ?? [])
        .filter((pf) => {
          if (targetVillages === null) return true; // ทุกหมู่บ้าน
          const v = (pf.village as string | null) ?? '';
          return targetVillages.some((tv) => v.includes(tv));
        })
        .map((pf) => pf.id as string);

      if (targetIds.length > 0) {
        let when = (ann.event_date as string | null) ?? '';
        if (ann.start_time && ann.end_time) {
          when += ` ${ann.start_time}-${ann.end_time} น.`;
        } else if (ann.start_time) {
          when += ` ${ann.start_time} น.`;
        }

        try {
          await fetch(`${SUPABASE_URL}/functions/v1/push-send`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              secret: PUSH_SECRET,
              profileIds: targetIds,
              title: `ประกาศ: ${ann.title}`,
              body: when.trim(),
              useWaterAlert: true,
            }),
          });
        } catch (e) {
          console.error('ส่งแจ้งเตือนตามเวลาไม่สำเร็จ:', e);
        }
      }

      // มาร์คว่าส่งแล้ว ไม่ว่าจะมีคนรับหรือไม่ (กันส่งซ้ำรอบหน้า)
      await admin
        .from('announcements')
        .update({ push_sent: true })
        .eq('id', ann.id);

      processed++;
    }

    return json({ success: true, processed });
  } catch (err) {
    return json({ error: 'เกิดข้อผิดพลาด', detail: String(err) }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
