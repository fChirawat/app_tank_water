-- ตั้ง cron job ให้เรียก send-scheduled-announcements ทุก 5 นาที
-- เพื่อไล่ส่ง push ของประกาศที่ตั้งเวลาไว้ล่วงหน้าและถึงเวลาส่งแล้ว
--
-- คำเตือน: ห้ามใส่ค่า secret จริงลงในไฟล์นี้ (ไฟล์นี้เก็บใน git) —
-- แทนที่ '<SCHEDULER_SECRET>' ด้านล่างด้วยค่าจริงตอนรันเอง ค่าจริงต้องตรงกับ
-- Supabase secret ชื่อ SCHEDULER_SECRET (`supabase secrets set
-- SCHEDULER_SECRET=...`) ถ้าจะหมุนรหัสใหม่ ต้องแก้ทั้ง secret และรัน
-- cron.alter_job (หรือ unschedule + schedule ใหม่) ให้ตรงกันทั้งคู่

select cron.schedule(
  'send-scheduled-announcements',
  '*/5 * * * *',
  $$
  select net.http_post(
    url := 'https://qyvgtiotpgqucnrblwen.supabase.co/functions/v1/send-scheduled-announcements',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := jsonb_build_object('secret', '<SCHEDULER_SECRET>')
  );
  $$
);
