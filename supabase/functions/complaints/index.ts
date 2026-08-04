// Edge Function: complaints
// หน้าที่: แจ้งปัญหา / ดูรายการเรื่องร้องเรียน
//
// ความปลอดภัย: ตรวจ LINE access token ก่อนทุกครั้ง
// - ประชาชน: แจ้งได้ + ดูได้เฉพาะเรื่องของตัวเอง
// - เจ้าหน้าที่/ผู้ใหญ่บ้าน/ปลัด: ดูได้ทุกเรื่อง

import { createClient } from 'jsr:@supabase/supabase-js@2';

const LINE_CHANNEL_ID = Deno.env.get('LINE_CHANNEL_ID')!;
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const PUSH_SECRET = Deno.env.get('PUSH_SECRET') ?? '';

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
    const { accessToken, action, complaint } = body;

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

    // ===== 2) หา LINE user id ตัวจริง =====
    const profileRes = await fetch('https://api.line.me/v2/profile', {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (!profileRes.ok) {
      return json({ error: 'ดึงข้อมูลผู้ใช้ไม่สำเร็จ' }, 400);
    }
    const lineProfile = await profileRes.json();
    const lineUserId: string = lineProfile.userId;

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    // ===== 3) หา profile =====
    const { data: profile } = await admin
      .from('profiles')
      .select(
        'id, line_user_id, title, first_name, last_name, house_no, village, avatar_url',
      )
      .eq('line_user_id', lineUserId)
      .maybeSingle();

    if (!profile) {
      return json({ error: 'ไม่พบข้อมูลสมาชิก' }, 403);
    }

    // ===== 4) ดู role =====
    const { data: roleRows } = await admin
      .from('user_roles')
      .select('role, village')
      .eq('profile_id', profile.id);

    const roles = (roleRows ?? []).map((r) => r.role);
    // คนที่ดูได้ทุกเรื่อง
    const canSeeAll =
      roles.includes('officer') ||
      roles.includes('village_head') ||
      roles.includes('palad');

    const isOfficer = roles.includes('officer');
    const isVillageHead = roles.includes('village_head');
    const isPalad = roles.includes('palad');
    // หมู่บ้านที่ผู้ใหญ่บ้านคนนี้ดูแล
    const headRow = (roleRows ?? []).find((r) => r.role === 'village_head');
    const headVillage = (headRow?.village as string | undefined) ?? null;
    // หมู่บ้านที่เจ้าหน้าที่คนนี้ดูแล
    const officerRow = (roleRows ?? []).find((r) => r.role === 'officer');
    const officerVillage = (officerRow?.village as string | undefined) ?? null;

    // ===== 5) ทำงานตามที่สั่ง =====
    switch (action) {
      // ขอตั๋วอัปโหลดรูป (ใช้ bucket เดียวกับแทงค์น้ำ)
      case 'upload-url': {
        const fileName = body.fileName as string | undefined;
        if (!fileName) return json({ error: 'ไม่ได้ระบุชื่อไฟล์' }, 400);

        const ext = fileName.split('.').pop() ?? 'jpg';
        const path = `complaints/${crypto.randomUUID()}.${ext}`;

        const { data, error } = await admin.storage
          .from('tank-images')
          .createSignedUploadUrl(path);

        if (error) {
          return json(
            { error: 'ขอตั๋วอัปโหลดไม่สำเร็จ', detail: error.message },
            500,
          );
        }

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

      // ===== แจ้งปัญหา =====
      case 'create': {
        if (!complaint?.problemType) {
          return json({ error: 'กรุณาเลือกประเภทปัญหา' }, 400);
        }

        // กันแจ้งซ้ำ: ถ้าแทงค์นี้มีเรื่องที่ยังไม่จบ (ไม่ใช่ done/rejected) แจ้งไม่ได้
        if (complaint.tankId) {
          const { data: active } = await admin
            .from('complaints')
            .select('id')
            .eq('tank_id', complaint.tankId)
            .not('status', 'in', '(done,rejected)')
            .limit(1);

          if (active && active.length > 0) {
            return json({
              error: 'แทงค์นี้มีเรื่องที่กำลังดำเนินการอยู่ ไม่สามารถแจ้งซ้ำได้จนกว่าจะแล้วเสร็จ',
            }, 400);
          }
        }

        const { data, error } = await admin
          .from('complaints')
          .insert({
            tank_id: complaint.tankId ?? null,
            reporter_id: profile.id,
            problem_type: complaint.problemType,
            detail: complaint.detail ?? null,
            image_urls: complaint.imageUrls ?? [],
            lat: complaint.lat ?? null,
            lng: complaint.lng ?? null,
            status: 'pending',
          })
          .select()
          .single();

        if (error) {
          return json({ error: 'ส่งเรื่องไม่สำเร็จ', detail: error.message }, 500);
        }
        await logStatus(admin, data.id, 'pending');

        // แจ้งเจ้าหน้าที่ว่ามีเรื่องใหม่
        const tankName = (data.tank_id as string | null)
          ? (await admin
              .from('water_tanks')
              .select('name, village, moo')
              .eq('id', data.tank_id)
              .maybeSingle()).data
          : null;

        sendPush({
          roles: ['officer'],
          village: tankName?.village, // เฉพาะเจ้าหน้าที่หมู่บ้านนั้น
          title: 'มีเรื่องแจ้งซ่อมใหม่',
          body: tankName
            ? `${complaint.problemType} — ${tankName.name} หมู่ ${tankName.moo} ${tankName.village}`
            : complaint.problemType,
        });

        return json({ success: true, complaint: data });
      }

      // ===== ดูรายการเรื่องร้องเรียน =====
      case 'list': {
        // ดึงชื่อแทงค์มาด้วย จะได้แสดงในรายการเลย
        let query = admin
          .from('complaints')
          .select(
            '*, water_tanks(name, type, village, moo), ' +
            'profiles!complaints_reporter_id_fkey(title, first_name, last_name, house_no, village)',
          )
          .order('created_at', { ascending: false });

        // ประชาชนธรรมดา -> เห็นเฉพาะเรื่องของตัวเอง
        if (!canSeeAll) {
          query = query.eq('reporter_id', profile.id);
        }

        const { data, error } = await query;

        if (error) {
          return json({ error: 'โหลดข้อมูลไม่สำเร็จ', detail: error.message }, 500);
        }

        let list = data ?? [];

        // action 'list' เป็นของเมนูเจ้าหน้าที่ (รับเรื่อง + อัปเดตสถานะ) เท่านั้น
        // จึงกรองตามหมู่บ้านของเจ้าหน้าที่เสมอ ไม่เกี่ยวกับ role อื่นที่มี
        // (ผู้ใหญ่บ้าน/เทศบาล ใช้ action แยก: village-head-list / palad-list)
        if (isOfficer && officerVillage) {
          list = list.filter((c) => {
            const tank = c.water_tanks as { village?: string } | null;
            return tank?.village === officerVillage;
          });
        }

        return json({ success: true, complaints: list });
      }

      // ดูสถานะประปา: แทงค์ในหมู่บ้าน + เรื่องร้องเรียนล่าสุดของแต่ละแทงค์
      // ทุกคนดูได้ (ไม่ต้องเป็นเจ้าหน้าที่)
      case 'tank-status': {
        const village = (body.village as string | undefined) ?? '';

        // ดึงแทงค์ตามหมู่บ้าน (ว่าง = ทุกหมู่บ้าน)
        let tankQuery = admin
          .from('water_tanks')
          .select('id, name, type, village, moo, lat, lng, image_urls')
          .order('created_at', { ascending: false });

        if (village.length > 0) {
          tankQuery = tankQuery.eq('village', village);
        }

        const { data: tanks, error: tankErr } = await tankQuery;
        if (tankErr) {
          return json({ error: 'โหลดข้อมูลไม่สำเร็จ', detail: tankErr.message }, 500);
        }

        // ดึงเรื่องร้องเรียนล่าสุดของแต่ละแทงค์ (เอาเรื่องที่ยังไม่จบ)
        const tankIds = (tanks ?? []).map((t) => t.id);
        let complaintsByTank: Record<string, unknown> = {};

        if (tankIds.length > 0) {
          const { data: cps } = await admin
            .from('complaints')
            .select('id, tank_id, status, problem_type, created_at, updated_at')
            .in('tank_id', tankIds)
            .order('created_at', { ascending: false });

          // เก็บเรื่องล่าสุดของแต่ละแทงค์ (ตัวแรกที่เจอ = ใหม่สุด)
          for (const cp of cps ?? []) {
            const tid = cp.tank_id as string;
            if (!complaintsByTank[tid]) {
              complaintsByTank[tid] = cp;
            }
          }
        }

        const result = (tanks ?? []).map((t) => ({
          ...t,
          latest_complaint: complaintsByTank[t.id] ?? null,
        }));

        return json({ success: true, tanks: result });
      }

      // เจ้าหน้าที่เดินสถานะไปทีละสเต็ป (ข้ามไม่ได้)
      case 'advance-status': {
        if (!canSeeAll) {
          return json({ error: 'เฉพาะเจ้าหน้าที่เท่านั้น' }, 403);
        }

        const complaintId = body.complaintId as string | undefined;
        if (!complaintId) return json({ error: 'ข้อมูลไม่ครบ' }, 400);

        // ดึงสถานะปัจจุบันก่อน
        const { data: current, error: fetchErr } = await admin
          .from('complaints')
          .select('status')
          .eq('id', complaintId)
          .single();

        if (fetchErr || !current) {
          return json({ error: 'ไม่พบเรื่องร้องเรียน' }, 404);
        }

        // สเต็ปถัดไปของแต่ละสถานะ (เจ้าหน้าที่เดินได้ถึงแค่ budget_wait)
        const nextOf: Record<string, string | null> = {
          pending: 'received',
          received: 'surveying',
          surveying: 'budget_wait',
          // budget_wait: ต้องรอผู้ใหญ่บ้าน เจ้าหน้าที่เดินต่อเองไม่ได้
          budget_wait: null,
          repairing: 'done',
          done: null,
          rejected: null,
        };

        const cur = current.status as string;
        const next = nextOf[cur];

        if (next === null || next === undefined) {
          return json(
            { error: 'สถานะนี้เดินต่อเองไม่ได้ (ต้องรอขั้นตอนอื่น)' },
            400,
          );
        }

        // ถ้าจะไป budget_wait ต้องกรอกวัสดุก่อน
        if (next === 'budget_wait') {
          const { count } = await admin
            .from('repair_items')
            .select('id', { count: 'exact', head: true })
            .eq('complaint_id', complaintId);

          if ((count ?? 0) === 0) {
            return json(
              { error: 'กรุณากรอกรายการวัสดุก่อนส่งอนุมัติงบ' },
              400,
            );
          }
        }

        const { data, error } = await admin
          .from('complaints')
          .update({ status: next, updated_at: new Date().toISOString() })
          .eq('id', complaintId)
          .select()
          .single();

        if (error) {
          return json({ error: 'อัปเดตไม่สำเร็จ', detail: error.message }, 500);
        }
        await logStatus(admin, complaintId, next);

        // ===== แจ้งเตือนตามสถานะใหม่ =====
        // ดึงข้อมูลเรื่อง + แทงค์ + ผู้แจ้ง ไว้ประกอบข้อความ
        const { data: info } = await admin
          .from('complaints')
          .select('reporter_id, water_tanks(name, village, moo)')
          .eq('id', complaintId)
          .maybeSingle();

        const tk = info?.water_tanks as
          { name: string; village: string; moo: number } | null;
        const tankLabel = tk ? `${tk.name} หมู่ ${tk.moo} ${tk.village}` : '';

        if (next === 'received') {
          // แจ้งประชาชนที่แจ้งเรื่อง
          if (info?.reporter_id) {
            sendPush({
              profileIds: [info.reporter_id as string],
              title: 'เจ้าหน้าที่รับเรื่องแล้ว',
              body: 'เจ้าหน้าที่รับเรื่องของคุณแล้ว กำลังดำเนินการ',
            });
          }
        } else if (next === 'budget_wait') {
          // แจ้งผู้ใหญ่บ้านของหมู่บ้านนั้น
          sendPush({
            roles: ['village_head'],
            village: tk?.village,
            title: 'มีเรื่องรออนุมัติงบ',
            body: tankLabel.length > 0
              ? `เจ้าหน้าที่ส่งขออนุมัติงบ — ${tankLabel}`
              : 'เจ้าหน้าที่ส่งขออนุมัติงบประมาณ',
          });
        } else if (next === 'done') {
          // แจ้งประชาชนว่าซ่อมเสร็จ
          if (info?.reporter_id) {
            sendPush({
              profileIds: [info.reporter_id as string],
              title: 'ซ่อมเสร็จเรียบร้อยแล้ว',
              body: tankLabel.length > 0
                ? `${tankLabel} ซ่อมเสร็จแล้ว`
                : 'เรื่องที่คุณแจ้งซ่อมเสร็จแล้ว',
            });
          }
        }

        return json({ success: true, complaint: data });
      }

      // บันทึกรายการวัสดุ (เจ้าหน้าที่ กรอกตอนลงพื้นที่ประเมิน)
      case 'save-items': {
        if (!canSeeAll) {
          return json({ error: 'เฉพาะเจ้าหน้าที่เท่านั้น' }, 403);
        }
        const complaintId = body.complaintId as string | undefined;
        const items = body.items as Array<{
          name: string;
          quantity: number;
          unitPrice: number;
        }> | undefined;
        const surveyNote = (body.surveyNote as string | undefined) ?? null;
        const problemType = (body.problemType as string | undefined) ?? null;
        const detail = (body.detail as string | undefined) ?? null;

        if (!complaintId || !items) return json({ error: 'ข้อมูลไม่ครบ' }, 400);

        // เก็บวัตถุประสงค์ + ประเภท/รายละเอียดที่เจ้าหน้าที่แก้ให้ตรงหน้างาน
        const updateData: Record<string, unknown> = { survey_note: surveyNote };
        if (problemType) updateData.problem_type = problemType;
        if (detail !== null) updateData.detail = detail;
        await admin
          .from('complaints')
          .update(updateData)
          .eq('id', complaintId);

        // ลบของเก่าก่อน (กรอกใหม่ทับ)
        await admin.from('repair_items').delete().eq('complaint_id', complaintId);

        if (items.length > 0) {
          const rows = items.map((it) => ({
            complaint_id: complaintId,
            name: it.name,
            quantity: it.quantity,
            unit_price: it.unitPrice,
          }));
          const { error } = await admin.from('repair_items').insert(rows);
          if (error) {
            return json({ error: 'บันทึกวัสดุไม่สำเร็จ', detail: error.message }, 500);
          }
        }
        return json({ success: true });
      }

      // ดึงรายการวัสดุของเรื่องนี้ + สาเหตุที่เจอ
      case 'get-items': {
        const complaintId = body.complaintId as string | undefined;
        if (!complaintId) return json({ error: 'ข้อมูลไม่ครบ' }, 400);

        const { data, error } = await admin
          .from('repair_items')
          .select('*')
          .eq('complaint_id', complaintId)
          .order('created_at', { ascending: true });

        if (error) {
          return json({ error: 'โหลดข้อมูลไม่สำเร็จ', detail: error.message }, 500);
        }

        // ดึงสาเหตุที่เจอหน้างานมาด้วย
        const { data: cp } = await admin
          .from('complaints')
          .select('survey_note')
          .eq('id', complaintId)
          .single();

        return json({
          success: true,
          items: data ?? [],
          surveyNote: cp?.survey_note ?? null,
        });
      }

      // บันทึกความคืบหน้าการซ่อม (ตอนซ่อมไม่เสร็จในวันเดียว)
      case 'add-log': {
        if (!canSeeAll) {
          return json({ error: 'เฉพาะเจ้าหน้าที่เท่านั้น' }, 403);
        }
        const complaintId = body.complaintId as string | undefined;
        const note = ((body.note as string | undefined) ?? '').trim();

        if (!complaintId || note.length === 0) {
          return json({ error: 'กรุณากรอกรายละเอียด' }, 400);
        }

        const { error } = await admin.from('repair_logs').insert({
          complaint_id: complaintId,
          note,
          created_by: profile.id,
        });
        if (error) {
          return json({ error: 'บันทึกไม่สำเร็จ', detail: error.message }, 500);
        }
        return json({ success: true });
      }

      // ดึงประวัติความคืบหน้า
      case 'get-logs': {
        const complaintId = body.complaintId as string | undefined;
        if (!complaintId) return json({ error: 'ข้อมูลไม่ครบ' }, 400);

        const { data, error } = await admin
          .from('repair_logs')
          .select('*')
          .eq('complaint_id', complaintId)
          .order('created_at', { ascending: false });

        if (error) {
          return json({ error: 'โหลดข้อมูลไม่สำเร็จ', detail: error.message }, 500);
        }
        return json({ success: true, logs: data ?? [] });
      }

      // ===== ผู้ใหญ่บ้าน: ดูเรื่องรออนุมัติงบ (เฉพาะหมู่บ้านตัวเอง) =====
      case 'village-head-list': {
        if (!isVillageHead) {
          return json({ error: 'เฉพาะผู้ใหญ่บ้านเท่านั้น' }, 403);
        }
        if (!headVillage) {
          return json({ error: 'ยังไม่ได้กำหนดหมู่บ้านที่ดูแล' }, 400);
        }

        // กรองสถานะที่ต้องการ (budget_wait หรือ budget_review)
        const wantStatus = body.status as string | undefined;

        // ดึงเรื่อง join แทงค์ + ผู้แจ้ง แล้วค่อยกรองหมู่บ้านจากแทงค์
        let q = admin
          .from('complaints')
          .select(
            '*, water_tanks(name, type, village, moo), ' +
            'profiles!complaints_reporter_id_fkey(title, first_name, last_name, house_no, village)',
          )
          .order('created_at', { ascending: false });

        if (wantStatus) q = q.eq('status', wantStatus);

        const { data, error } = await q;
        if (error) {
          return json({ error: 'โหลดข้อมูลไม่สำเร็จ', detail: error.message }, 500);
        }

        // กรองเฉพาะเรื่องที่แทงค์อยู่ในหมู่บ้านที่ดูแล
        const filtered = (data ?? []).filter((c) => {
          const tank = c.water_tanks as { village?: string } | null;
          return tank?.village === headVillage;
        });

        return json({ success: true, complaints: filtered });
      }

      // ===== ผู้ใหญ่บ้าน: รับเรื่อง (budget_wait -> budget_review) =====
      case 'head-receive': {
        if (!isVillageHead) {
          return json({ error: 'เฉพาะผู้ใหญ่บ้านเท่านั้น' }, 403);
        }
        const complaintId = body.complaintId as string | undefined;
        if (!complaintId) return json({ error: 'ข้อมูลไม่ครบ' }, 400);

        const { error } = await admin
          .from('complaints')
          .update({ status: 'budget_review', updated_at: new Date().toISOString() })
          .eq('id', complaintId)
          .eq('status', 'budget_wait'); // กันกดซ้ำ

        if (error) {
          return json({ error: 'รับเรื่องไม่สำเร็จ', detail: error.message }, 500);
        }
        await logStatus(admin, complaintId, 'budget_review');
        return json({ success: true });
      }

      // ===== ผู้ใหญ่บ้าน: ตัดสินงบ =====
      // decision = 'approve' (งบพอ -> repairing) หรือ 'insufficient' (งบไม่พอ -> palad_review)
      case 'head-decide': {
        if (!isVillageHead) {
          return json({ error: 'เฉพาะผู้ใหญ่บ้านเท่านั้น' }, 403);
        }
        const complaintId = body.complaintId as string | undefined;
        const decision = body.decision as string | undefined;
        if (!complaintId || !decision) {
          return json({ error: 'ข้อมูลไม่ครบ' }, 400);
        }

        if (decision === 'approve') {
          // งบพอ -> กำลังซ่อม
          const { error } = await admin
            .from('complaints')
            .update({ status: 'repairing', updated_at: new Date().toISOString() })
            .eq('id', complaintId);
          if (error) {
            return json({ error: 'อนุมัติไม่สำเร็จ', detail: error.message }, 500);
          }
          await logStatus(admin, complaintId, 'repairing');

          sendPush({
            roles: ['officer'],
            title: 'งบอนุมัติแล้ว เริ่มซ่อมได้',
            body: 'ผู้ใหญ่บ้านอนุมัติงบประมาณแล้ว',
          });

          return json({ success: true });
        }

        if (decision === 'insufficient') {
          // งบไม่พอ -> ต้องกรอกจำนวนเงินที่ขาด -> ส่งปลัด "รับเรื่อง" ก่อน
          const shortfall = body.shortfall as number | undefined;
          if (shortfall == null || shortfall <= 0) {
            return json({ error: 'กรุณากรอกจำนวนเงินที่ขาด' }, 400);
          }
          const { error } = await admin
            .from('complaints')
            .update({
              status: 'palad_review',
              shortfall,
              updated_at: new Date().toISOString(),
            })
            .eq('id', complaintId);
          if (error) {
            return json({ error: 'ส่งต่อไม่สำเร็จ', detail: error.message }, 500);
          }
          await logStatus(admin, complaintId, 'palad_review');

          sendPush({
            roles: ['palad'],
            title: 'มีเรื่องรอสมทบงบ',
            body: `งบผู้ใหญ่บ้านไม่พอ ขาด ${shortfall.toLocaleString()} บาท`,
          });

          return json({ success: true });
        }

        return json({ error: 'คำสั่งไม่ถูกต้อง' }, 400);
      }

      // ===== ปลัด: ดูรายการ =====
      // status = 'palad_review' (รอรับ) หรือ 'palad_wait' (รับแล้ว รอสมทบ)
      case 'palad-list': {
        if (!isPalad) return json({ error: 'เฉพาะเจ้าหน้าที่เทศบาลเท่านั้น' }, 403);

        const wantStatus = (body.status as string | undefined) ?? 'palad_review';
        const { data, error } = await admin
          .from('complaints')
          .select(
            '*, water_tanks(name, type, village, moo), ' +
            'profiles!complaints_reporter_id_fkey(title, first_name, last_name, house_no, village)',
          )
          .eq('status', wantStatus)
          .order('created_at', { ascending: false });

        if (error) {
          return json({ error: 'โหลดข้อมูลไม่สำเร็จ', detail: error.message }, 500);
        }
        return json({ success: true, complaints: data ?? [] });
      }

      // ปลัดรับเรื่อง (palad_review -> palad_wait)
      case 'palad-receive': {
        if (!isPalad) return json({ error: 'เฉพาะเจ้าหน้าที่เทศบาลเท่านั้น' }, 403);
        const complaintId = body.complaintId as string | undefined;
        if (!complaintId) return json({ error: 'ข้อมูลไม่ครบ' }, 400);

        const { error } = await admin
          .from('complaints')
          .update({ status: 'palad_wait', updated_at: new Date().toISOString() })
          .eq('id', complaintId)
          .eq('status', 'palad_review');

        if (error) {
          return json({ error: 'อัปเดตไม่สำเร็จ', detail: error.message }, 500);
        }
        await logStatus(admin, complaintId, 'palad_wait');
        return json({ success: true });
      }

      // ปลัดสมทบงบเสร็จ (palad_wait -> repairing)
      case 'palad-approve': {
        if (!isPalad) return json({ error: 'เฉพาะเจ้าหน้าที่เทศบาลเท่านั้น' }, 403);
        const complaintId = body.complaintId as string | undefined;
        if (!complaintId) return json({ error: 'ข้อมูลไม่ครบ' }, 400);

        const { error } = await admin
          .from('complaints')
          .update({ status: 'repairing', updated_at: new Date().toISOString() })
          .eq('id', complaintId)
          .eq('status', 'palad_wait');

        if (error) {
          return json({ error: 'อัปเดตไม่สำเร็จ', detail: error.message }, 500);
        }
        await logStatus(admin, complaintId, 'repairing');

        sendPush({
          roles: ['officer'],
          title: 'เจ้าหน้าที่เทศบาลสมทบงบแล้ว เริ่มซ่อมได้',
          body: 'งบประมาณครบแล้ว สามารถเริ่มซ่อมได้',
        });

        return json({ success: true });
      }

      // ดึง timeline ประวัติสถานะของเรื่อง (ทุกคนดูได้)
      case 'get-timeline': {
        const complaintId = body.complaintId as string | undefined;
        if (!complaintId) return json({ error: 'ข้อมูลไม่ครบ' }, 400);

        // ข้อมูลเรื่อง + แทงค์ + สาเหตุที่เจอ
        const { data: cp, error: cpErr } = await admin
          .from('complaints')
          .select('*, water_tanks(name, type, village, moo)')
          .eq('id', complaintId)
          .single();

        if (cpErr || !cp) {
          return json({ error: 'ไม่พบเรื่องร้องเรียน' }, 404);
        }

        // ประวัติสถานะเรียงตามเวลา
        const { data: logs } = await admin
          .from('status_logs')
          .select('status, created_at')
          .eq('complaint_id', complaintId)
          .order('created_at', { ascending: true });

        // ความคืบหน้าการซ่อม (repair_logs) เรียงใหม่สุดก่อน
        const { data: repairLogs } = await admin
          .from('repair_logs')
          .select('note, created_at')
          .eq('complaint_id', complaintId)
          .order('created_at', { ascending: false });

        return json({
          success: true,
          complaint: cp,
          timeline: logs ?? [],
          repairLogs: repairLogs ?? [],
        });
      }

      // นับจำนวนงานค้างของแต่ละเมนู (สำหรับ badge)
      case 'menu-counts': {
        const counts: Record<string, number> = {};

        // เจ้าหน้าที่: เรื่องรอรับ (pending) + กำลังดำเนินการ
        // กรองตามหมู่บ้านของเจ้าหน้าที่เสมอ (badge ของเมนูเจ้าหน้าที่)
        if (isOfficer) {
          if (officerVillage) {
            const { data: pendRows } = await admin
              .from('complaints')
              .select('id, water_tanks!inner(village)')
              .eq('status', 'pending')
              .eq('water_tanks.village', officerVillage);
            counts['receiveComplaint'] = (pendRows ?? []).length;

            const { data: repRows } = await admin
              .from('complaints')
              .select('id, water_tanks!inner(village)')
              .in('status', ['received', 'surveying', 'repairing'])
              .eq('water_tanks.village', officerVillage);
            counts['repairStatus'] = (repRows ?? []).length;
          } else {
            // เจ้าหน้าที่ที่ยังไม่ผูกหมู่บ้าน -> นับทุกหมู่บ้าน
            const { count } = await admin
              .from('complaints')
              .select('id', { count: 'exact', head: true })
              .eq('status', 'pending');
            counts['receiveComplaint'] = count ?? 0;

            const { count: c2 } = await admin
              .from('complaints')
              .select('id', { count: 'exact', head: true })
              .in('status', ['received', 'surveying', 'repairing']);
            counts['repairStatus'] = c2 ?? 0;
          }
        }

        // ผู้ใหญ่บ้าน: รอรับเรื่อง (budget_wait) + รออนุมัติ (budget_review)
        // เฉพาะหมู่บ้านที่ดูแล
        if (isVillageHead && headVillage) {
          // ต้อง join แทงค์เพื่อกรองหมู่บ้าน -> ดึงมานับเอง
          const { data: waitRows } = await admin
            .from('complaints')
            .select('id, water_tanks!inner(village)')
            .eq('status', 'budget_wait')
            .eq('water_tanks.village', headVillage);
          counts['headReceive'] = (waitRows ?? []).length;

          const { data: reviewRows } = await admin
            .from('complaints')
            .select('id, water_tanks!inner(village)')
            .eq('status', 'budget_review')
            .eq('water_tanks.village', headVillage);
          counts['budgetApprove'] = (reviewRows ?? []).length;
        }

        // ปลัด: รอรับเรื่อง (palad_review) + รอสมทบ (palad_wait)
        if (isPalad) {
          const { count: c1 } = await admin
            .from('complaints')
            .select('id', { count: 'exact', head: true })
            .eq('status', 'palad_review');
          counts['paladReceive'] = c1 ?? 0;

          const { count: c2 } = await admin
            .from('complaints')
            .select('id', { count: 'exact', head: true })
            .eq('status', 'palad_wait');
          counts['paladApprove'] = c2 ?? 0;
        }

        return json({ success: true, counts });
      }

      // เช็คว่า token ยังใช้ได้ไหม + คืนข้อมูลล่าสุด
      // ใช้ตอนเปิดแอป (auto login) — ได้ role ล่าสุดด้วยถ้า admin เปลี่ยนให้
      case 'me': {
        return json({
          success: true,
          profile,
          roles,
        });
      }

      // ===== เก็บรหัสเครื่อง (FCM token) ผูกกับผู้ใช้ =====
      // เรียกตอนล็อกอินสำเร็จ เพื่อให้ส่งแจ้งเตือนหาคนนี้ได้
      case 'save-token': {
        const deviceToken = body.deviceToken as string | undefined;
        if (!deviceToken || deviceToken.length == 0) {
          return json({ error: 'ไม่มีรหัสเครื่อง' }, 400);
        }

        // upsert: ถ้ารหัสนี้เคยผูกกับคนอื่น (เครื่องเดียวกัน คนละบัญชี)
        // ให้ย้ายมาเป็นของคนที่ล็อกอินอยู่ตอนนี้
        const { error } = await admin.from('device_tokens').upsert(
          {
            profile_id: profile.id,
            token: deviceToken,
            updated_at: new Date().toISOString(),
          },
          { onConflict: 'token' },
        );

        if (error) {
          return json({ error: 'เก็บรหัสเครื่องไม่สำเร็จ', detail: error.message }, 500);
        }
        return json({ success: true });
      }

      // ===== ลบรหัสเครื่อง (ตอนออกจากระบบ) =====
      // กันไม่ให้แจ้งเตือนของคนเก่าเด้งใส่คนที่มาใช้เครื่องต่อ
      case 'delete-token': {
        const deviceToken = body.deviceToken as string | undefined;
        if (!deviceToken) return json({ success: true });

        await admin
          .from('device_tokens')
          .delete()
          .eq('token', deviceToken)
          .eq('profile_id', profile.id);

        return json({ success: true });
      }

      default:
        return json({ error: 'ไม่รู้จักคำสั่งนี้' }, 400);
    }
  } catch (err) {
    return json({ error: 'เกิดข้อผิดพลาด', detail: String(err) }, 500);
  }
});

// ===== ส่งแจ้งเตือน =====
// เรียก Edge Function push-send ให้ยิงแจ้งเตือน
// ส่งแบบ "ไม่รอผล" เพื่อไม่ให้ผู้ใช้ต้องรอ (ถ้าส่งไม่ได้ก็ไม่ควรทำให้งานหลักพัง)
function sendPush(payload: {
  profileIds?: string[];
  roles?: string[];
  village?: string;
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

// บันทึกประวัติการเปลี่ยนสถานะ (สำหรับ timeline)
async function logStatus(
  admin: ReturnType<typeof createClient>,
  complaintId: string,
  status: string,
) {
  await admin.from('status_logs').insert({
    complaint_id: complaintId,
    status,
  });
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}