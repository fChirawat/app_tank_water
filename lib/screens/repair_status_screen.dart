import 'package:flutter/material.dart';
import '../data/complaint.dart';
import '../services/complaint_service.dart';
import '../theme/app_colors.dart';
import 'complaint_detail_screen.dart';
import 'complaint_list_screen.dart' show statusColor;

// หน้าอัปเดตสถานะการซ่อม (เจ้าหน้าที่)
// แสดงเรื่องที่ "รับแล้ว" และยังไม่จบ (ไม่ใช่ pending / done / rejected)
class RepairStatusScreen extends StatefulWidget {
  const RepairStatusScreen({super.key});

  @override
  State<RepairStatusScreen> createState() => _RepairStatusScreenState();
}

class _RepairStatusScreenState extends State<RepairStatusScreen> {
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
        // เห็นเฉพาะเรื่องที่กำลังดำเนินการ (รับแล้ว แต่ยังไม่จบ)
        _complaints = list.where((c) {
          return c.status != ComplaintStatus.pending &&
              c.status != ComplaintStatus.done &&
              c.status != ComplaintStatus.rejected;
        }).toList();
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
    if (changed == true) _load();
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
                  'อัปเดตสถานะการซ่อม',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'เรื่องที่กำลังดำเนินการ',
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

    if (_complaints.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
                color: AppColors.textGrey, size: 46),
            SizedBox(height: 12),
            Text('ไม่มีงานที่กำลังดำเนินการ',
                style: TextStyle(color: AppColors.textGrey, fontSize: 14)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 4, bottom: 20),
        itemCount: _complaints.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _card(_complaints[i]),
      ),
    );
  }

  Widget _card(Complaint c) {
    return GestureDetector(
      onTap: () => _openDetail(c),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ไอคอนสถานะ
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: statusColor(c.status).withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(_statusIcon(c.status),
                  color: statusColor(c.status), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.tankName ?? 'เหตุ : ${c.problemType}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'เหตุ : ${c.problemType}',
                    style: const TextStyle(
                        color: AppColors.textGrey, fontSize: 13),
                  ),
                  if (c.tankVillage != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'หมู่ ${c.tankMoo ?? '-'} ${c.tankVillage}',
                      style: const TextStyle(
                          color: AppColors.textGrey, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _statusBadge(c.status),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(ComplaintStatus status) {
    final color = statusColor(status);
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
            statusLabel(status),
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  IconData _statusIcon(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.received:
        return Icons.assignment_turned_in;
      case ComplaintStatus.surveying:
        return Icons.search;
      case ComplaintStatus.budgetWait:
        return Icons.account_balance_wallet;
      case ComplaintStatus.repairing:
        return Icons.build;
      default:
        return Icons.info_outline;
    }
  }
}