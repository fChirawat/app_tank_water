// ===== ข้อมูลแทงค์น้ำ 1 ตัว =====
class WaterTank {
  final String id;
  final String name; // ชื่อแทงค์
  final String type; // ประเภทประปา
  final String village; // หมู่บ้าน
  final int moo; // หมู่ที่
  final String? detail; // รายละเอียดเพิ่มเติม
  final List<String> imageUrls; // รูปภาพ
  final double? lat; // ตำแหน่งบนแผนที่
  final double? lng;

  // ===== ข้อมูลเพิ่มเติมของแทงค์ =====
  final double? capacity; // ความจุ (ลิตร)
  final int? builtYear; // ปีที่สร้าง (พ.ศ.)
  final String? caretaker; // ผู้ดูแล
  final String? caretakerPhone; // เบอร์ติดต่อผู้ดูแล

  const WaterTank({
    required this.id,
    required this.name,
    required this.type,
    required this.village,
    required this.moo,
    this.detail,
    this.imageUrls = const [],
    this.lat,
    this.lng,
    this.capacity,
    this.builtYear,
    this.caretaker,
    this.caretakerPhone,
  });

  // แปลงข้อมูลจากฐานข้อมูล (PostgreSQL) มาเป็น WaterTank
  factory WaterTank.fromJson(Map<String, dynamic> json) {
    return WaterTank(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      village: json['village'] as String,
      moo: json['moo'] as int,
      detail: json['detail'] as String?,
      imageUrls: (json['image_urls'] as List?)?.cast<String>() ?? const [],
      // ฐานข้อมูลอาจส่งมาเป็น int หรือ double ก็ได้ เลยแปลงให้ชัวร์
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      capacity: (json['capacity'] as num?)?.toDouble(),
      builtYear: (json['built_year'] as num?)?.toInt(),
      caretaker: json['caretaker'] as String?,
      caretakerPhone: json['caretaker_phone'] as String?,
    );
  }
}