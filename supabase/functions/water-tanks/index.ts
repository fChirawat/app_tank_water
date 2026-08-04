// Edge Function: water-tanks
// หน้าที่: เพิ่ม/แก้/ลบ ข้อมูลแทงค์น้ำ
//
// ความปลอดภัย: ตรวจ LINE access token ก่อนทุกครั้ง แล้วเช็คว่าเป็น officer จริง
// (ห้ามเชื่อ role ที่แอปส่งมา เพราะปลอมได้)

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
    const body = await req.json();
    const { accessToken, action, tank, tankId } = body;

    if (!accessToken) {
      return json({ error: 'ต้องเข้าสู่ระบบก่อน' }, 401);
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

    // ===== 2) ดึง LINE user id ตัวจริง =====
    const profileRes = await fetch('https://api.line.me/v2/profile', {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (!profileRes.ok) {
      return json({ error: 'ดึงข้อมูลผู้ใช้ไม่สำเร็จ' }, 400);
    }
    const lineProfile = await profileRes.json();
    const lineUserId: string = lineProfile.userId;

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    // ===== 3) หา profile ของคนนี้ =====
    const { data: profile } = await admin
      .from('profiles')
      .select('id')
      .eq('line_user_id', lineUserId)
      .maybeSingle();

    if (!profile) {
      return json({ error: 'ไม่พบข้อมูลสมาชิก' }, 403);
    }

    // ===== 4) เช็คว่าเป็นเจ้าหน้าที่จริงไหม (จากฐานข้อมูล ไม่ใช่จากแอป) =====
    const { data: roles } = await admin
      .from('user_roles')
      .select('role')
      .eq('profile_id', profile.id);

    const isOfficer = (roles ?? []).some((r) => r.role === 'officer');
    if (!isOfficer) {
      return json({ error: 'เฉพาะเจ้าหน้าที่เท่านั้นที่จัดการข้อมูลแทงค์น้ำได้' }, 403);
    }

    // ===== 5) ทำงานตามที่สั่ง =====
    switch (action) {
      // ขอ "ตั๋วอัปโหลด" รูป — แอปเอาไปอัปรูปเข้า Storage โดยตรง
      case 'upload-url': {
        const fileName = body.fileName as string | undefined;
        if (!fileName) return json({ error: 'ไม่ได้ระบุชื่อไฟล์' }, 400);

        // ตั้งชื่อไฟล์ใหม่ไม่ให้ซ้ำกัน
        const ext = fileName.split('.').pop() ?? 'jpg';
        const path = `${crypto.randomUUID()}.${ext}`;

        const { data, error } = await admin.storage
          .from('tank-images')
          .createSignedUploadUrl(path);

        if (error) {
          return json(
            { error: 'ขอตั๋วอัปโหลดไม่สำเร็จ', detail: error.message },
            500,
          );
        }

        // publicUrl = ลิงก์ที่เอาไว้แสดงรูปทีหลัง
        const { data: pub } = admin.storage
          .from('tank-images')
          .getPublicUrl(path);

        return json({
          success: true,
          path,
          token: data.token,
          publicUrl: pub.publicUrl,
        });
      }

      case 'create': {
        if (!tank?.name || !tank?.type || !tank?.village || tank?.moo == null) {
          return json({ error: 'ข้อมูลไม่ครบ' }, 400);
        }

        const { data, error } = await admin
          .from('water_tanks')
          .insert({
            name: tank.name,
            type: tank.type,
            village: tank.village,
            moo: tank.moo,
            detail: tank.detail ?? null,
            capacity: tank.capacity ?? null,
            built_year: tank.builtYear ?? null,
            caretaker: tank.caretaker ?? null,
            caretaker_phone: tank.caretakerPhone ?? null,
            image_urls: tank.imageUrls ?? [],
            lat: tank.lat ?? null,
            lng: tank.lng ?? null,
            created_by: profile.id,
          })
          .select()
          .single();

        if (error) {
          return json({ error: 'บันทึกไม่สำเร็จ', detail: error.message }, 500);
        }
        return json({ success: true, tank: data });
      }

      case 'update': {
        if (!tankId) return json({ error: 'ไม่ได้ระบุแทงค์ที่จะแก้' }, 400);

        const { data, error } = await admin
          .from('water_tanks')
          .update({
            name: tank.name,
            type: tank.type,
            village: tank.village,
            moo: tank.moo,
            detail: tank.detail ?? null,
            capacity: tank.capacity ?? null,
            built_year: tank.builtYear ?? null,
            caretaker: tank.caretaker ?? null,
            caretaker_phone: tank.caretakerPhone ?? null,
            image_urls: tank.imageUrls ?? [],
            lat: tank.lat ?? null,
            lng: tank.lng ?? null,
            updated_at: new Date().toISOString(),
          })
          .eq('id', tankId)
          .select()
          .single();

        if (error) {
          return json({ error: 'แก้ไขไม่สำเร็จ', detail: error.message }, 500);
        }
        return json({ success: true, tank: data });
      }

      case 'delete': {
        if (!tankId) return json({ error: 'ไม่ได้ระบุแทงค์ที่จะลบ' }, 400);

        const { error } = await admin
          .from('water_tanks')
          .delete()
          .eq('id', tankId);

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