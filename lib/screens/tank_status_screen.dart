import 'package:flutter/material.dart';
import '../data/complaint.dart';
import '../data/tank_status.dart';
import '../data/villages.dart';
import '../services/complaint_service.dart';
import '../services/session.dart';
import '../theme/app_colors.dart';
import 'status_timeline_screen.dart';

// หน้าสถานะประปา (ประชาชนดูได้)
// default = หมู่บ้านของตัวเอง, เลือกดูหมู่บ้านอื่น/ทุกหมู่บ้านได้
class TankStatusScreen extends StatefulWidget {
  const TankStatusScreen({super.key});

  @override
  State<TankStatusScreen> createState() => _TankStatusScreenState();
}

class _TankStatusScreenState extends State<TankStatusScreen> {
  // ค่าพิเศษสำหรับ "ทุกหมู่บ้าน"
  static const String _allVillages = '__all__';

  late String _selectedVillage; // หมู่บ้านที่กำลังดู
  List<TankStatus> _tanks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // default = หมู่บ้านของผู้ใช้ (ตัดคำว่า "หมู่ x" ออก เก็บแค่ชื่อหมู่บ้าน)
    _selectedVillage = _myVillage() ?? _allVillages;
    _load();
  }

  // หาหมู่บ้าน default ให้ตรงกับบทบาท
  // - ผู้ใหญ่บ้าน/เจ้าหน้าที่หมู่บ้าน -> หมู่บ้านที่ตัวเอง "ดูแล" (อาจไม่ใช่หมู่บ้านที่อยู่)
  // - ประชาชน/เจ้าหน้าที่เทศบาล -> หมู่บ้านที่อยู่อาศัยจากโปรไฟล์
  String? _myVillage() {
    if (AppSession.isOfficer && AppSession.officerVillage != null) {
      return AppSession.officerVillage;
    }
    if (AppSession.isVillageHead && AppSession.headVillage != null) {
      return AppSession.headVillage;
    }

    final v = AppSession.profile?['village'] as String?;
    if (v == null || v.isEmpty) return null;
    // โปรไฟล์เก็บเป็น "หมู่ 3 บ้านซาววา" -> เทียบกับ kVillages หาชื่อที่ตรง
    for (final name in kVillages) {
      if (v.contains(name)) return name;
    }
    return null;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final village =
          _selectedVillage == _allVillages ? null : _selectedVillage;
      final tanks = await ComplaintService.fetchTankStatus(village);
      if (!mounted) return;
      setState(() {
        _tanks = tanks;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'โหลดข้อมูลไม่สำเร็จ: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(22),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'หมู่บ้านที่กำลังดู',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildVillageDropdown(),
                    const SizedBox(height: 6),
                    Text(
                      (AppSession.isOfficer || AppSession.isVillageHead)
                          ? 'ค่าเริ่มต้นคือหมู่บ้านที่คุณดูแล'
                          : 'ค่าเริ่มต้นคือหมู่บ้านที่คุณลงทะเบียนไว้',
                      style: const TextStyle(
                          color: AppColors.textGrey, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    Expanded(child: _buildList()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              children: [
                Text(
                  'สถานะประปา',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'แสดงสถานะระบบประปาของหมู่บ้าน',
                  style: TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildVillageDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedVillage,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down,
              color: AppColors.textGrey),
          items: [
            const DropdownMenuItem(
                value: _allVillages, child: Text('ทุกหมู่บ้าน')),
            ...kVillages.map(
                (v) => DropdownMenuItem(value: v, child: Text(v))),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() => _selectedVillage = v);
            _load();
          },
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, color: AppColors.textGrey, size: 40),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textGrey, fontSize: 13)),
            ),
            TextButton(onPressed: _load, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }

    if (_tanks.isEmpty) {
      return const Center(
        child: Text('ไม่มีแทงค์น้ำในหมู่บ้านนี้',
            style: TextStyle(color: AppColors.textGrey)),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 20),
        itemCount: _tanks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _statusCard(_tanks[i]),
      ),
    );
  }

  Widget _statusCard(TankStatus t) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // รูปแทงค์ (ถ้ามี) หรือไอคอนวงกลมสีตามสถานะ
          if (t.imageUrls.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                t.imageUrls.first,
                width: 46,
                height: 46,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _iconBg(t),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_iconData(t), color: _iconColor(t), size: 24),
                ),
              ),
            )
          else
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _iconBg(t),
                shape: BoxShape.circle,
              ),
              child: Icon(_iconData(t), color: _iconColor(t), size: 24),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'ประเภท : ${t.type}',
                  style: const TextStyle(
                      color: AppColors.textGrey, fontSize: 13),
                ),
                const SizedBox(height: 10),
                _statusChip(t),
                // ปุ่มดูรายละเอียด (เฉพาะแทงค์ที่มีเรื่อง)
                if (t.complaintId != null) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StatusTimelineScreen(
                          complaintId: t.complaintId!,
                          tankName: t.name,
                          tankType: t.type,
                        ),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFEAFD),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('ดูรายละเอียด',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ป้ายสถานะ
  Widget _statusChip(TankStatus t) {
    final String label;
    final Color color;

    if (t.isNormal) {
      label = 'ปกติ';
      color = const Color(0xFF5CB888);
    } else {
      label = statusLabel(t.latestStatus!);
      color = _statusColor(t.latestStatus!);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 9, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ===== สี/ไอคอน ตามสถานะ =====
  Color _iconBg(TankStatus t) {
    if (t.isNormal) return const Color(0xFFDDEBFB);
    switch (t.latestStatus!) {
      case ComplaintStatus.repairing:
        return const Color(0xFFFDECD8);
      default:
        return const Color(0xFFFBE0E0);
    }
  }

  Color _iconColor(TankStatus t) {
    if (t.isNormal) return const Color(0xFF4A90E2);
    switch (t.latestStatus!) {
      case ComplaintStatus.repairing:
        return const Color(0xFFE8923A);
      default:
        return const Color(0xFFD9534F);
    }
  }

  IconData _iconData(TankStatus t) {
    if (t.isNormal) return Icons.water_drop;
    switch (t.latestStatus!) {
      case ComplaintStatus.repairing:
        return Icons.build;
      default:
        return Icons.priority_high;
    }
  }

  Color _statusColor(ComplaintStatus s) {
    switch (s) {
      case ComplaintStatus.pending:
        return const Color(0xFFE8923A);
      case ComplaintStatus.received:
      case ComplaintStatus.surveying:
        return const Color(0xFF3B7DD8);
      case ComplaintStatus.budgetWait:
      case ComplaintStatus.budgetReview:
        return const Color(0xFFB08A00);
      case ComplaintStatus.paladReview:
      case ComplaintStatus.paladWait:
        return const Color(0xFFC77DBB);
      case ComplaintStatus.repairing:
        return const Color(0xFF7C5CFC);
      case ComplaintStatus.done:
        return const Color(0xFF5CB888);
      case ComplaintStatus.rejected:
        return const Color(0xFFD9534F);
    }
  }
}