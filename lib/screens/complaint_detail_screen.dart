import 'package:flutter/material.dart';
import '../data/complaint.dart';
import '../services/complaint_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_toast.dart';
import '../widgets/app_dialog.dart';
import '../widgets/image_gallery.dart';
import 'complaint_list_screen.dart' show statusColor;
import 'repair_items_screen.dart';
import 'repair_progress_screen.dart';
import 'repair_status_screen.dart';

// หน้ารายละเอียดร้องเรียน (เจ้าหน้าที่)
// เดินสถานะทีละสเต็ป ข้ามไม่ได้
class ComplaintDetailScreen extends StatefulWidget {
  final Complaint complaint;

  const ComplaintDetailScreen({super.key, required this.complaint});

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  late ComplaintStatus _status;
  bool _busy = false;
  bool _changed = false;

  // กรอกรายการวัสดุแล้วหรือยัง (ใช้เปิด/ปิดปุ่มส่งอนุมัติ)
  bool _itemsSaved = false;

  @override
  void initState() {
    super.initState();
    _status = widget.complaint.status;
    // ถ้าอยู่ขั้นประเมิน เช็คว่าเคยกรอกรายการไว้หรือยัง
    if (_status == ComplaintStatus.surveying) {
      _checkItems();
    }
  }

  // เช็คว่ากรอกครบทั้งวัสดุ "และ" สาเหตุ แล้วหรือยัง
  // (ต้องครบทั้ง 2 ถึงจะส่งอนุมัติงบได้)
  Future<void> _checkItems() async {
    try {
      final result = await ComplaintService.getItems(widget.complaint.id);
      if (!mounted) return;
      // ต้องมีวัสดุที่กรอกครบทั้ง 3 (ชื่อ + จำนวน + ราคา) อย่างน้อย 1 รายการ
      final hasCompleteItem = result.items.any((it) =>
          it.name.trim().isNotEmpty && it.quantity > 0 && it.unitPrice > 0);
      final hasNote =
          result.surveyNote != null && result.surveyNote!.trim().isNotEmpty;
      setState(() => _itemsSaved = hasCompleteItem && hasNote);
    } catch (_) {
      // โหลดไม่ได้ก็ถือว่ายังไม่ครบ
    }
  }

