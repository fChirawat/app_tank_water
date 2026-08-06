import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/complaint.dart';
import '../data/tank_status.dart';
import '../data/repair.dart';
import 'session.dart';
import 'package:flutter/foundation.dart';

// ผลลัพธ์ getItems: รายการวัสดุ + สาเหตุที่เจอหน้างาน
class ItemsResult {
  final List<RepairItem> items;
  final String? surveyNote;
  const ItemsResult({required this.items, this.surveyNote});
}

// ประวัติสถานะ 1 รายการ (สำหรับ timeline)
class StatusLog {
  final ComplaintStatus status;
  final DateTime at;
  const StatusLog({required this.status, required this.at});
}

// ผลลัพธ์ timeline: ข้อมูลเรื่อง + ประวัติสถานะ + ความคืบหน้าการซ่อม
class TimelineResult {
  final Complaint complaint;
  final List<StatusLog> logs;
  final List<RepairLog> repairLogs;
  const TimelineResult({
    required this.complaint,
    required this.logs,
    this.repairLogs = const [],
  });
}

// จัดการเรื่องร้องเรียนกับ PostgreSQL
// ทุกอย่างผ่าน Edge Function เพราะเป็นข้อมูลส่วนตัว ต้องเช็คสิทธิ์ก่อน
class ComplaintService {
  static final _supabase = Supabase.instance.client;

  // ===== อัปโหลดรูป 1 รูป =====
  static Future<String> uploadImage(File file) async {
    final fileName = file.path.split(Platform.pathSeparator).last;

    final response = await _supabase.functions.invoke(
      'complaints',
      body: {
        'accessToken': AppSession.accessToken,
        'action': 'upload-url',
        'fileName': fileName,
      },
    );

    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) {
      throw Exception(data['error']);
    }

    final path = data['path'] as String;
    final token = data['token'] as String;
    final publicUrl = data['publicUrl'] as String;

    await _supabase.storage
        .from('tank-images')
        .uploadToSignedUrl(path, token, file);

