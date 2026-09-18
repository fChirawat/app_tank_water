// Edge Function: line-register
// หน้าที่: รับข้อมูลที่ผู้ใช้กรอกในหน้า "กรอกข้อมูลสมาชิก"
//         -> สร้าง profile ใน PostgreSQL -> ให้ role citizen อัตโนมัติ
//
// เหตุผลที่แยกจาก line-login: ผู้ใช้ใหม่ต้องกรอกชื่อ/ที่อยู่ก่อน จึงสร้าง profile ได้
//
// ความปลอดภัย: ต้องตรวจ accessToken กับ LINE ก่อนเสมอ แล้วใช้ lineUserId
// ที่ได้จาก LINE เอง (ไม่ใช่ค่าที่ client ส่งมา) กันคนปลอม lineUserId
// สร้างโปรไฟล์ดักไว้ล่วงหน้าแทนคนอื่น

import { createClient } from 'jsr:@supabase/supabase-js@2';

const LINE_CHANNEL_ID = Deno.env.get('LINE_CHANNEL_ID')!;
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const {
      accessToken,
      title,
      firstName,
      lastName,
      houseNo,
      village,
      avatarUrl,
    } = await req.json();

    // เช็คข้อมูลที่จำเป็น
    if (!accessToken || !title || !firstName || !lastName || !houseNo || !village) {
      return json({ error: 'ข้อมูลไม่ครบ' }, 400);
    }

    // ===== 1) ตรวจ token กับ LINE =====
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

    // ===== 2) ดึง lineUserId ตัวจริงจาก LINE (ไม่เชื่อค่าที่ client ส่งมา) =====
    const profileRes = await fetch('https://api.line.me/v2/profile', {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (!profileRes.ok) {
      return json({ error: 'ดึงข้อมูลผู้ใช้ไม่สำเร็จ' }, 400);
    }
    const lineProfile = await profileRes.json();
    const lineUserId: string = lineProfile.userId;

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    // กันสมัครซ้ำ
    const { data: existing } = await admin
      .from('profiles')
      .select('id')
      .eq('line_user_id', lineUserId)
      .maybeSingle();

    if (existing) {
      return json({ error: 'บัญชี LINE นี้สมัครไว้แล้ว' }, 409);
    }

    // ===== สร้าง profile =====
    const { data: profile, error: insertErr } = await admin
      .from('profiles')
      .insert({
        line_user_id: lineUserId,
        title: title ?? null,
        first_name: firstName,
        last_name: lastName,
        house_no: houseNo ?? null,
        village: village ?? null,
        avatar_url: avatarUrl ?? null,
      })
      .select('id, title, first_name, last_name, house_no, village, avatar_url')
      .single();

    if (insertErr) {
      return json({ error: 'สร้างสมาชิกไม่สำเร็จ', detail: insertErr.message }, 500);
    }

    // ===== ให้ role citizen อัตโนมัติ (ทุกคนเริ่มจากประชาชน) =====
    const { error: roleErr } = await admin
      .from('user_roles')
      .insert({ profile_id: profile.id, role: 'citizen' });

    if (roleErr) {
      return json({ error: 'ให้สิทธิ์ไม่สำเร็จ', detail: roleErr.message }, 500);
    }

    return json({
      success: true,
      profile,
      roles: ['citizen'],
    });
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