// Edge Function: admin-users
// หน้าที่: admin ดูรายชื่อผู้ใช้ + เพิ่ม/ลบ role ให้คนอื่น
//
// ความปลอดภัย:
// - ต้องเป็น admin เท่านั้น (เช็คจากฐานข้อมูล)
// - จัดการได้แค่ officer / village_head / palad
// - ห้ามยุ่งกับ role admin และ citizen (กันคนยึดระบบ / กันลบสิทธิ์พื้นฐาน)

import { createClient } from 'jsr:@supabase/supabase-js@2';

const LINE_CHANNEL_ID = Deno.env.get('LINE_CHANNEL_ID')!;
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

// role ที่ admin แต่งตั้งให้คนอื่นได้ (ไม่รวม admin, citizen)
const ASSIGNABLE_ROLES = ['officer', 'village_head', 'palad'];

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
    const { accessToken, action } = body;

    if (!accessToken) return json({ error: 'ต้องเข้าสู่ระบบก่อน' }, 401);

    // ===== 1) ตรวจ token =====
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

    // ===== 2) หา profile ของคนสั่ง =====
    const profileRes = await fetch('https://api.line.me/v2/profile', {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (!profileRes.ok) return json({ error: 'ดึงข้อมูลผู้ใช้ไม่สำเร็จ' }, 400);

    const lineProfile = await profileRes.json();
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    const { data: me } = await admin
      .from('profiles')
      .select('id')
      .eq('line_user_id', lineProfile.userId)
      .maybeSingle();

    if (!me) return json({ error: 'ไม่พบข้อมูลสมาชิก' }, 403);

    // ===== 3) เช็คว่าเป็น admin จริงไหม =====
    const { data: myRoles } = await admin
      .from('user_roles')
      .select('role')
      .eq('profile_id', me.id);

    const isAdmin = (myRoles ?? []).some((r) => r.role === 'admin');
    if (!isAdmin) {
      return json({ error: 'เฉพาะผู้ดูแลระบบเท่านั้น' }, 403);
    }

    // ===== 4) ทำงานตามคำสั่ง =====
    switch (action) {
      // ดูรายชื่อผู้ใช้ แบบแบ่งหน้า (ทีละ 10 คน) + กรองตามช่องค้นหา
      // รับ: title, firstName, lastName (ช่องไหนว่างก็ไม่กรองช่องนั้น)
      //     page = หน้าที่เท่าไหร่ (เริ่มที่ 0)
      case 'list-users': {
        const pageSize = 10;
        const page = (body.page as number | undefined) ?? 0;

        const title = ((body.title as string | undefined) ?? '').trim();
        const firstName = ((body.firstName as string | undefined) ?? '').trim();
        const lastName = ((body.lastName as string | undefined) ?? '').trim();

        // count: 'exact' -> ให้ฐานข้อมูลนับจำนวนทั้งหมดมาด้วย (ไว้คำนวณจำนวนหน้า)
        let q = admin
          .from('profiles')
          .select(
            'id, title, first_name, last_name, house_no, village, avatar_url',
            { count: 'exact' },
          )
          .order('created_at', { ascending: false });

        // กรองเฉพาะช่องที่กรอกมา
        if (title.length > 0) q = q.ilike('title', `%${title}%`);
        if (firstName.length > 0) q = q.ilike('first_name', `%${firstName}%`);
        if (lastName.length > 0) q = q.ilike('last_name', `%${lastName}%`);

        // เอาเฉพาะช่วงของหน้านี้ (เช่น หน้า 0 = แถว 0-9, หน้า 1 = แถว 10-19)
        const from = page * pageSize;
        const to = from + pageSize - 1;
        q = q.range(from, to);

        const { data: profiles, error, count } = await q;

        if (error) {
          return json({ error: 'โหลดข้อมูลไม่สำเร็จ', detail: error.message }, 500);
        }

        // ดึง role ทั้งหมดมาแยกใส่แต่ละคน (พร้อมหมู่บ้านที่ดูแล)
        const { data: allRoles } = await admin
          .from('user_roles')
          .select('profile_id, role, village');

        const rolesByProfile: Record<string, string[]> = {};
        const headVillageBy: Record<string, string> = {};
        const officerVillageBy: Record<string, string> = {};
        for (const r of allRoles ?? []) {
          (rolesByProfile[r.profile_id] ??= []).push(r.role);
          if (r.role === 'village_head' && r.village) {
            headVillageBy[r.profile_id] = r.village;
          }
          if (r.role === 'officer' && r.village) {
            officerVillageBy[r.profile_id] = r.village;
          }
        }

        const users = (profiles ?? []).map((p) => ({
          ...p,
          roles: rolesByProfile[p.id] ?? [],
          headVillage: headVillageBy[p.id] ?? null,
          officerVillage: officerVillageBy[p.id] ?? null,
        }));

        return json({
          success: true,
          users,
          total: count ?? 0, // จำนวนทั้งหมด (ทุกหน้ารวมกัน)
          page,
          pageSize,
        });
      }

      // เพิ่ม role ให้ผู้ใช้
      case 'add-role': {
        const targetId = body.profileId as string | undefined;
        const role = body.role as string | undefined;
        const village = (body.village as string | undefined) ?? null;

        if (!targetId || !role) return json({ error: 'ข้อมูลไม่ครบ' }, 400);
        if (!ASSIGNABLE_ROLES.includes(role)) {
          return json({ error: 'ไม่สามารถแต่งตั้ง role นี้ได้' }, 403);
        }
        // ผู้ใหญ่บ้าน/เจ้าหน้าที่ ต้องระบุหมู่บ้านที่ดูแล
        if ((role === 'village_head' || role === 'officer') &&
            (!village || village.length === 0)) {
          return json({ error: 'กรุณาเลือกหมู่บ้านที่ดูแล' }, 400);
        }

        // ลบ role เดิมก่อน (เผื่อเปลี่ยนหมู่บ้าน) แล้วใส่ใหม่
        await admin
          .from('user_roles')
          .delete()
          .eq('profile_id', targetId)
          .eq('role', role);

        const { error } = await admin.from('user_roles').insert({
          profile_id: targetId,
          role,
          // ผู้ใหญ่บ้านและเจ้าหน้าที่เก็บหมู่บ้าน role อื่นเป็น null
          village: (role === 'village_head' || role === 'officer')
              ? village
              : null,
        });

        if (error) {
          return json({ error: 'เพิ่มสิทธิ์ไม่สำเร็จ', detail: error.message }, 500);
        }

        return json({ success: true });
      }

      // ลบ role ออกจากผู้ใช้
      case 'remove-role': {
        const targetId = body.profileId as string | undefined;
        const role = body.role as string | undefined;

        if (!targetId || !role) return json({ error: 'ข้อมูลไม่ครบ' }, 400);
        if (!ASSIGNABLE_ROLES.includes(role)) {
          return json({ error: 'ไม่สามารถลบ role นี้ได้' }, 403);
        }

        const { error } = await admin
          .from('user_roles')
          .delete()
          .eq('profile_id', targetId)
          .eq('role', role);

        if (error) {
          return json({ error: 'ลบสิทธิ์ไม่สำเร็จ', detail: error.message }, 500);
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