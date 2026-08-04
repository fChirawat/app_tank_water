import 'package:flutter/material.dart';
import '../data/complaint.dart';
import '../data/repair.dart';
import '../services/complaint_service.dart';
import '../theme/app_colors.dart';
import '../widgets/image_gallery.dart';
import '../widgets/app_toast.dart';
import '../widgets/app_dialog.dart';
import 'budget_approve_screen.dart';

enum BudgetMode { receive, approve }

// หน้ารายละเอียดงบ (ผู้ใหญ่บ้าน)
// mode receive = กดรับเรื่อง | mode approve = ตัดสินงบพอ/ไม่พอ
// แสดงรายการวัสดุ + ยอดรวม เสมอ (สำคัญ)
class BudgetDetailScreen extends StatefulWidget {
  final Complaint complaint;
  final BudgetMode mode;

  const BudgetDetailScreen({
    super.key,
    required this.complaint,
    required this.mode,
  });

  @override
  State<BudgetDetailScreen> createState() => _BudgetDetailScreenState();
}

class _BudgetDetailScreenState extends State<BudgetDetailScreen> {
  List<RepairItem> _items = [];
  String? _surveyNote; // สาเหตุที่เจอหน้างาน
  bool _loadingItems = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final result = await ComplaintService.getItems(widget.complaint.id);
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _surveyNote = result.surveyNote;
        _loadingItems = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingItems = false);
    }
  }

  double get _total => _items.fold(0.0, (s, it) => s + it.total);

  // ผู้ใหญ่บ้านกดรับเรื่อง
  Future<void> _receive() async {
    setState(() => _busy = true);
    try {
      await ComplaintService.headReceive(widget.complaint.id);
      if (!mounted) return;
      // รับเรื่องแล้วเด้งไปหน้าอนุมัติงบเลย
      // ปิดหน้ารายละเอียด+รายการกลับ home ก่อน แล้วเปิดหน้าอนุมัติงบ
      Navigator.popUntil(context, (route) => route.isFirst);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BudgetApproveScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ===== ป๊อปอัปให้เลือกงบพอ / ไม่พอ =====
  Future<void> _showBudgetChoice() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ขีดบอกลากปิด
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text('ตัดสินงบประมาณ',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('เลือกผลการพิจารณางบประมาณ',
                  style:
                      TextStyle(color: AppColors.textGrey, fontSize: 13)),
              const SizedBox(height: 18),

              // งบพอ
              _choiceCard(
                color: const Color(0xFF5CB888),
                icon: Icons.check_circle,
                title: 'งบพอ อนุมัติ',
                subtitle: 'เริ่มดำเนินการซ่อมได้ทันที',
                onTap: () => Navigator.pop(ctx, 'approve'),
              ),
              const SizedBox(height: 12),

              // งบไม่พอ
              _choiceCard(
                color: const Color(0xFFD9534F),
                icon: Icons.error,
                title: 'งบไม่พอ',
                subtitle: 'กรอกเงินที่ขาด เพื่อส่งให้เจ้าหน้าที่เทศบาลสมทบ',
                onTap: () => Navigator.pop(ctx, 'insufficient'),
              ),
            ],
          ),
        ),
      ),
    );

    if (choice == 'approve') {
      _approve();
    } else if (choice == 'insufficient') {
      _insufficient();
    }
  }

  // การ์ดตัวเลือกในป๊อปอัป
  Widget _choiceCard({
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color, width: 1.3),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: color,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textGrey, fontSize: 12.5)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }

  // งบพอ -> อนุมัติ
  Future<void> _approve() async {
    setState(() => _busy = true);
    try {
      await ComplaintService.headDecide(widget.complaint.id, 'approve');
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // งบไม่พอ -> กรอกเงินที่ขาด -> ส่งปลัด
  Future<void> _insufficient() async {
    final shortfall = await _askShortfall();
    if (shortfall == null) return;

    setState(() => _busy = true);
    try {
      await ComplaintService.headDecide(
        widget.complaint.id,
        'insufficient',
        shortfall: shortfall,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // popup กรอกจำนวนเงินที่ขาด
  Future<double?> _askShortfall() async {
    final ctrl = TextEditingController();
    return showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('งบประมาณไม่พอ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('กรอกจำนวนเงินที่ขาด เพื่อส่งให้เจ้าหน้าที่เทศบาลสมทบ',
                style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
            const SizedBox(height: 8),
            // บอกยอดวัสดุ เพื่อไม่ให้กรอกเกิน
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F0FD),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'ยอดวัสดุทั้งหมด ${_money(_total)} บาท\n(กรอกได้ไม่เกินยอดนี้)',
                style: const TextStyle(
                    color: AppColors.primary, fontSize: 12.5, height: 1.4),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'จำนวนเงิน (บาท)',
                suffixText: 'บาท',
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.trim());
              if (v == null || v <= 0) {
                AppDialog.warn(ctx, 'กรุณากรอกจำนวนเงินให้ถูกต้อง');
                return;
              }
              // ห้ามกรอกเกินยอดวัสดุทั้งหมด
              if (v > _total) {
                AppDialog.warn(ctx,
                    'เงินที่ขาดต้องไม่เกินยอดวัสดุ (${_money(_total)} บาท)');
                return;
              }
              Navigator.pop(ctx, v);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('ส่งให้เจ้าหน้าที่เทศบาล'),
          ),
        ],
      ),
    );
  }

  void _toast(String msg) {
    AppDialog.error(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.complaint;
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoCard(c),
                      const SizedBox(height: 16),
                      _itemsCard(),
                      if (c.imageUrls.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _images(c),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final title = widget.mode == BudgetMode.receive
        ? 'รายละเอียดเรื่อง'
        : 'ตัดสินงบประมาณ';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context, false),
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
          Expanded(
            child: Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _infoCard(Complaint c) {
    return _card(
      title: 'ข้อมูลร้องเรียน',
      child: Column(
        children: [
          if (c.tankName != null) _row('ชื่อแทงค์', c.tankName!),
          if (c.tankType != null) _row('ประเภท', c.tankType!),
          if (c.tankVillage != null)
            _row('หมู่', 'หมู่ ${c.tankMoo ?? '-'} ${c.tankVillage}'),
          _row('ปัญหา', c.problemType),
          if (c.detail != null && c.detail!.isNotEmpty)
            _row('รายละเอียดเพิ่มเติม', c.detail!),
          if (_surveyNote != null && _surveyNote!.isNotEmpty)
            _row('มีความประสงค์', _surveyNote!),
          if (c.shortfall != null && c.shortfall! > 0)
            _row('เงินที่ขาด', '${_money(c.shortfall!)} บาท'),
        ],
      ),
    );
  }

  // ===== รายการวัสดุ + ยอดรวม (สำคัญ) =====
  Widget _itemsCard() {
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
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.receipt_long,
                    color: Colors.white, size: 15),
              ),
              const SizedBox(width: 8),
              const Text('รายการวัสดุที่ต้องใช้',
                  style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 14),
          if (_loadingItems)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (_items.isEmpty)
            const Text('ไม่มีรายการวัสดุ',
                style: TextStyle(color: AppColors.textGrey, fontSize: 13))
          else ...[
            // หัวตาราง
            Row(
              children: const [
                Expanded(
                    flex: 4,
                    child: Text('รายการ',
                        style: TextStyle(
                            color: AppColors.textGrey, fontSize: 12))),
                Expanded(
                    flex: 2,
                    child: Text('จำนวน',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.textGrey, fontSize: 12))),
                Expanded(
                    flex: 3,
                    child: Text('รวม',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            color: AppColors.textGrey, fontSize: 12))),
              ],
            ),
            const Divider(height: 16),
            // แต่ละรายการ
            ..._items.map(_itemRow),
            const Divider(height: 16),
            // ยอดรวม
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('รวมทั้งหมด',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark)),
                Text('${_money(_total)} บาท',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _itemRow(RepairItem it) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(it.name,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textDark)),
                Text('${_money(it.unitPrice)}/ชิ้น',
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.textGrey)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text('${it.quantity}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textDark)),
          ),
          Expanded(
            flex: 3,
            child: Text('${_money(it.total)}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark)),
          ),
        ],
      ),
    );
  }

  Widget _images(Complaint c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('รูปภาพประกอบ ${c.imageUrls.length} รูป',
            style: const TextStyle(
                color: AppColors.primary,
                fontSize: 14.5,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ImageGrid(urls: c.imageUrls),
      ],
    );
  }

  Widget _bottomBar() {
    // โหมดรับเรื่อง -> ปุ่มเดียว
    if (widget.mode == BudgetMode.receive) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _busy ? null : _receive,
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
                        color: Colors.white, strokeWidth: 2.5))
                : const Text('รับเรื่อง',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      );
    }

    // โหมดอนุมัติ -> 2 ปุ่ม: งบไม่พอ / งบพอ
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _busy ? null : _showBudgetChoice,
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
                      color: Colors.white, strokeWidth: 2.5))
              : const Text('ตัดสินงบประมาณ',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
        ),
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
                    color: AppColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.info_outline,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary)),
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
                  color: AppColors.primary)),
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
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _money(double n) {
    final s = n.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}