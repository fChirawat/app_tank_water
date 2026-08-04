import 'complaint.dart';

// ===== สถานะของแทงค์ 1 ตัว (สำหรับหน้าสถานะประปา) =====
// รวมข้อมูลแทงค์ + เรื่องร้องเรียนล่าสุด (ถ้ามี)
class TankStatus {
  final String tankId;
  final String name;
  final String type;
  final String village;
  final int moo;
  final double? lat;
  final double? lng;
  final List<String> imageUrls;

  // เรื่องล่าสุดของแทงค์นี้ (null = ไม่เคยมีปัญหา = ปกติ)
  final String? complaintId;
  final ComplaintStatus? latestStatus;
  final String? latestProblem;
  final DateTime? updatedAt;

  const TankStatus({
    required this.tankId,
    required this.name,
    required this.type,
    required this.village,
    required this.moo,
    this.lat,
    this.lng,
    this.imageUrls = const [],
    this.complaintId,
    this.latestStatus,
    this.latestProblem,
    this.updatedAt,
  });

  // แทงค์ปกติไหม (ไม่มีเรื่องค้าง หรือเรื่องล่าสุดซ่อมเสร็จ/ปิดแล้ว)
  bool get isNormal {
    if (latestStatus == null) return true;
    return latestStatus == ComplaintStatus.done ||
        latestStatus == ComplaintStatus.rejected;
  }

  factory TankStatus.fromJson(Map<String, dynamic> json) {
    final latest = json['latest_complaint'] as Map<String, dynamic>?;

    return TankStatus(
      tankId: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      village: json['village'] as String,
      moo: json['moo'] as int,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      imageUrls: (json['image_urls'] as List?)?.cast<String>() ?? const [],
      complaintId: latest?['id'] as String?,
      latestStatus: latest != null
          ? statusFromString(latest['status'] as String? ?? 'pending')
          : null,
      latestProblem: latest?['problem_type'] as String?,
      updatedAt: latest?['updated_at'] != null
          ? DateTime.tryParse(latest!['updated_at'] as String)
          : null,
    );
  }
}