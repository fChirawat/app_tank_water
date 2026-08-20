// รายชื่อฟีเจอร์เสริมทั้งหมดที่ปลดล็อกได้ — เพิ่มฟีเจอร์ใหม่แค่เพิ่มรายการในนี้
// (id ต้องตรงกับ key ใน FEATURE_UNLOCK_CODES ฝั่ง
// supabase/functions/admin-users/index.ts)
class AddonFeature {
  final String id;
  final String title;
  final String description;

  const AddonFeature({
    required this.id,
    required this.title,
    required this.description,
  });
}

const List<AddonFeature> kAddonFeatures = [
  AddonFeature(
    id: 'pdf_signer',
    title: 'กำหนดชื่อผู้ลงนามใน PDF เอง',
    description:
        'เลือกชื่อ/ตำแหน่งผู้ลงนามในใบคำร้องเองทุกครั้งที่สร้าง PDF '
        'แทนที่จะใช้ชื่อที่ตั้งไว้ตายตัว',
  ),
  AddonFeature(
    id: 'dashboard_print',
    title: 'พิมพ์รายงาน Dashboard',
    description:
        'พิมพ์/บันทึกสรุปสถิติของ Dashboard (ผู้ใหญ่บ้าน/เทศบาล) เป็น PDF',
  ),
  AddonFeature(
    id: 'dashboard_compare',
    title: 'เปรียบเทียบสถิติย้อนหลัง',
    description:
        'เทียบจำนวนเรื่อง/งบของช่วงเวลาที่ดูอยู่ กับเดือนที่แล้วหรือปีที่แล้ว',
  ),
  AddonFeature(
    id: 'scheduled_announcement',
    title: 'ตั้งเวลาส่งประกาศล่วงหน้า',
    description:
        'ตั้งเวลาให้ระบบส่งแจ้งเตือนประกาศอัตโนมัติในอนาคต '
        'แทนที่จะต้องส่งทันทีตอนสร้าง',
  ),
];
