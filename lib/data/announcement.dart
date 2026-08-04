// ประกาศ 1 รายการ
class Announcement {
  final String id;
  final String title; // เรื่อง
  final String? detail; // รายละเอียด
  final DateTime eventDate; // วันที่
  final String? startTime; // เวลาเริ่ม (HH:mm)
  final String? endTime; // เวลาสิ้นสุด
  final List<String> villages; // หมู่บ้านที่ประกาศถึง (ว่าง = ทุกหมู่บ้าน)
  final String? createdByName; // ชื่อเจ้าหน้าที่ที่ประกาศ

  const Announcement({
    required this.id,
    required this.title,
    this.detail,
    required this.eventDate,
    this.startTime,
    this.endTime,
    this.villages = const [],
    this.createdByName,
  });

  // ประกาศนี้สำหรับทุกหมู่บ้านไหม
  bool get isAllVillages => villages.isEmpty;

  // ข้อความบอกว่าประกาศถึงใคร เช่น "บุญเรืองเหนือ, บ้านหก"
  String get villageLabel =>
      isAllVillages ? 'ทุกหมู่บ้าน' : villages.join(', ');

  factory Announcement.fromJson(Map<String, dynamic> json) {
    final creator = json['profiles'] as Map<String, dynamic>?;
    String? name;
    if (creator != null) {
      final t = (creator['title'] as String?) ?? '';
      final f = (creator['first_name'] as String?) ?? '';
      final l = (creator['last_name'] as String?) ?? '';
      name = '$t$f $l'.trim();
    }

    return Announcement(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      detail: json['detail'] as String?,
      eventDate: json['event_date'] != null
          ? DateTime.parse(json['event_date'] as String)
          : DateTime.now(),
      startTime: _shortTime(json['start_time'] as String?),
      endTime: _shortTime(json['end_time'] as String?),
      villages: (json['villages'] as List?)?.cast<String>() ?? const [],
      createdByName: name,
    );
  }

  // ตัด "14:00:00" -> "14:00"
  static String? _shortTime(String? t) {
    if (t == null || t.isEmpty) return null;
    final parts = t.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return t;
  }
}