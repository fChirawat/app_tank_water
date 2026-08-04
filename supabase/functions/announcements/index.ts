// Edge Function: announcements
// หน้าที่: ระบบประกาศ (น้ำหยุดไหล ซ่อมท่อ ฯลฯ)
//
// ความปลอดภัย: ตรวจ LINE access token ก่อนทุกครั้ง
// - เจ้าหน้าที่: สร้าง/ลบประกาศได้
// - ทุกคน: ดูประกาศได้ (เฉพาะที่ยังไม่หมดวัน + หมู่บ้านตัวเอง/ทุกหมู่บ้าน)

import { createClient } from 'jsr:@supabase/supabase-js@2';

const LINE_CHANNEL_ID = Deno.env.get('LINE_CHANNEL_ID')!;
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const PUSH_SECRET = Deno.env.get('PUSH_SECRET') ?? '';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

// ส่งแจ้งเตือน (ไม่รอผล เพื่อไม่ให้ผู้ใช้ต้องรอ)
function sendPush(payload: {
  profileIds?: string[];
  title: string;
  body: string;
}) {
  try {
    fetch(`${SUPABASE_URL}/functions/v1/push-send`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ secret: PUSH_SECRET, ...payload }),
    }).catch((e) => console.error('ส่งแจ้งเตือนไม่สำเร็จ:', e));
  } catch (e) {
    console.error('ส่งแจ้งเตือนไม่สำเร็จ:', e);
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const { accessToken, action } = body;

    if (!accessToken) return json({ error: 'ต้องเข้าสู่ระบบก่อน' }, 401);

    // ===== ตรวจ token กับ LINE =====
    const verifyRes = await fetch(
      `https://api.line.me/oauth2/v2.1/verify?access_token=${encodeURIComponent(accessToken)}`,
    );
    if (!verifyRes.ok) {
      return json({ error: 'token หมดอายุ กรุณาเข้าสู่ระบบใหม่' }, 401);
    }
    const verifyData = await verifyRes.json();
    if (String(verifyData.client_id) !== String(LINE_CHANNEL_ID)) {
      return json({ error: 'token ไม่ได้มาจากแอปนี้' }, 401);
    }

    // ===== หา LINE user id ตัวจริง =====
    const profileRes = await fetch('https://api.line.me/v2/profile', {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (!profileRes.ok) {
      return json({ error: 'ดึงข้อมูลผู้ใช้ไม่สำเร็จ' }, 400);
    }
    const lineProfile = await profileRes.json();
    const lineUserId: string = lineProfile.userId;

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    // ===== หา profile =====
    const { data: profile } = await admin
      .from('profiles')
      .select('id, village')
      .eq('line_user_id', lineUserId)
      .maybeSingle();

    if (!profile) return json({ error: 'ไม่พบข้อมูลสมาชิก' }, 403);

    // ===== ดู role + หมู่บ้านที่ดูแล =====
    const { data: roleRows } = await admin
      .from('user_roles')
      .select('role, village')
      .eq('profile_id', profile.id);

    const roles = (roleRows ?? []).map((r) => r.role);
    const isOfficer = roles.includes('officer');
    const isPalad = roles.includes('palad'); // เจ้าหน้าที่เทศบาล
    const isAdmin = roles.includes('admin');
    // หมู่บ้านที่เจ้าหน้าที่ดูแล
    const officerRow = (roleRows ?? []).find((r) => r.role === 'officer');
    const officerVillage = (officerRow?.village as string | undefined) ?? null;
    // ประกาศทั้งจังหวัด/ทุกหมู่บ้านได้ = เทศบาล หรือ แอดมิน
    const canAnnounceAll = isPalad || isAdmin;

    switch (action) {
      // เจ้าหน้าที่สร้างประกาศ
      case 'create': {
        // ต้องเป็นเจ้าหน้าที่ หรือ เทศบาล หรือ แอดมิน
        if (!isOfficer && !canAnnounceAll) {
          return json({ error: 'เฉพาะเจ้าหน้าที่เท่านั้น' }, 403);
        }

        const a = body.announcement as {
          title?: string;
          detail?: string;
          eventDate?: string; // YYYY-MM-DD
          startTime?: string; // HH:mm
          endTime?: string;
          villages?: string[] | null; // ว่าง/null = ทุกหมู่บ้าน
        } | undefined;

        if (!a?.title || !a.eventDate) {
          return json({ error: 'กรุณากรอกเรื่องและวันที่' }, 400);
        }

        // ===== กำหนดหมู่บ้านที่ประกาศได้ ตามสิทธิ์ =====
        let finalVillages: string[] | null;
        if (canAnnounceAll) {
          // เทศบาล/แอดมิน: ประกาศได้ตามที่เลือก (ว่าง = ทุกหมู่บ้าน)
          finalVillages = (a.villages && a.villages.length > 0)
            ? a.villages
            : null;
        } else {
          // เจ้าหน้าที่หมู่บ้าน: บังคับเฉพาะหมู่บ้านตัวเองเท่านั้น
          if (!officerVillage) {
            return json({ error: 'เจ้าหน้าที่ยังไม่ได้ผูกหมู่บ้าน' }, 400);
          }
          finalVillages = [officerVillage];
        }

        const { data, error } = await admin
          .from('announcements')
          .insert({
            title: a.title,
            detail: a.detail ?? null,
            event_date: a.eventDate,
            start_time: a.startTime ?? null,
            end_time: a.endTime ?? null,
            villages: finalVillages,
            created_by: profile.id,
          })
          .select()
          .single();

        if (error) {
          return json({ error: 'สร้างประกาศไม่สำเร็จ', detail: error.message }, 500);
        }
        // ===== แจ้งเตือนชาวบ้านที่เกี่ยวข้อง =====
        const targetVillages = finalVillages; // null = ทุกหมู่บ้าน

        // หาคนที่ต้องแจ้ง (ดูจากหมู่บ้านในโปรไฟล์)
        let peopleQuery = admin.from('profiles').select('id, village');
        const { data: people } = await peopleQuery;

        const targetIds = (people ?? [])
          .filter((pf) => {
            if (targetVillages === null) return true; // ทุกหมู่บ้าน
            const v = (pf.village as string | null) ?? '';
            return targetVillages.some((tv) => v.includes(tv));
          })
          .map((pf) => pf.id as string);

        if (targetIds.length > 0) {
          // ประกอบข้อความ เช่น "26 ก.ค. 13:00-15:00"
          let when = a.eventDate ?? '';
          if (a.startTime && a.endTime) {
            when += ` ${a.startTime}-${a.endTime} น.`;
          } else if (a.startTime) {
            when += ` ${a.startTime} น.`;
          }

          sendPush({
            profileIds: targetIds,
            title: `ประกาศ: ${a.title}`,
            body: when.trim(),
          });
        }

        return json({ success: true, announcement: data });
      }

      // ดูประกาศ (ทุกคน)
      // แสดงเฉพาะประกาศที่ event_date >= วันนี้ (ยังไม่ข้ามวัน)
      // และหมู่บ้านตรงกับผู้ใช้ หรือ village = null (ทุกหมู่บ้าน)
      case 'list': {
        // วันนี้ (เขตเวลาไทย) แบบ YYYY-MM-DD
        const today = new Date();
        const bangkok = new Date(today.getTime() + 7 * 60 * 60 * 1000);
        const todayStr = bangkok.toISOString().slice(0, 10);

        // หาชื่อหมู่บ้านของผู้ใช้ (เทียบแบบ contains)
        const myVillage = (profile.village as string | null) ?? '';

        let query = admin
          .from('announcements')
          .select(
            '*, profiles!announcements_created_by_fkey(title, first_name, last_name)',
          )
          .gte('event_date', todayStr) // ยังไม่ข้ามวัน
          .order('event_date', { ascending: true })
          .order('start_time', { ascending: true });

        // เจ้าหน้าที่เห็นทุกประกาศ, ประชาชนเห็นเฉพาะหมู่บ้านตัวเอง + ทุกหมู่บ้าน
        const { data, error } = await query;
        if (error) {
          return json({ error: 'โหลดข้อมูลไม่สำเร็จ', detail: error.message }, 500);
        }

        // กรองหมู่บ้าน (ถ้าไม่ใช่เจ้าหน้าที่)
        let result = data ?? [];
        if (!isOfficer) {
          result = result.filter((row) => {
            const list = row.villages as string[] | null;
            // ไม่ระบุหมู่บ้าน = ประกาศถึงทุกหมู่บ้าน
            if (!list || list.length === 0) return true;
            // ตรงกับหมู่บ้านของผู้ใช้ไหม (โปรไฟล์เก็บเป็น "หมู่ 1 บุญเรืองเหนือ")
            return list.some((v) => myVillage.includes(v) || v === myVillage);
          });
        }

        return json({ success: true, announcements: result });
      }

      // เจ้าหน้าที่ลบประกาศ
      case 'delete': {
        if (!isOfficer) {
          return json({ error: 'เฉพาะเจ้าหน้าที่เท่านั้น' }, 403);
        }
        const id = body.id as string | undefined;
        if (!id) return json({ error: 'ข้อมูลไม่ครบ' }, 400);

        const { error } = await admin
          .from('announcements')
          .delete()
          .eq('id', id);

        if (error) {
          return json({ error: 'ลบไม่สำเร็จ', detail: error.message }, 500);
        }
        return json({ success: true });
      }

      default:
        return json({ error: 'ไม่รู้จักคำสั่งนี้' }, 400);
    }
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