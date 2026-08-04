import 'package:flutter/material.dart';
import '../data/complaint.dart';
import '../services/complaint_service.dart';
import '../theme/app_colors.dart';
import 'complaint_detail_screen.dart';

// หน้ารับเรื่องแจ้งซ่อม (เจ้าหน้าที่เห็นทุกเรื่อง)
class ComplaintListScreen extends StatefulWidget {
  const ComplaintListScreen({super.key});

  @override
  State<ComplaintListScreen> createState() => _ComplaintListScreenState();
}

class _ComplaintListScreenState extends State<ComplaintListScreen> {
  List<Complaint> _complaints = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ComplaintService.fetchComplaints();
      if (!mounted) return;
      setState(() {
        // หน้ารับเรื่อง: เห็นเฉพาะเรื่องใหม่ที่ยังรอรับ
        _complaints =
            list.where((c) => c.status == ComplaintStatus.pending).toList();
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

  Future<void> _openDetail(Complaint c) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ComplaintDetailScreen(complaint: c)),
    );
    if (changed == true) _load(); // ถ้ามีการเปลี่ยนสถานะ โหลดใหม่
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
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(22),
                  ),
                ),
                child: _buildList(),
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
                  'รายการร้องเรียน',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'รายการแจ้งปัญหาจากประชาชน',
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

    final items = _complaints;
    if (items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, color: AppColors.textGrey, size: 46),
            SizedBox(height: 12),
            Text('ไม่มีเรื่องรอรับ',
                style: TextStyle(color: AppColors.textGrey, fontSize: 14)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _complaintCard(items[i]),
      ),
    );
  }

  Widget _complaintCard(Complaint c) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'เหตุ : ${c.problemType}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              _statusBadge(c.status),
            ],
          ),
          const SizedBox(height: 8),
          if (c.tankName != null)
            _infoLine('หมู่ : ${c.tankMoo ?? '-'} ${c.tankVillage ?? ''}'),
          if (c.tankName != null)
            _infoLine('ชื่อแทงค์ : ${c.tankName}'),
          if (c.tankType != null)
            _infoLine('ประเภท : ${c.tankType}'),
          _infoLine('วันที่แจ้ง : ${_formatDate(c.createdAt)}'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _cardButton(
              'ดูรายละเอียด',
              bg: AppColors.primary,
              fg: Colors.white,
              onTap: () => _openDetail(c),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
      ),
    );
  }

  Widget _cardButton(String label,
      {required Color bg, required Color fg, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: fg, fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _statusBadge(ComplaintStatus status) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        statusLabel(status),
        style: TextStyle(
            color: color, fontSize: 11.5, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// สีของแต่ละสถานะ (ใช้ร่วมกับหน้ารายละเอียด)
Color statusColor(ComplaintStatus status) {
  switch (status) {
    case ComplaintStatus.pending:
      return const Color(0xFFE8923A); // ส้ม
    case ComplaintStatus.received:
    case ComplaintStatus.surveying:
      return const Color(0xFF3B7DD8); // ฟ้า
    case ComplaintStatus.budgetWait:
      return const Color(0xFFB08A00); // เหลืองเข้ม
    case ComplaintStatus.budgetReview:
      return const Color(0xFFB08A00); // เหลืองเข้ม
    case ComplaintStatus.paladReview:
    case ComplaintStatus.paladWait:
      return const Color(0xFFC77DBB); // ม่วงชมพู
    case ComplaintStatus.repairing:
      return const Color(0xFF7C5CFC); // ม่วง
    case ComplaintStatus.done:
      return const Color(0xFF5CB888); // เขียว
    case ComplaintStatus.rejected:
      return const Color(0xFFD9534F); // แดง
  }
}

// จัดรูปแบบวันที่แบบไทย เช่น 26 มิ.ย. 2569 เวลา 09:30 น.
String _formatDate(DateTime dt) {
  const months = [
    '', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
    'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
  ];
  final local = dt.toLocal();
  final year = local.year + 543; // พ.ศ.
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${months[local.month]} $year เวลา $hh:$mm น.';
}