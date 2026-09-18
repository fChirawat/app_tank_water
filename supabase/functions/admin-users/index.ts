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
// รหัสปลดล็อกฟีเจอร์เสริมแต่ละตัว — เก็บเป็น secret ฝั่งเซิร์ฟเวอร์เท่านั้น
// ไม่เคยถูกส่งลงไปอยู่ในตัวแอป กันคนแกะแอปเจอรหัส
// เพิ่มฟีเจอร์ใหม่ -> เพิ่ม secret ใหม่ + เพิ่มบรรทัดในนี้ (id ต้องตรงกับ
// kAddonFeatures ฝั่งแอปที่ lib/data/addon_feature.dart)
const FEATURE_UNLOCK_CODES: Record<string, string> = {
  'pdf_signer': Deno.env.get('PDF_SIGNER_UNLOCK_CODE') ?? '',
  'dashboard_print': Deno.env.get('DASHBOARD_PRINT_UNLOCK_CODE') ?? '',
  'dashboard_compare': Deno.env.get('DASHBOARD_COMPARE_UNLOCK_CODE') ?? '',
  'scheduled_announcement':
    Deno.env.get('SCHEDULED_ANNOUNCEMENT_UNLOCK_CODE') ?? '',
};
// รหัสยืนยันก่อนลบบัญชีผู้ใช้ (กันกดลบพลาด) — เก็บเป็น secret ฝั่งเซิร์ฟเวอร์เท่านั้น
const ADMIN_DELETE_CONFIRM_CODE = Deno.env.get('ADMIN_DELETE_CONFIRM_CODE') ?? '';

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
        const roleFilter = ((body.role as string | undefined) ?? '').trim();

        // ถ้ากรองตามตำแหน่ง -> หา profile_id ที่มี role นั้นก่อน
        let filterIds: string[] | null = null;
        if (roleFilter.length > 0) {
          const { data: roleMatch } = await admin
            .from('user_roles')
            .select('profile_id')
            .eq('role', roleFilter);
          filterIds = (roleMatch ?? []).map((r) => r.profile_id as string);
          // ไม่มีใครถือ role นี้ -> คืนว่างเลย
          if (filterIds.length === 0) {
            return json({ success: true, users: [], total: 0, page });
          }
        }

        // count: 'exact' -> ให้ฐานข้อมูลนับจำนวนทั้งหมดมาด้วย (ไว้คำนวณจำนวนหน้า)
        let q = admin
          .from('profiles')
          .select(
            'id, title, first_name, last_name, house_no, village, avatar_url',
            { count: 'exact' },
          )
          // ซ่อนบัญชีที่ถูกลบไปแล้ว (ล้างข้อมูลส่วนตัวแต่เก็บแถวไว้เพราะมีเรื่อง
          // แจ้งซ่อมผูกอยู่ — ดู action 'delete-user') ออกจากรายการค้นหา
          .not('line_user_id', 'like', 'deleted:%')
          .order('created_at', { ascending: false });

        // กรองเฉพาะช่องที่กรอกมา
        if (title.length > 0) q = q.ilike('title', `%${title}%`);
        if (firstName.length > 0) q = q.ilike('first_name', `%${firstName}%`);
        if (lastName.length > 0) q = q.ilike('last_name', `%${lastName}%`);
        // กรองตามตำแหน่ง (เฉพาะ id ที่มี role นั้น)
        if (filterIds !== null) q = q.in('id', filterIds);

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

        // ===== เช็ค 1 ต่อ 1: หมู่บ้านนี้มีคนถือ role นี้อยู่แล้วไหม =====
        // (ยกเว้นตัวเอง กรณีแค่เปลี่ยนหมู่บ้าน)
        const force = body.force === true;
        if (role === 'village_head' || role === 'officer') {
          const { data: existingHolders } = await admin
            .from('user_roles')
            .select('profile_id')
            .eq('role', role)
            .eq('village', village)
            .neq('profile_id', targetId);

          if (existingHolders && existingHolders.length > 0) {
            // มีคนดูแลหมู่บ้านนี้อยู่แล้ว
            if (!force) {
              // ยังไม่ยืนยัน -> คืนชื่อคนเก่าให้แอปถาม
              const oldId = existingHolders[0].profile_id as string;
              const { data: oldProfile } = await admin
                .from('profiles')
                .select('title, first_name, last_name')
                .eq('id', oldId)
                .maybeSingle();
              const oldName = oldProfile
                ? [oldProfile.title, oldProfile.first_name, oldProfile.last_name]
                    .filter((s) => s && s.length > 0)
                    .join(' ')
                : 'ผู้ใช้เดิม';
              return json({
                needConfirm: true,
                currentHolder: oldName,
                village,
              });
            }
            // ยืนยันแล้ว -> ย้าย role คนเก่าออกจากหมู่บ้านนี้
            await admin
              .from('user_roles')
              .delete()
              .eq('role', role)
              .eq('village', village)
              .neq('profile_id', targetId);
          }
        }

        // ลบ role เดิมของคนนี้ก่อน (เผื่อเปลี่ยนหมู่บ้าน) แล้วใส่ใหม่
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

      // ===== ลบบัญชีผู้ใช้ (ต้องกรอกรหัสยืนยันก่อน) =====
      // ลบ role + รหัสเครื่อง(แจ้งเตือน) เสมอ
      // - ไม่มีเรื่องแจ้งซ่อมผูกอยู่ -> ลบโปรไฟล์ทิ้งทั้งแถว (เหมือนผู้ใช้ใหม่ถ้าล็อกอินซ้ำ)
      // - มีเรื่องแจ้งซ่อมผูกอยู่ (complaints.reporter_id) -> ลบทั้งแถวไม่ได้ (ชน foreign key)
      //   จึงล้างข้อมูลส่วนตัวออกแทน (anonymize) แต่ "เก็บแถวโปรไฟล์ไว้" เพื่อไม่ให้
      //   เรื่องแจ้งซ่อมที่ยังไม่จบพังไปด้วย — คนอื่น (เจ้าหน้าที่/ผู้ใหญ่บ้าน/ปลัด)
      //   ยังทำงานกับเรื่องนั้นได้ตามปกติ แค่ชื่อผู้แจ้งจะโชว์เป็น "ผู้ใช้ที่ถูกลบ"
      case 'delete-user': {
        const targetId = body.profileId as string | undefined;
        const code = (body.code as string | undefined) ?? '';

        if (!targetId) return json({ error: 'ข้อมูลไม่ครบ' }, 400);

        if (ADMIN_DELETE_CONFIRM_CODE.length === 0 ||
            code !== ADMIN_DELETE_CONFIRM_CODE) {
          return json({ error: 'รหัสยืนยันไม่ถูกต้อง' }, 403);
        }

        if (targetId === me.id) {
          return json({ error: 'ลบบัญชีของตัวเองไม่ได้' }, 400);
        }

        const { data: targetRoles } = await admin
          .from('user_roles')
          .select('role')
          .eq('profile_id', targetId);

        if ((targetRoles ?? []).some((r) => r.role === 'admin')) {
          return json({ error: 'ลบบัญชีผู้ดูแลระบบไม่ได้' }, 403);
        }

        // ลบรหัสเครื่อง(แจ้งเตือน) + role ก่อน กันเหลือข้อมูลค้าง
        await admin.from('device_tokens').delete().eq('profile_id', targetId);
        await admin.from('user_roles').delete().eq('profile_id', targetId);

        // เช็คก่อนว่ามีเรื่องแจ้งซ่อมผูกกับคนนี้อยู่ไหม (ทุกสถานะ ไม่ใช่แค่ที่ยังไม่จบ)
        const { count: complaintCount } = await admin
          .from('complaints')
          .select('id', { count: 'exact', head: true })
          .eq('reporter_id', targetId);

        if ((complaintCount ?? 0) > 0) {
          // มีเรื่องผูกอยู่ -> ลบทั้งแถวไม่ได้ ล้างข้อมูลส่วนตัวออกแทน
          // ใช้ค่าว่าง/placeholder แทน null ทุกช่อง กันชนกับ NOT NULL constraint
          // line_user_id ใส่ค่าปลอมที่ไม่ซ้ำใคร (กันชน unique) แทนการเว้นว่าง
          // เพื่อไม่ให้ LINE account เดิม login ซ้ำมาเจอโปรไฟล์นี้ได้อีก
          const { error: anonErr } = await admin
            .from('profiles')
            .update({
              title: '',
              first_name: 'ผู้ใช้ที่ถูกลบ',
              last_name: '',
              house_no: '',
              village: null,
              avatar_url: '',
              line_user_id: `deleted:${targetId}`,
            })
            .eq('id', targetId);

          if (anonErr) {
            return json(
              { error: `ลบไม่สำเร็จ: ${anonErr.message}` },
              500,
            );
          }

          return json({ success: true, anonymized: true });
        }

        // ไม่มีเรื่องผูกอยู่ -> ลบโปรไฟล์ทิ้งทั้งแถว
        const { error: delErr } = await admin
          .from('profiles')
          .delete()
          .eq('id', targetId);

        if (delErr) {
          return json({
            error: `ลบไม่สำเร็จ: ${delErr.message}`,
          }, 500);
        }

        return json({ success: true, anonymized: false });
      }

      // ===== เช็ครหัสปลดล็อกฟีเจอร์เสริม (ระบุ featureId ว่าจะปลดล็อกตัวไหน) =====
      // มาถึงตรงนี้ได้แปลว่าเป็น admin แล้ว (เช็คไว้ก่อนหน้าแล้ว)
      // รหัสจริงเก็บเป็น secret ฝั่งเซิร์ฟเวอร์เท่านั้น ไม่เคยส่งไปให้แอป
      case 'verify-feature-unlock': {
        const featureId = (body.featureId as string | undefined) ?? '';
        const code = (body.code as string | undefined) ?? '';
        const expected = FEATURE_UNLOCK_CODES[featureId] ?? '';
        const ok = expected.length > 0 && code === expected;
        if (!ok) {
          return json({ error: 'รหัสไม่ถูกต้อง' }, 403);
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