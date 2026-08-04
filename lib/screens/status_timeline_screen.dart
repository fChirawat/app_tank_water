import 'package:flutter/material.dart';
import '../data/complaint.dart';
import '../data/repair.dart';
import '../services/complaint_service.dart';
import '../theme/app_colors.dart';
import 'complaint_list_screen.dart' show statusColor;

// หน้ารายละเอียดสถานะประปา (ประชาชนแตะการ์ดแล้วเข้ามา)
// แสดง ชื่อ/ประเภท/สถานะ/สาเหตุจริง + timeline ขั้นตอน
class StatusTimelineScreen extends StatefulWidget {
  final String complaintId;
  final String tankName;
  final String tankType;

  const StatusTimelineScreen({
    super.key,
    required this.complaintId,
    required this.tankName,
    required this.tankType,
  });

  @override
  State<StatusTimelineScreen> createState() => _StatusTimelineScreenState();
}

class _StatusTimelineScreenState extends State<StatusTimelineScreen> {
  TimelineResult? _data;
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
      final data = await ComplaintService.getTimeline(widget.complaintId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
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
            _header(),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 14),
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

  Widget _header() {
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
            child: Text('ติดตามสถานะ',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
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
                  style:
                      const TextStyle(color: AppColors.textGrey, fontSize: 13)),
            ),
            TextButton(onPressed: _load, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }

    final c = _data!.complaint;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoCard(c),
          const SizedBox(height: 20),
          const Text('ขั้นตอนการดำเนินงาน',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark)),
          const SizedBox(height: 14),
          _timeline(c),
        ],
      ),
    );
  }

  // การ์ดข้อมูล: ชื่อ/ประเภท/สถานะ/สาเหตุจริง (ถ้ามี)
  Widget _infoCard(Complaint c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5FE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.tankName,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark)),
          const SizedBox(height: 4),
          Text('ประเภท : ${widget.tankType}',
              style:
                  const TextStyle(color: AppColors.textGrey, fontSize: 13)),
          const SizedBox(height: 12),
          // สถานะปัจจุบัน
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor(c.status).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 9, color: statusColor(c.status)),
                const SizedBox(width: 6),
                Text(statusLabel(c.status),
                    style: TextStyle(
                        color: statusColor(c.status),
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          // ปัญหาที่แจ้ง = สาเหตุจริง (โชว์เฉพาะเมื่อเจ้าหน้าที่กรอกแล้ว)
          if (c.surveyNote != null && c.surveyNote!.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            const Text('ปัญหาที่พบ',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary)),
            const SizedBox(height: 4),
            Text(c.surveyNote!,
                style: const TextStyle(
                    color: AppColors.textDark, fontSize: 14)),
          ],
        ],
      ),
    );
  }

  // ===== timeline =====
  Widget _timeline(Complaint c) {
    final logs = _data!.logs;
    if (logs.isEmpty) {
      return const Text('ยังไม่มีประวัติ',
          style: TextStyle(color: AppColors.textGrey));
    }

    // ===== รวมสถานะ + บันทึกการซ่อม เป็นรายการเดียว เรียงตามเวลา =====
    final events = <_TimelineEvent>[];

    // 1) ทุกสถานะ
    for (final log in logs) {
      events.add(_TimelineEvent(
        at: log.at,
        label: statusLabel(log.status),
        color: statusColor(log.status),
        isRepairLog: false,
        status: log.status,
      ));
    }

    // 2) บันทึกการซ่อม (แทรกเป็นจุดย่อยในเส้น)
    for (final r in _data!.repairLogs) {
      events.add(_TimelineEvent(
        at: r.createdAt,
        label: r.note,
        color: AppColors.primary,
        isRepairLog: true,
      ));
    }

    // 3) เรียงตามเวลา (เก่า -> ใหม่)
    events.sort((a, b) => a.at.compareTo(b.at));

    return Column(
      children: List.generate(events.length, (i) {
        final e = events[i];
        final isLast = i == events.length - 1;
        // ขั้นสถานะที่ผ่านไปแล้ว (ไม่ใช่ขั้นล่าสุด) -> ใช้ label แบบ "เสร็จแล้ว"
        // ขั้นล่าสุด -> ใช้ label ปกติ ("รอ...")
        String label = e.label;
        if (!e.isRepairLog && e.status != null && !isLast) {
          label = statusLabelDone(e.status!);
        }
        return _timelineStep(
          label: label,
          time: _formatDate(e.at),
          color: e.color,
          isLast: isLast,
          isCurrent: isLast,
          isRepairLog: e.isRepairLog,
        );
      }),
    );
  }

  Widget _timelineStep({
    required String label,
    required String time,
    required Color color,
    required bool isLast,
    required bool isCurrent,
    bool isRepairLog = false,
  }) {
    // จุดของบันทึกการซ่อม = เล็กกว่า + ไอคอนประแจ
    final dotSize = isRepairLog ? 18.0 : 22.0;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // เส้น + จุด
          Column(
            children: [
              Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: isRepairLog
                      ? Colors.white
                      : (isCurrent ? color : color.withValues(alpha: 0.25)),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Icon(
                  isRepairLog
                      ? Icons.build
                      : (isCurrent
                          ? Icons.radio_button_checked
                          : Icons.check),
                  color: isRepairLog
                      ? color
                      : (isCurrent ? Colors.white : color),
                  size: isRepairLog ? 10 : 13,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: color.withValues(alpha: 0.3),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          // ข้อความ
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: isRepairLog
                  // บันทึกการซ่อม -> การ์ดม่วงอ่อน
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F0FD),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('บันทึกการซ่อม',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 3),
                          Text(label,
                              style: const TextStyle(
                                  color: AppColors.textDark, fontSize: 14)),
                          const SizedBox(height: 3),
                          Text(time,
                              style: const TextStyle(
                                  color: AppColors.textGrey, fontSize: 11.5)),
                        ],
                      ),
                    )
                  // สถานะปกติ
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color:
                                  isCurrent ? color : AppColors.textDark,
                            )),
                        const SizedBox(height: 2),
                        Text(time,
                            style: const TextStyle(
                                color: AppColors.textGrey, fontSize: 12)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      '', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
    ];
    final local = dt.toLocal();
    final year = local.year + 543;
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month]} $year เวลา $hh:$mm น.';
  }
}

// เหตุการณ์ 1 อันใน timeline (สถานะ หรือ บันทึกการซ่อม)
class _TimelineEvent {
  final DateTime at;
  final String label;
  final Color color;
  final bool isRepairLog;
  final ComplaintStatus? status; // สถานะ (null ถ้าเป็นบันทึกซ่อม)
  const _TimelineEvent({
    required this.at,
    required this.label,
    required this.color,
    required this.isRepairLog,
    this.status,
  });
}