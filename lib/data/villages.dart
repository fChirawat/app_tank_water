// ===================================================
//  ข้อมูลกลางของแอป — แก้ที่ไฟล์นี้ที่เดียว
//  ทุกหน้าที่ใช้ dropdown จะเปลี่ยนตามอัตโนมัติ
// ===================================================

// ===== หมู่บ้าน =====
// 1 หมู่บ้าน = 1 หมู่ (ตายตัว) เรียงตามหมู่ที่ 1-10
// key = ชื่อหมู่บ้าน, value = หมู่ที่
const Map<String, int> kVillageMooMap = {
  'บุญเรืองเหนือ': 1,
  'บุญเรืองใต้': 2,
  'บ้านซาววา': 3,
  'บ้านหก': 4,
  'ต้นปล้อง': 5,
  'แดนเมือง': 6,
  'บ้านป่าเคาะ': 7,
  'บ้านต้นปล้องใต้': 8,
  'บ้านป่าอ้อ': 9,
  'บ้านภูแกง': 10,
};

// รายชื่อหมู่บ้านอย่างเดียว (ไว้ใส่ dropdown)
List<String> get kVillages => kVillageMooMap.keys.toList();

// หา "หมู่ที่" ของหมู่บ้าน
int? mooOfVillage(String? villageName) {
  if (villageName == null) return null;
  return kVillageMooMap[villageName];
}

// ข้อความเต็ม เช่น "หมู่ 1 บุญเรืองเหนือ"
String villageWithMoo(String villageName) {
  final moo = kVillageMooMap[villageName];
  if (moo == null) return villageName;
  return 'หมู่ $moo $villageName';
}

// รายการข้อความเต็มทั้งหมด (ไว้ใส่ dropdown แบบมีหมู่)
List<String> get kVillagesWithMoo =>
    kVillageMooMap.entries.map((e) => 'หมู่ ${e.value} ${e.key}').toList();

// ===== ประเภทประปา =====
const List<String> kTankTypes = [
  'แทงค์บาดาล',
  'แทงค์ประปาภูเขา',
];