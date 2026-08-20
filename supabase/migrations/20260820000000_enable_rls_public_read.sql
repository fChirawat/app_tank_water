-- ตรวจสอบ/ล็อก Row Level Security (RLS) ให้ตารางทั้งหมดในระบบ
--
-- บริบท: แอปเรียกข้อมูลเกือบทั้งหมดผ่าน Edge Function (ใช้ service_role key
-- ซึ่ง "bypass" RLS อยู่แล้วเสมอ ไม่ว่าจะตั้ง policy อะไรก็ตาม) มีเพียงตาราง
-- เดียวที่แอป Flutter อ่านตรงจากฐานข้อมูลด้วย anon key (public key ที่ฝังอยู่
-- ในตัวแอป) คือ water_tanks (ดู lib/services/tank_service.dart -> fetchTanks())
--
-- ดังนั้นเป้าหมายของไฟล์นี้คือ:
--   1) เปิด RLS ให้ครบทุกตาราง กันไว้ก่อนเผื่อมีตารางไหนลืมเปิด
--      (เปิดซ้ำได้ ไม่มีผลเสีย - Postgres รองรับ ENABLE ROW LEVEL SECURITY แบบ idempotent)
--   2) เพิ่ม policy อ่านสาธารณะ "เฉพาะ" ตาราง water_tanks เท่านั้น
--      (ตรงกับ intent เดิมในโค้ด: "ข้อมูลแทงค์ไม่ใช่ความลับ ชาวบ้านดูได้")
--   3) ตารางอื่น (profiles, user_roles, complaints, repair_items, repair_logs,
--      status_logs, announcements, device_tokens) ไม่เพิ่ม policy ใดๆ ให้ฝั่ง
--      client เลย เพราะเดิมทีก็ไม่ได้ถูกอ่าน/เขียนตรงจากแอปอยู่แล้ว (ไปผ่าน
--      Edge Function ทั้งหมด) การไม่มี policy + เปิด RLS = ปิดกั้น anon/
--      authenticated จากตารางเหล่านี้โดยสมบูรณ์ ในขณะที่ service_role
--      (Edge Function) ยังทำงานได้ตามปกติทุกอย่าง ไม่กระทบฟีเจอร์ใดๆ
--
-- คำเตือน: รันไฟล์นี้ผ่าน Supabase SQL Editor / `supabase db push` บน
-- โปรเจกต์จริงก่อน ควรอ่านทวนชื่อตาราง/คอลัมน์ให้ตรงกับ schema จริงบน
-- dashboard ก่อนรัน เพราะ repo นี้ไม่เคยมีไฟล์ migration เก็บ schema ไว้
-- มาก่อน (ตรวจสอบจาก Edge Function code เป็นหลัก อาจมีตารางอื่นที่ตกหล่น)

alter table if exists public.profiles enable row level security;
alter table if exists public.user_roles enable row level security;
alter table if exists public.water_tanks enable row level security;
alter table if exists public.complaints enable row level security;
alter table if exists public.repair_items enable row level security;
alter table if exists public.repair_logs enable row level security;
alter table if exists public.status_logs enable row level security;
alter table if exists public.announcements enable row level security;
alter table if exists public.device_tokens enable row level security;

-- อ่านแทงค์น้ำได้แบบสาธารณะ (ทั้ง anon และ authenticated) — ตรงกับที่แอปใช้งานอยู่จริง
drop policy if exists "public can read water tanks" on public.water_tanks;
create policy "public can read water tanks"
  on public.water_tanks
  for select
  to anon, authenticated
  using (true);

-- หมายเหตุ: ไม่เพิ่ม policy insert/update/delete ให้ water_tanks ฝั่ง client
-- เพราะการเขียนทั้งหมดต้องผ่าน Edge Function water-tanks (เช็ค role officer
-- + หมู่บ้านที่ดูแลก่อนเสมอ) ถ้าเปิด policy เขียนให้ client ตรงๆ จะเป็นการ
-- เปิดช่องให้ข้ามการเช็คสิทธิ์ในฟังก์ชันไปเลย
