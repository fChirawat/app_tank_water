-- ฟีเจอร์เสริม: ตั้งเวลาส่งแจ้งเตือนประกาศล่วงหน้า
--
-- เดิมทีตอนสร้างประกาศ ระบบจะยิง push แจ้งเตือนทันที ไม่มีทางเลื่อนเวลาได้
-- ไฟล์นี้เพิ่ม 2 คอลัมน์ให้ตาราง announcements:
--   - push_scheduled_at: เวลาที่ต้องการให้ระบบส่ง push (null = ส่งทันทีเหมือนเดิม)
--   - push_sent: ส่งไปแล้วหรือยัง (ประกาศเก่า/ที่ส่งทันทีถือว่า sent = true อยู่แล้ว
--     ค่า default จึงตั้งเป็น true เพื่อไม่กระทบข้อมูลเดิมที่มีอยู่)
--
-- Edge Function `send-scheduled-announcements` (รันเป็น cron ทุก 5 นาที ผ่าน
-- pg_cron + pg_net) จะไล่หาแถวที่ push_sent = false และ push_scheduled_at ผ่าน
-- ไปแล้ว แล้วค่อยยิง push ให้ พร้อมอัปเดต push_sent = true

alter table if exists public.announcements
  add column if not exists push_scheduled_at timestamptz null;

alter table if exists public.announcements
  add column if not exists push_sent boolean not null default true;

-- ช่วยให้ cron job ค้นแถวที่ยังไม่ส่งได้เร็วขึ้น
create index if not exists idx_announcements_pending_push
  on public.announcements (push_scheduled_at)
  where push_sent = false;
