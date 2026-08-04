import 'package:flutter/material.dart';
import '../data/repair.dart';
import '../services/complaint_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_toast.dart';
import '../widgets/app_dialog.dart';

// หน้าอัปเดตการซ่อม (สถานะ "กำลังซ่อม")
// - ถ้าซ่อมเสร็จวันเดียว -> กดซ่อมเสร็จ
// - ถ้ายังไม่เสร็จ -> บันทึกว่าวันนี้ทำอะไรไปบ้าง
class RepairProgressScreen extends StatefulWidget {
  final String complaintId;

  const RepairProgressScreen({super.key, required this.complaintId});

  @override
  State<RepairProgressScreen> createState() => _RepairProgressScreenState();
}

class _RepairProgressScreenState extends State<RepairProgressScreen> {
  final _noteController = TextEditingController();

  List<RepairLog> _logs = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    try {
      final logs = await ComplaintService.getLogs(widget.complaintId);
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // บันทึกความคืบหน้าวันนี้
  Future<void> _saveLog() async {
    final note = _noteController.text.trim();
    if (note.isEmpty) {
      AppDialog.warn(context, 'กรุณากรอกรายละเอียดการซ่อม');
      return;
    }

    // ยืนยันก่อนบันทึก (แก้ไขทีหลังไม่ได้)
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ยืนยันการบันทึก'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ตรวจสอบข้อความก่อนบันทึก',
                style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F0FD),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(note,
                  style: const TextStyle(
                      color: AppColors.textDark, fontSize: 14)),
            ),
            const SizedBox(height: 12),
            Row(
              children: const [
                Icon(Icons.info_outline,
                    size: 16, color: Color(0xFFE8923A)),
                SizedBox(width: 6),
                Expanded(
                  child: Text('เมื่อบันทึกแล้วจะแก้ไขไม่ได้',
                      style: TextStyle(
                          color: Color(0xFFB5701F), fontSize: 12.5)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('แก้ไขอีกครั้ง',
                style: TextStyle(color: AppColors.textGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('ยืนยันบันทึก'),
          ),
        ],
      ),
    );

    if (confirmed != true) return; // ยกเลิก -> ไม่บันทึก

    setState(() => _saving = true);
    try {
      await ComplaintService.addLog(widget.complaintId, note);
      if (!mounted) return;
      _noteController.clear();
      setState(() => _saving = false);
      _loadLogs(); // โหลดประวัติใหม่
      AppToast.show(context, 'บันทึกความคืบหน้าแล้ว');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppDialog.error(context, 'บันทึกไม่สำเร็จ');
    }
  }

  // กดซ่อมเสร็จ -> ยืนยันก่อน แล้วส่ง 'done' กลับไปให้หน้ารายละเอียดเดินสถานะ
  void _markDone() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ยืนยันการซ่อมเสร็จ'),
        content: const Text('ยืนยันว่าซ่อมแซมเสร็จเรียบร้อยแล้ว?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, 'done'); // ส่งสัญญาณกลับ
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('ซ่อมเสร็จ'),
          ),
        ],
      ),
    );
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
                    // ช่องกรอกความคืบหน้าวันนี้
                    const Text(
                      'บันทึกความคืบหน้าวันนี้',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildNoteField(),
                    const SizedBox(height: 10),
                    _buildSaveLogButton(),
                    const SizedBox(height: 20),
                    const Text(
                      'ประวัติการซ่อม',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(child: _buildLogs()),
                  ],
                ),
              ),
            ),
            _buildDoneBar(),
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
                  'อัปเดตการซ่อม',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'บันทึกความคืบหน้า หรือแจ้งซ่อมเสร็จ',
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

  Widget _buildNoteField() {
    return TextField(
      controller: _noteController,
      maxLines: 3,
      decoration: InputDecoration(
        hintText: 'วันนี้ทำอะไรไปบ้าง...\nเช่น เปลี่ยนท่อ PVC แล้ว รอปูนแห้งพรุ่งนี้ต่อ',
        hintStyle: const TextStyle(color: AppColors.textGrey, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFFAFAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildSaveLogButton() {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton.icon(
        onPressed: _saving ? null : _saveLog,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              )
            : const Icon(Icons.save_outlined, size: 20),
        label: const Text('บันทึกความคืบหน้า',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildLogs() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_logs.isEmpty) {
      return const Center(
        child: Text('ยังไม่มีบันทึกความคืบหน้า',
            style: TextStyle(color: AppColors.textGrey)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _logs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _logCard(_logs[i]),
    );
  }

  Widget _logCard(RepairLog log) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, size: 14, color: AppColors.textGrey),
              const SizedBox(width: 6),
              Text(
                _formatDate(log.createdAt),
                style: const TextStyle(
                    color: AppColors.textGrey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            log.note,
            style: const TextStyle(color: AppColors.textDark, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildDoneBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: _markDone,
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('ซ่อมเสร็จแล้ว',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5CB888),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
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
    return '${local.day} ${months[local.month]} $year $hh:$mm น.';
  }
}