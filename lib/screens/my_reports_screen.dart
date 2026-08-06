import 'package:flutter/material.dart';
import '../data/complaint.dart';
import '../services/complaint_service.dart';
import '../theme/app_colors.dart';
import 'complaint_list_screen.dart' show statusColor;
import 'status_timeline_screen.dart';

// หน้าประวัติแจ้งปัญหา (ประชาชนดูเฉพาะเรื่องที่ตัวเองแจ้ง)
// รูปแบบเดียวกับหน้าสถานะประปา
class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  List<Complaint> _reports = [];
  int _page = 0;
  int _total = 0;
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
      final result = await ComplaintService.fetchMyReports(page: _page);
      if (!mounted) return;
      setState(() {
        _reports = result.items;
        _total = result.total;
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

  int get _totalPages => (_total / 10).ceil();
  bool get _hasNext => (_page + 1) * 10 < _total;
  bool get _hasPrev => _page > 0;

  void _goPage(int p) {
    setState(() => _page = p);
    _load();
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
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(22),
                  ),
                ),
                child: _buildBody(),
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
                  'ประวัติแจ้งปัญหา',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'เรื่องที่คุณเคยแจ้งไว้',
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

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.textGrey, size: 46),
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textGrey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }
    if (_reports.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, color: AppColors.textGrey, size: 46),
            SizedBox(height: 12),
            Text('ยังไม่มีประวัติการแจ้งปัญหา',
                style: TextStyle(color: AppColors.textGrey, fontSize: 15)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 20),
              itemCount: _reports.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _reportCard(_reports[i]),
            ),
          ),
          if (_totalPages > 1) _buildPager(),
        ],
      ),
    );
  }

  // แถบแบ่งหน้า: ก่อนหน้า / หน้า x จาก y / ถัดไป
  Widget _buildPager() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _hasPrev ? () => _goPage(_page - 1) : null,
            icon: const Icon(Icons.chevron_left),
            color: AppColors.primary,
            disabledColor: AppColors.border,
          ),
          Text(
            'หน้า ${_page + 1} จาก $_totalPages',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark),
          ),
          IconButton(
            onPressed: _hasNext ? () => _goPage(_page + 1) : null,
            icon: const Icon(Icons.chevron_right),
            color: AppColors.primary,
            disabledColor: AppColors.border,
          ),
        ],
      ),
    );
  }

  Widget _reportCard(Complaint c) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StatusTimelineScreen(
            complaintId: c.id,
            tankName: c.tankName ?? '-',
            tankType: c.tankType ?? '-',
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ชื่อแทงค์ + สถานะ
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    c.tankName ?? 'ไม่ระบุแทงค์',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _statusChip(c.status),
              ],
            ),

            const SizedBox(height: 8),

            // ปัญหาที่แจ้ง
            Text(
              'ปัญหา : ${c.problemType}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),

            // รายละเอียดปัญหา
            if (c.detail != null && c.detail!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'รายละเอียด : ${c.detail}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 12.5,
                ),
              ),
            ],

            const SizedBox(height: 8),

            // วันที่ + ดูรายละเอียด
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 13,
                  color: AppColors.textGrey,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    _fmtDate(c.createdAt),
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Text(
                  'ดูรายละเอียด',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(ComplaintStatus status) {
    final color = statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    const months = [
      '', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
    ];
    final local = dt.toLocal();
    final year = local.year + 543;
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month]} $year $hh:$mm น.';
  }
}