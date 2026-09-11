// ===== ประเภทปัญหา =====
// อยากเพิ่ม/แก้ แก้ตรงนี้ที่เดียว
const List<String> kProblemTypes = [
  'น้ำไม่ไหล',
  'น้ำไหลอ่อน',
  'น้ำขุ่น / มีตะกอน',
  'น้ำมีกลิ่น / มีสี',
  'ท่อแตก / ท่อรั่ว',
  'มาตรวัดน้ำชำรุด',
  'อื่นๆ',
];

// ===== สถานะของเรื่องร้องเรียน =====
enum ComplaintStatus {
  pending, // รอเจ้าหน้าที่รับเรื่อง
  received, // รับเรื่องแล้ว
  surveying, // ลงพื้นที่ประเมิน
  budgetWait, // รอผู้ใหญ่บ้านรับเรื่อง
  budgetReview, // ผู้ใหญ่บ้านรับแล้ว รออนุมัติ
  paladReview, // งบไม่พอ รอปลัดรับเรื่อง
  paladWait, // ปลัดรับแล้ว รอสมทบงบ
  repairing, // กำลังซ่อม
  done, // ซ่อมเสร็จ
  rejected, // ลงพื้นที่ตรวจสอบแล้วไม่พบปัญหาจริง
}

// แปลงชื่อสถานะจากฐานข้อมูล -> enum
ComplaintStatus statusFromString(String s) {
  switch (s) {
    case 'received':
      return ComplaintStatus.received;
    case 'surveying':
      return ComplaintStatus.surveying;
    case 'budget_wait':
      return ComplaintStatus.budgetWait;
    case 'budget_review':
      return ComplaintStatus.budgetReview;
    case 'palad_review':
      return ComplaintStatus.paladReview;
    case 'palad_wait':
      return ComplaintStatus.paladWait;
    case 'repairing':
      return ComplaintStatus.repairing;
    case 'done':
      return ComplaintStatus.done;
    case 'rejected':
      return ComplaintStatus.rejected;
    default:
      return ComplaintStatus.pending;
  }
}

// ข้อความภาษาไทยของแต่ละสถานะ
String statusLabel(ComplaintStatus s) {
  switch (s) {
    case ComplaintStatus.pending:
      return 'รอเจ้าหน้าที่หมู่บ้านรับเรื่อง';
    case ComplaintStatus.received:
      return 'เจ้าหน้าที่หมู่บ้านรับเรื่องแล้ว';
    case ComplaintStatus.surveying:
      return 'เจ้าหน้าที่ลงพื้นที่ประเมิน';
    case ComplaintStatus.budgetWait:
      return 'รอผู้ใหญ่บ้านรับเรื่อง';
    case ComplaintStatus.budgetReview:
      return 'ผู้ใหญ่บ้านรับเรื่องแล้ว';
    case ComplaintStatus.paladReview:
      return 'งบผู้ใหญ่บ้านไม่พอ ส่งเรื่องไปยังเทศบาล';
    case ComplaintStatus.paladWait:
      return 'เทศบาลรับเรื่องแล้ว';
    case ComplaintStatus.repairing:
      return 'เจ้าหน้าที่กำลังเริ่มซ่อม';
    case ComplaintStatus.done:
      return 'ซ่อมเสร็จ';
    case ComplaintStatus.rejected:
      return 'ไม่พบปัญหาจริง';
  }
}

// ข้อความสำหรับขั้นที่ "ผ่านไปแล้ว" ใน timeline (เปลี่ยน "รอ..." เป็น "...แล้ว")
// ใช้ตอนแสดงประวัติ ขั้นที่เดินผ่านไปแล้วให้ดูเหมือนทำเสร็จ
String statusLabelDone(ComplaintStatus s) {
  switch (s) {
    case ComplaintStatus.pending:
      return 'เจ้าหน้าที่หมู่บ้านรับเรื่องแล้ว';
    case ComplaintStatus.received:
      return 'เจ้าหน้าที่หมู่บ้านรับเรื่องแล้ว';
    case ComplaintStatus.surveying:
      return 'เจ้าหน้าที่ประเมินเสร็จแล้ว';
    case ComplaintStatus.budgetWait:
      return 'ผู้ใหญ่บ้านรับเรื่องแล้ว';
    case ComplaintStatus.budgetReview:
      return 'ผู้ใหญ่บ้านพิจารณางบแล้ว';
    case ComplaintStatus.paladReview:
      return 'ส่งเรื่องไปยังเทศบาลแล้ว';
    case ComplaintStatus.paladWait:
      return 'เทศบาลรับเรื่องแล้ว';
    case ComplaintStatus.repairing:
      return 'เริ่มซ่อมแล้ว';
    case ComplaintStatus.done:
      return 'ซ่อมเสร็จ';
    case ComplaintStatus.rejected:
      return 'ไม่พบปัญหาจริง';
  }
}
class Complaint {
  final String id;
  final String? tankId;
  final String? tankName; // ชื่อแทงค์ (ดึงมาจากตาราง water_tanks)
  final String? tankType; // ประเภทแทงค์
  final String? tankVillage;
  final int? tankMoo;
  final String problemType;
  final String? detail;
  final List<String> imageUrls;
  final double? lat;
  final double? lng;
  final ComplaintStatus status;
  final DateTime createdAt;
  final double? shortfall; // จำนวนเงินที่ขาด (ตอนงบไม่พอ)
  final String? surveyNote; // สาเหตุจริงที่เจ้าหน้าที่กรอก
  // ข้อมูลผู้แจ้ง (join มาจากตาราง profiles)
  final String? reporterName;
  final String? reporterHouseNo;
  final String? reporterVillage;

  const Complaint({
    required this.id,
    this.tankId,
    this.tankName,
    this.tankType,
    this.tankVillage,
    this.tankMoo,
    required this.problemType,
    this.detail,
    this.imageUrls = const [],
    this.lat,
    this.lng,
    required this.status,
    required this.createdAt,
    this.shortfall,
    this.surveyNote,
    this.reporterName,
    this.reporterHouseNo,
    this.reporterVillage,
  });

  factory Complaint.fromJson(Map<String, dynamic> json) {
    // ข้อมูลแทงค์ที่ join มาด้วย (อาจเป็น null ถ้าแทงค์ถูกลบไปแล้ว)
    final tank = json['water_tanks'] as Map<String, dynamic>?;

    // ข้อมูลผู้แจ้ง (join มาจาก profiles)
    final reporter = json['profiles'] as Map<String, dynamic>?;
    String? reporterName;
    if (reporter != null) {
      final t = (reporter['title'] as String?) ?? '';
      final f = (reporter['first_name'] as String?) ?? '';
      final l = (reporter['last_name'] as String?) ?? '';
      reporterName = '$t$f $l'.trim();
    }

    return Complaint(
      id: json['id'] as String? ?? '',
      tankId: json['tank_id'] as String?,
      tankName: tank?['name'] as String?,
      tankType: tank?['type'] as String?,
      tankVillage: tank?['village'] as String?,
      tankMoo: tank?['moo'] as int?,
      problemType: json['problem_type'] as String? ?? '-',
      detail: json['detail'] as String?,
      imageUrls: (json['image_urls'] as List?)?.cast<String>() ?? const [],
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      status: statusFromString(json['status'] as String? ?? 'pending'),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      shortfall: (json['shortfall'] as num?)?.toDouble(),
      surveyNote: json['survey_note'] as String?,
      reporterName: reporterName,
      reporterHouseNo: reporter?['house_no'] as String?,
      reporterVillage: reporter?['village'] as String?,
    );
  }
}