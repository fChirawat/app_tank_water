// Edge Function: line-login
// หน้าที่: รับ code จากแอป -> เอา Channel Secret แลก token กับ LINE
//         -> ดึงข้อมูลผู้ใช้ -> เช็คใน PostgreSQL ว่าเคยสมัครไหม
//
// Channel Secret อยู่แค่ในนี้ ไม่เคยถูกส่งลงไปที่แอป

import { createClient } from 'jsr:@supabase/supabase-js@2';

const LINE_CHANNEL_ID = Deno.env.get('LINE_CHANNEL_ID')!;
const LINE_CHANNEL_SECRET = Deno.env.get('LINE_CHANNEL_SECRET')!;
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
    // ===== 1) รับข้อมูลจากแอป =====
    // รองรับ 2 แบบ:
    //   ก) SDK  -> ส่ง accessToken มาเลย (ไม่ต้องแลก)
    //   ข) Web  -> ส่ง code + redirectUri มาให้แลก token
    const body = await req.json();
    const code = body.code as string | undefined;
    const redirectUri = body.redirectUri as string | undefined;
    const sdkToken = body.accessToken as string | undefined;

    let accessToken: string;

    if (sdkToken) {
      // ===== แบบ ก) SDK: ตรวจว่า token นี้ของจริงและมาจาก Channel เรา =====
      const verifyRes = await fetch(
        `https://api.line.me/oauth2/v2.1/verify?access_token=${encodeURIComponent(sdkToken)}`,
      );
      if (!verifyRes.ok) {
        return json({ error: 'token ไม่ถูกต้องหรือหมดอายุ' }, 401);
      }
      const verifyData = await verifyRes.json();
      if (String(verifyData.client_id) !== String(LINE_CHANNEL_ID)) {
        return json({ error: 'token ไม่ได้มาจากแอปนี้' }, 401);
      }
      accessToken = sdkToken;
    } else {
      // ===== แบบ ข) Web: เอา code ไปแลก token (ใช้ Channel Secret) =====
      if (!code || !redirectUri) {
        return json({ error: 'ต้องส่ง accessToken หรือ code+redirectUri' }, 400);
      }

      const tokenRes = await fetch('https://api.line.me/oauth2/v2.1/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          grant_type: 'authorization_code',
          code,
          redirect_uri: redirectUri,
          client_id: LINE_CHANNEL_ID,
          client_secret: LINE_CHANNEL_SECRET,
        }),
      });

      if (!tokenRes.ok) {
        const detail = await tokenRes.text();
        return json({ error: 'แลก token กับ LINE ไม่สำเร็จ', detail }, 400);
      }

      const tokenData = await tokenRes.json();
      accessToken = tokenData.access_token;
    }

    // ===== 3) ดึงข้อมูลผู้ใช้จาก LINE =====
    const profileRes = await fetch('https://api.line.me/v2/profile', {
      headers: { Authorization: `Bearer ${accessToken}` },
    });

    if (!profileRes.ok) {
      return json({ error: 'ดึงโปรไฟล์จาก LINE ไม่สำเร็จ' }, 400);
    }

    const lineProfile = await profileRes.json();
    const lineUserId: string = lineProfile.userId;

    // ===== 4) เช็คใน PostgreSQL =====
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    const { data: existing, error: findErr } = await admin
      .from('profiles')
      .select('id, title, first_name, last_name, house_no, village, avatar_url')
      .eq('line_user_id', lineUserId)
      .maybeSingle();

    if (findErr) {
      return json({ error: 'อ่านข้อมูลผู้ใช้ไม่สำเร็จ', detail: findErr.message }, 500);
    }

    // ผู้ใช้เก่า -> ส่ง profile + roles กลับ
    if (existing) {
      const { data: roles } = await admin
        .from('user_roles')
        .select('role')
        .eq('profile_id', existing.id);

      return json({
        isNewUser: false,
        accessToken,
        profile: existing,
        roles: (roles ?? []).map((r) => r.role),
      });
    }

    // ผู้ใช้ใหม่ -> ให้ไปกรอกข้อมูลก่อน
    return json({
      isNewUser: true,
      accessToken,
      lineUserId,
      displayName: lineProfile.displayName ?? '',
      pictureUrl: lineProfile.pictureUrl ?? null,
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