  // ยืนยันก่อนส่งอนุมัติงบ (ส่งแล้วเรื่องไปที่ผู้ใหญ่บ้าน ย้อนไม่ได้)
  Future<void> _confirmSendBudget() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ยืนยันส่งอนุมัติงบ'),
        content: const Text(
          'เมื่อส่งแล้ว เรื่องจะถูกส่งต่อให้ผู้ใหญ่บ้านพิจารณางบประมาณ '
          'และจะย้อนกลับมาแก้ไขไม่ได้',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก',
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
            child: const Text('ยืนยันส่ง'),
          ),
        ],
      ),
    );

    if (ok == true) _advance();
  }

  // เดินสถานะไปสเต็ปถัดไป (Edge Function เป็นคนตัดสินว่าไปไหนต่อ)
  Future<void> _advance() async {
    setState(() => _busy = true);
    try {
      await ComplaintService.advanceStatus(widget.complaint.id);
      if (!mounted) return;

      final wasReceiving = _status == ComplaintStatus.pending;
      final next = _nextStatus(_status);

      // ถ้าเพิ่งกด "รับเรื่อง" (pending -> received)
      // ให้เด้งไปหน้าอัปเดตสถานะการซ่อมเลย
      // แล้วปิดหน้านี้ทิ้ง -> พอผู้ใช้กดกลับจะไปอยู่หน้ารายการอัปเดตสถานะ
      if (wasReceiving) {
        // ปิดหน้ารายละเอียด + หน้ารายการเรื่อง (กลับไปหน้า home)
        Navigator.popUntil(context, (route) => route.isFirst);
        // เปิดหน้าอัปเดตสถานะการซ่อม -> เห็นเรื่องที่เพิ่งรับ
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RepairStatusScreen()),
        );
        return;
      }

      setState(() {
        _status = next;
        _changed = true;
        _busy = false;
      });
      AppToast.show(context, 'อัปเดตเป็น "${statusLabel(_status)}" แล้ว');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppDialog.error(context, _cleanError(e));
    }
  }

  // สเต็ปถัดไป (ให้ตรงกับฝั่ง Edge Function)
  ComplaintStatus _nextStatus(ComplaintStatus s) {
    switch (s) {
      case ComplaintStatus.pending:
        return ComplaintStatus.received;
      case ComplaintStatus.received:
        return ComplaintStatus.surveying;
      case ComplaintStatus.surveying:
        return ComplaintStatus.budgetWait;
      case ComplaintStatus.repairing:
        return ComplaintStatus.done;
      default:
        return s;
    }
  }

  String _cleanError(Object e) {
    final msg = e.toString().replaceFirst('Exception: ', '');
    return msg;
  }

  // เปิดหน้ากรอกวัสดุ
  Future<void> _openItems() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RepairItemsScreen(
          complaintId: widget.complaint.id,
          complaint: widget.complaint,
        ),
      ),
    );
    if (saved == true && mounted) {
      // บันทึกแล้วเช็คใหม่ว่าครบทั้งวัสดุและสาเหตุไหม
      _checkItems();
      AppToast.show(context, 'บันทึกรายละเอียดแล้ว');
    }
  }

  // เปิดหน้าบันทึกความคืบหน้า / กดซ่อมเสร็จ
  Future<void> _openProgress() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => RepairProgressScreen(complaintId: widget.complaint.id),
      ),
    );
    if (!mounted) return;
    // ถ้ากดซ่อมเสร็จในหน้านั้น จะส่ง 'done' กลับมา
    if (result == 'done') {
      await _advance(); // repairing -> done
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.complaint;

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
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(22),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusRow(),
                      const SizedBox(height: 18),
                      _buildInfoCard(c),
                      const SizedBox(height: 16),
                      if (c.detail != null && c.detail!.isNotEmpty) ...[
                        _buildDetailCard(c),
                        const SizedBox(height: 16),
                      ],
                      if (c.imageUrls.isNotEmpty) ...[
                        _buildImages(c),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            _buildBottomBar(),
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
            onTap: () => Navigator.pop(context, _changed),
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
            child: Text(
              'รายละเอียดร้องเรียน',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildStatusRow() {
    final color = statusColor(_status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 12, color: color),
          const SizedBox(width: 8),
          const Text('สถานะปัจจุบัน : ',
              style: TextStyle(color: AppColors.textDark, fontSize: 13.5)),
          Text(
            statusLabel(_status),
            style: TextStyle(
                color: color, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(Complaint c) {
    return _card(
      title: 'ข้อมูลร้องเรียน',
      child: Column(
        children: [
          _row('เหตุ', c.problemType),
          if (c.tankVillage != null)
            _row('หมู่', 'หมู่ ${c.tankMoo ?? '-'} ${c.tankVillage}'),
          if (c.tankName != null) _row('ชื่อแทงค์', c.tankName!),
          if (c.tankType != null) _row('ประเภท', c.tankType!),
          _row('วันที่แจ้ง', _formatDate(c.createdAt)),
        ],
      ),
    );
  }

  Widget _buildDetailCard(Complaint c) {
    return _cardPlain(
      title: 'รายละเอียดเพิ่มเติม',
      child: Text(c.detail!,
          style: const TextStyle(color: AppColors.textDark, fontSize: 14)),
    );
  }

  Widget _buildImages(Complaint c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'รูปภาพประกอบ ${c.imageUrls.length} รูป',
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 14.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        ImageGrid(urls: c.imageUrls),
      ],
    );
  }

  // ===== แถบปุ่มล่าง (เปลี่ยนตามสถานะ) =====
  Widget _buildBottomBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: _actionForStatus(),
    );
  }

  Widget _actionForStatus() {
    switch (_status) {
      // รอรับ -> ปุ่มรับเรื่อง
      case ComplaintStatus.pending:
        return _mainButton('รับเรื่อง', _advance);

      // รับเรื่องแล้ว -> ปุ่มลงพื้นที่ประเมิน
      case ComplaintStatus.received:
        return _mainButton('ลงพื้นที่ประเมิน', _advance);

      // ลงพื้นที่ประเมิน -> กรอกวัสดุ + ส่งอนุมัติงบ
      case ComplaintStatus.surveying:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _outlineButton('กรอกรายละเอียด', Icons.list_alt, _openItems),
            const SizedBox(height: 10),
            // ยังไม่บันทึกรายละเอียด -> ปุ่มเทา กดแล้วเตือน
            _itemsSaved
                ? _mainButton('ส่งอนุมัติงบประมาณ', _confirmSendBudget)
                : _disabledButton('ส่งอนุมัติงบประมาณ',
                    'ต้องมีความประสงค์ และวัสดุที่กรอกครบ (ชื่อ จำนวน ราคา) ก่อน'),
          ],
        );

      // รอผู้ใหญ่บ้านรับเรื่อง -> ล็อก
      case ComplaintStatus.budgetWait:
        return _lockedBar('รอผู้ใหญ่บ้านรับเรื่อง');
      // ผู้ใหญ่บ้านรับแล้ว รออนุมัติ -> ล็อก
      case ComplaintStatus.budgetReview:
        return _lockedBar('รอผู้ใหญ่บ้านอนุมัติงบประมาณ');
      // งบไม่พอ รอปลัด -> ล็อก
      case ComplaintStatus.paladReview:
        return _lockedBar('รอเจ้าหน้าที่เทศบาลรับเรื่อง');
      case ComplaintStatus.paladWait:
        return _lockedBar('รอเจ้าหน้าที่เทศบาลสมทบงบประมาณ');

      // กำลังซ่อม -> บันทึกความคืบหน้า / ซ่อมเสร็จ
      case ComplaintStatus.repairing:
        return _mainButton('อัปเดตการซ่อม', _openProgress);

      // จบแล้ว
      case ComplaintStatus.done:
        return _lockedBar('ซ่อมเสร็จเรียบร้อยแล้ว', color: const Color(0xFF5CB888));
      case ComplaintStatus.rejected:
        return _lockedBar('เรื่องนี้ถูกปฏิเสธ', color: const Color(0xFFD9534F));
    }
  }

  // ปุ่มหลักแบบปิดใช้งาน (เทา) — กดแล้วเตือนให้ทำสิ่งที่ขาดก่อน
  Widget _disabledButton(String label, String warning) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: _busy ? null : () => Navigator.pop(context, _changed),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('กลับ',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              // ยังกดได้ แต่แค่เตือน (ไม่เดินสถานะ)
              onPressed: () => AppDialog.warn(context, warning),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBFBFCB), // เทา
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _mainButton(String label, VoidCallback onTap) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: _busy ? null : () => Navigator.pop(context, _changed),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('กลับ',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _busy ? null : onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text(label,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _outlineButton(String label, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _busy ? null : onTap,
        icon: Icon(icon, size: 20),
        label: Text(label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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

  // แถบล็อก (ทำอะไรไม่ได้ รอขั้นตอนอื่น)
  Widget _lockedBar(String text, {Color color = AppColors.textGrey}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_clock, size: 18, color: color),
          const SizedBox(width: 8),
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ===== ชิ้นส่วน UI =====
  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5FE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.info_outline,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  )),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _cardPlain({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              )),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textGrey, fontSize: 13.5)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                )),
          ),
        ],
      ),
    );
  }
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