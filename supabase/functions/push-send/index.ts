// Edge Function: push-send
// หน้าที่: ส่งแจ้งเตือน (Push Notification) ไปยังเครื่องของผู้ใช้
//
// วิธีทำงาน:
//   1) หาว่าจะส่งหาใคร -> ดึงรหัสเครื่อง (token) จากตาราง device_tokens
//   2) ขอ access token จาก Google ด้วย Service Account
//   3) ยิงแจ้งเตือนผ่าน Firebase Cloud Messaging (FCM)
//
// หมายเหตุ: ฟังก์ชันนี้ให้ Edge Function ตัวอื่นเรียกใช้ (ไม่ใช่แอปเรียกตรง)

import { createClient } from 'jsr:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

// ข้อมูล Service Account จาก Firebase (ตั้งเป็น secret ไว้)
const FIREBASE_SERVICE_ACCOUNT = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')!;

// รหัสลับสำหรับให้ Edge Function ตัวอื่นเรียก (กันคนนอกยิงเล่น)
const PUSH_SECRET = Deno.env.get('PUSH_SECRET') ?? '';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

// ===== แปลง PEM (ข้อความ) เป็นรูปแบบที่ Web Crypto ใช้ได้ =====
function pemToBinary(pem: string): ArrayBuffer {
  const clean = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '');
  const raw = atob(clean);
  const buf = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) buf[i] = raw.charCodeAt(i);
  return buf.buffer;
}

// ===== เข้ารหัสแบบ base64url (มาตรฐานของ JWT) =====
function base64url(data: string | Uint8Array): string {
  let str: string;
  if (typeof data === 'string') {
    str = btoa(data);
  } else {
    let bin = '';
    for (const b of data) bin += String.fromCharCode(b);
    str = btoa(bin);
  }
  return str.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

// ===== ขอ access token จาก Google =====
// Google ไม่ให้ใช้ Service Account ตรงๆ ต้องเอาไปแลกเป็น access token ก่อน
let cachedToken: { value: string; expireAt: number } | null = null;

async function getGoogleAccessToken(sa: {
  client_email: string;
  private_key: string;
}): Promise<string> {
  // ถ้ายังไม่หมดอายุ ใช้ตัวเดิม (ลดการเรียก Google ซ้ำ)
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expireAt > now + 60) {
    return cachedToken.value;
  }

  const header = { alg: 'RS256', typ: 'JWT' };
  const claims = {
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600, // อายุ 1 ชั่วโมง
  };

  const unsigned =
    `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(claims))}`;

  // เซ็นด้วยกุญแจส่วนตัวของ Service Account
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToBinary(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );

  const jwt = `${unsigned}.${base64url(new Uint8Array(signature))}`;

  // เอา JWT ไปแลก access token
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  if (!res.ok) {
    throw new Error(`ขอ access token ไม่สำเร็จ: ${await res.text()}`);
  }

  const data = await res.json();
  cachedToken = {
    value: data.access_token,
    expireAt: now + (data.expires_in ?? 3600),
  };
  return cachedToken.value;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const body = await req.json();

    // กันคนนอกยิงเล่น
    if (PUSH_SECRET && body.secret !== PUSH_SECRET) {
      return json({ error: 'ไม่มีสิทธิ์เรียกใช้' }, 403);
    }

    const title = body.title as string | undefined;
    const message = body.body as string | undefined;
    if (!title || !message) {
      return json({ error: 'ต้องมี title และ body' }, 400);
    }

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    // ===== 1) หาว่าจะส่งหาใคร =====
    // ส่งได้ 2 แบบ: ระบุ profileIds ตรงๆ หรือระบุ role (+ หมู่บ้าน)
    let profileIds: string[] = (body.profileIds as string[] | undefined) ?? [];

    const roles = body.roles as string[] | undefined;
    const village = body.village as string | undefined;

    if (roles && roles.length > 0) {
      let q = admin.from('user_roles').select('profile_id, role, village');
      const { data: roleRows } = await q.in('role', roles);

      for (const r of roleRows ?? []) {
        // ผู้ใหญ่บ้าน/เจ้าหน้าที่: ส่งเฉพาะคนที่ดูแลหมู่บ้านนั้น
        if ((r.role === 'village_head' || r.role === 'officer') && village) {
          if (r.village !== village) continue;
        }
        profileIds.push(r.profile_id as string);
      }
    }

    // ตัดคนที่ซ้ำออก
    profileIds = [...new Set(profileIds)];

    if (profileIds.length === 0) {
      return json({ success: true, sent: 0, note: 'ไม่มีผู้รับ' });
    }

    // ===== 2) ดึงรหัสเครื่องของคนเหล่านั้น =====
    const { data: tokenRows } = await admin
      .from('device_tokens')
      .select('token')
      .in('profile_id', profileIds);

    const tokens = (tokenRows ?? []).map((t) => t.token as string);

    if (tokens.length === 0) {
      return json({ success: true, sent: 0, note: 'ผู้รับยังไม่ได้เปิดแอป' });
    }

    // ===== 3) ส่งแจ้งเตือน =====
    const sa = JSON.parse(FIREBASE_SERVICE_ACCOUNT);
    const accessToken = await getGoogleAccessToken(sa);
    const projectId = sa.project_id;

    let sent = 0;
    const deadTokens: string[] = [];



    const useWaterAlert = body.useWaterAlert === true;

    const channelId = useWaterAlert
      ? 'water_app_alert_channel'
      : 'water_app_default_channel';

    // FCM ส่งทีละเครื่อง
    for (const token of tokens) {
      const res = await fetch(
        `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            message: {
              token,
              // ใส่ notification เพื่อให้เด้งขึ้นมาแม้ปิดแอปอยู่
              notification: { title, body: message },
              android: {
                priority: 'HIGH',
                notification: {
                  channel_id: channelId,
                  ...(useWaterAlert
                    ? { sound: 'water_alert' }
                    : {}),
                },
              },

              data: {
                ...((body.data as Record<string, string> | undefined) ?? {}),
                useWaterAlert: String(useWaterAlert),
              },
            },
          }),
        },
      );

      if (res.ok) {
        sent++;
      } else {
        const errText = await res.text();
        // เครื่องที่ถอนแอปไปแล้ว -> เก็บไว้ลบทีหลัง
        if (errText.includes('UNREGISTERED') || errText.includes('INVALID_ARGUMENT')) {
          deadTokens.push(token);
        }
        console.error('ส่งไม่สำเร็จ:', errText);
      }
    }

    // ลบรหัสเครื่องที่ใช้ไม่ได้แล้วออก
    if (deadTokens.length > 0) {
      await admin.from('device_tokens').delete().in('token', deadTokens);
    }

    return json({ success: true, sent, total: tokens.length });
  } catch (err) {
    return json({ error: 'ส่งแจ้งเตือนไม่สำเร็จ', detail: String(err) }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}