    return publicUrl;
  }

  // ===== อัปโหลดหลายรูป =====
  static Future<List<String>> uploadImages(List<File> files) async {
    final urls = <String>[];
    for (final f in files) {
      urls.add(await uploadImage(f));
    }
    return urls;
  }

  // ===== แจ้งปัญหา =====
  static Future<Complaint> createComplaint({
    String? tankId,
    required String problemType,
    String? detail,
    List<String> imageUrls = const [],
    double? lat,
    double? lng,
  }) async {
    final response = await _supabase.functions.invoke(
      'complaints',
      body: {
        'accessToken': AppSession.accessToken,
        'action': 'create',
        'complaint': {
          'tankId': tankId,
          'problemType': problemType,
          'detail': detail,
          'imageUrls': imageUrls,
          'lat': lat,
          'lng': lng,
        },
      },
    );

    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) {
      throw Exception(data['error']);
    }

    return Complaint.fromJson(data['complaint'] as Map<String, dynamic>);
  }

  // ===== ดูสถานะประปา (แทงค์ + เรื่องล่าสุด) =====
  // village ว่าง = ทุกหมู่บ้าน
  static Future<List<TankStatus>> fetchTankStatus(String? village) async {
    final response = await _supabase.functions.invoke(
      'complaints',
      body: {
        'accessToken': AppSession.accessToken,
        'action': 'tank-status',
        'village': village ?? '',
      },
    );

    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw Exception(data['error']);

    return (data['tanks'] as List)
        .map((t) => TankStatus.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  // ===== ผู้ใหญ่บ้าน: ดูเรื่อง (เฉพาะหมู่บ้านตัวเอง) =====
  // status: 'budget_wait' (รอรับ) หรือ 'budget_review' (รับแล้ว)
  static Future<List<Complaint>> villageHeadList(String status) async {
    final response = await _supabase.functions.invoke(
      'complaints',
      body: {
        'accessToken': AppSession.accessToken,
        'action': 'village-head-list',
        'status': status,
      },
    );
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw Exception(data['error']);
    return (data['complaints'] as List)
        .map((c) => Complaint.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  // ผู้ใหญ่บ้านรับเรื่อง (budget_wait -> budget_review)
  static Future<void> headReceive(String complaintId) async {
    final response = await _supabase.functions.invoke(
      'complaints',
      body: {
        'accessToken': AppSession.accessToken,
        'action': 'head-receive',
        'complaintId': complaintId,
      },
    );
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw Exception(data['error']);
  }

  // ผู้ใหญ่บ้านตัดสินงบ: 'approve' = งบพอ, 'insufficient' = งบไม่พอ (ต้องมี shortfall)
  static Future<void> headDecide(
    String complaintId,
    String decision, {
    double? shortfall,
  }) async {
    final response = await _supabase.functions.invoke(
      'complaints',
      body: {
        'accessToken': AppSession.accessToken,
        'action': 'head-decide',
        'complaintId': complaintId,
        'decision': decision,
        'shortfall': shortfall,
      },
    );
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw Exception(data['error']);
  }

  // ===== เดินสถานะไปสเต็ปถัดไป (ข้ามไม่ได้) =====
  static Future<void> advanceStatus(String complaintId) async {
    final response = await _supabase.functions.invoke(
      'complaints',
      body: {
        'accessToken': AppSession.accessToken,
        'action': 'advance-status',
        'complaintId': complaintId,
      },
    );
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw Exception(data['error']);
  }

  // ===== วัสดุซ่อม =====
  static Future<void> saveItems(
    String complaintId,
    List<Map<String, dynamic>> items, {
    String? surveyNote, // วัตถุประสงค์
    String? problemType, // ประเภทปัญหา (เจ้าหน้าที่แก้ให้ตรงหน้างาน)
    String? detail, // รายละเอียดปัญหา (เจ้าหน้าที่แก้)
  }) async {
    final response = await _supabase.functions.invoke(
      'complaints',
      body: {
        'accessToken': AppSession.accessToken,
        'action': 'save-items',
        'complaintId': complaintId,
        'items': items,
        'surveyNote': surveyNote,
        'problemType': problemType,
        'detail': detail,
      },
    );
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw Exception(data['error']);
  }

  // คืนทั้งรายการวัสดุ + สาเหตุที่เจอ
  static Future<ItemsResult> getItems(String complaintId) async {
    final response = await _supabase.functions.invoke(
      'complaints',
      body: {
        'accessToken': AppSession.accessToken,
        'action': 'get-items',
        'complaintId': complaintId,
      },
    );
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw Exception(data['error']);
    final items = (data['items'] as List)
        .map((i) => RepairItem.fromJson(i as Map<String, dynamic>))
        .toList();
    return ItemsResult(
      items: items,
      surveyNote: data['surveyNote'] as String?,
    );
  }

  // ===== บันทึกความคืบหน้าการซ่อม =====
  static Future<void> addLog(String complaintId, String note) async {
    final response = await _supabase.functions.invoke(
      'complaints',
      body: {
        'accessToken': AppSession.accessToken,
        'action': 'add-log',
        'complaintId': complaintId,
        'note': note,
      },
    );
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw Exception(data['error']);
  }

  static Future<List<RepairLog>> getLogs(String complaintId) async {
    final response = await _supabase.functions.invoke(
      'complaints',
      body: {
        'accessToken': AppSession.accessToken,
        'action': 'get-logs',
        'complaintId': complaintId,
      },
    );
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw Exception(data['error']);
    return (data['logs'] as List)
        .map((l) => RepairLog.fromJson(l as Map<String, dynamic>))
        .toList();
  }

  // ===== ดูรายการเรื่องร้องเรียน =====
  // ประชาชน -> เห็นเฉพาะของตัวเอง | เจ้าหน้าที่ขึ้นไป -> เห็นทุกเรื่อง
  static Future<List<Complaint>> fetchComplaints() async {
    final response = await _supabase.functions.invoke(
      'complaints',
      body: {
        'accessToken': AppSession.accessToken,
        'action': 'list',
      },
    );

    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) {
      throw Exception(data['error']);
    }

    return (data['complaints'] as List)
        .map((row) => Complaint.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  // ===== ประวัติแจ้งปัญหา (เฉพาะของตัวเอง) แบบแบ่งหน้าทีละ 10 =====
  static Future<MyReportsPage> fetchMyReports({int page = 0}) async {
    final response = await _supabase.functions.invoke(
      'complaints',
      body: {
        'accessToken': AppSession.accessToken,
        'action': 'my-reports',
        'page': page,
      },
    );

    final data = response.data as Map<String, dynamic>;

    if (data['error'] != null) {
      throw Exception(data['error']);
    }

    final items = (data['complaints'] as List)
        .map((row) => Complaint.fromJson(row as Map<String, dynamic>))
        .toList();

    final total = (data['total'] as num?)?.toInt() ?? items.length;

    return MyReportsPage(
      items: items,
      total: total,
      page: page,
    );
  }

  // ===== นับงานค้างของแต่ละเมนู (สำหรับ badge) =====
  static Future<Map<String, int>> menuCounts() async {
    final response = await _supabase.functions.invoke(
      'complaints',
      body: {
        'accessToken': AppSession.accessToken,
        'action': 'menu-counts',
      },
    );
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw Exception(data['error']);
    final raw = (data['counts'] as Map<String, dynamic>?) ?? {};
    return raw.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  // ===== ดึง timeline ประวัติสถานะ =====
  static Future<TimelineResult> getTimeline(String complaintId) async {
    final response = await _supabase.functions.invoke(
      'complaints',
      body: {
        'accessToken': AppSession.accessToken,
        'action': 'get-timeline',
        'complaintId': complaintId,
      },
    );
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw Exception(data['error']);

    final complaint =
        Complaint.fromJson(data['complaint'] as Map<String, dynamic>);
    final logs = (data['timeline'] as List).map((l) {
      final m = l as Map<String, dynamic>;
      return StatusLog(
        status: statusFromString(m['status'] as String? ?? 'pending'),
        at: m['created_at'] != null
            ? DateTime.parse(m['created_at'] as String)
            : DateTime.now(),
      );
    }).toList();

    final repairLogs = (data['repairLogs'] as List? ?? [])
        .map((l) => RepairLog.fromJson(l as Map<String, dynamic>))
        .toList();

    return TimelineResult(
      complaint: complaint,
      logs: logs,
      repairLogs: repairLogs,
    );
  }

  // ===== ปลัด =====
  static Future<List<Complaint>> paladList(String status) async {
    final response = await _supabase.functions.invoke(
      'complaints',
      body: {
        'accessToken': AppSession.accessToken,
        'action': 'palad-list',
        'status': status,
      },
    );
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw Exception(data['error']);
    return (data['complaints'] as List)
        .map((row) => Complaint.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  static Future<void> paladReceive(String complaintId) async {
    final response = await _supabase.functions.invoke(
      'complaints',
      body: {
        'accessToken': AppSession.accessToken,
        'action': 'palad-receive',
        'complaintId': complaintId,
      },
    );
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw Exception(data['error']);
  }

  static Future<void> paladApprove(String complaintId) async {
    final response = await _supabase.functions.invoke(
      'complaints',
      body: {
        'accessToken': AppSession.accessToken,
        'action': 'palad-approve',
        'complaintId': complaintId,
      },
    );
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw Exception(data['error']);
  }

  // ===== Dashboard เทศบาล =====
  // mode: 'month' (year + month) | 'year' (year)
  static Future<DashboardData> fetchPaladDashboard({
    required String mode,
    required int year, // ค.ศ.
    int? month,
  }) async {
    final response = await _supabase.functions.invoke(
      'complaints',
      body: {
        'accessToken': AppSession.accessToken,
        'action': 'palad-dashboard',
        'mode': mode,
        'year': year,
        if (month != null) 'month': month,
      },
    );

    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw Exception(data['error']);

    return DashboardData.fromJson(data);
  }

  // ===== Dashboard ผู้ใหญ่บ้าน =====
  // เห็นเฉพาะหมู่บ้านที่ดูแล และแยกข้อมูลตามแทงค์น้ำ
  static Future<VillageHeadDashboardData> fetchVillageHeadDashboard({
    required String mode,
    required int year, // ค.ศ.
    int? month,
  }) async {
    final response = await _supabase.functions.invoke(
      'complaints',
      body: {
        'accessToken': AppSession.accessToken,
        'action': 'village-head-dashboard',
        'mode': mode,
        'year': year,
        if (month != null) 'month': month,
      },
    );

    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw Exception(data['error']);

    return VillageHeadDashboardData.fromJson(data);
  }

}

// ผลลัพธ์ประวัติแจ้งปัญหา แบบแบ่งหน้า
class MyReportsPage {
  final List<Complaint> items;
  final int total; // จำนวนเรื่องทั้งหมดของคนนี้
  final int page; // หน้าปัจจุบัน (เริ่ม 0)
  const MyReportsPage({
    required this.items,
    required this.total,
    required this.page,
  });

  int get totalPages => (total / 10).ceil();
  bool get hasNext => (page + 1) * 10 < total;
  bool get hasPrev => page > 0;
}

// ===== ข้อมูล Dashboard เทศบาล =====
class DashboardPeriod {
  final String type; // 'month' | 'year'
  final int year; // ค.ศ.
  final int? month; // 1-12 (null = ทั้งปี)
  final String label;

  const DashboardPeriod({
    required this.type,
    required this.year,
    this.month,
    required this.label,
  });

  factory DashboardPeriod.fromJson(Map<String, dynamic> json) {
    return DashboardPeriod(
      type: json['type'] as String,
      year: (json['year'] as num).toInt(),
      month: (json['month'] as num?)?.toInt(),
      label: json['label'] as String,
    );
  }
}

class VillageCount {
  final String village;
  final int count;

  const VillageCount({required this.village, required this.count});
}

class VillageBudget {
  final String village;
  final double budget;

  const VillageBudget({required this.village, required this.budget});
}

class DashboardData {
  final List<VillageCount> donut;
  final List<VillageBudget> bar;
  final int totalReports;
  final double totalBudget;
  final List<DashboardPeriod> periods;

  const DashboardData({
    required this.donut,
    required this.bar,
    required this.totalReports,
    required this.totalBudget,
    required this.periods,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      donut: (json['donut'] as List? ?? [])
          .map(
            (item) => VillageCount(
              village: (item as Map<String, dynamic>)['village'] as String,
              count: (item['count'] as num).toInt(),
            ),
          )
          .toList(),
      bar: (json['bar'] as List? ?? [])
          .map(
            (item) => VillageBudget(
              village: (item as Map<String, dynamic>)['village'] as String,
              budget: (item['budget'] as num).toDouble(),
            ),
          )
          .toList(),
      totalReports: ((json['totalReports'] as num?) ?? 0).toInt(),
      totalBudget: ((json['totalBudget'] as num?) ?? 0).toDouble(),
      periods: (json['periods'] as List? ?? [])
          .map(
            (item) => DashboardPeriod.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}


// ===== ข้อมูล Dashboard ผู้ใหญ่บ้าน =====
class TankCount {
  final String tankId;
  final String tankName;
  final int count;

  const TankCount({
    required this.tankId,
    required this.tankName,
    required this.count,
  });
}

class TankBudget {
  final String tankId;
  final String tankName;
  final double budget;

  const TankBudget({
    required this.tankId,
    required this.tankName,
    required this.budget,
  });
}

class VillageHeadDashboardData {
  final String village;
  final List<TankCount> donut;
  final List<TankBudget> bar;
  final int totalReports;
  final double totalBudget;
  final List<DashboardPeriod> periods;

  const VillageHeadDashboardData({
    required this.village,
    required this.donut,
    required this.bar,
    required this.totalReports,
    required this.totalBudget,
    required this.periods,
  });

  factory VillageHeadDashboardData.fromJson(Map<String, dynamic> json) {
    return VillageHeadDashboardData(
      village: (json['village'] as String?) ?? '',
      donut: (json['donut'] as List? ?? [])
          .map(
            (item) => TankCount(
              tankId: (item as Map<String, dynamic>)['tankId'] as String,
              tankName: item['tankName'] as String,
              count: (item['count'] as num).toInt(),
            ),
          )
          .toList(),
      bar: (json['bar'] as List? ?? [])
          .map(
            (item) => TankBudget(
              tankId: (item as Map<String, dynamic>)['tankId'] as String,
              tankName: item['tankName'] as String,
              budget: (item['budget'] as num).toDouble(),
            ),
          )
          .toList(),
      totalReports: ((json['totalReports'] as num?) ?? 0).toInt(),
      totalBudget: ((json['totalBudget'] as num?) ?? 0).toDouble(),
      periods: (json['periods'] as List? ?? [])
          .map(
            (item) => DashboardPeriod.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}
