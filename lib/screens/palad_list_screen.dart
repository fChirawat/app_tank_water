import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../data/complaint.dart';
import '../data/repair.dart';
import '../services/complaint_service.dart';
import '../services/session.dart';
import '../services/request_pdf_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_dialog.dart';
import '../widgets/image_gallery.dart';

enum PaladMode { receive, approve }

// หน้าปลัด: รับเรื่องจากผู้ใหญ่บ้าน / สมทบงบประมาณ
// ปลัดเห็นทุกหมู่บ้าน (ต่างจากผู้ใหญ่บ้านที่เห็นเฉพาะหมู่บ้านตัวเอง)
class PaladListScreen extends StatefulWidget {
  final PaladMode mode;
  const PaladListScreen({super.key, required this.mode});

  @override
  State<PaladListScreen> createState() => _PaladListScreenState();
}

class _PaladListScreenState extends State<PaladListScreen> {
  List<Complaint> _list = [];
  bool _loading = true;
  String? _error;

  String get _status =>
      widget.mode == PaladMode.receive ? 'palad_review' : 'palad_wait';

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
      final list = await ComplaintService.paladList(_status);
      if (!mounted) return;
      setState(() {
        _list = list;
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

  Future<void> _open(Complaint c) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _PaladDetail(complaint: c, mode: widget.mode),
      ),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.mode == PaladMode.receive
        ? 'รับเรื่องจากผู้ใหญ่บ้าน'
        : 'สมทบงบประมาณ';
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            _header(title),
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
                child: _body(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(String title) {
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
          Expanded(
            child: Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _body() {
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
            Text(_error!,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: AppColors.textGrey, fontSize: 13)),
            TextButton(onPressed: _load, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }
    if (_list.isEmpty) {
      return const Center(
        child: Text('ไม่มีเรื่อง',
            style: TextStyle(color: AppColors.textGrey, fontSize: 14)),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 4, bottom: 20),
        itemCount: _list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _card(_list[i]),
      ),
    );
  }

  Widget _card(Complaint c) {
    return GestureDetector(
      onTap: () => _open(c),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('เหตุ : ${c.problemType}',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark)),
            const SizedBox(height: 8),
            if (c.tankName != null)
              _line('ชื่อแทงค์ : ${c.tankName}'),
            if (c.tankVillage != null)
              _line('หมู่ ${c.tankMoo ?? '-'} ${c.tankVillage}'),
            if (c.shortfall != null)
              _line('เงินที่ขาด : ${_money(c.shortfall!)} บาท'),
          ],
        ),
      ),
    );
  }

  Widget _line(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Text(t,
            style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
      );

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

// ===== หน้ารายละเอียดปลัด =====
class _PaladDetail extends StatefulWidget {
  final Complaint complaint;
  final PaladMode mode;
  const _PaladDetail({required this.complaint, required this.mode});

  @override
  State<_PaladDetail> createState() => _PaladDetailState();
}

class _PaladDetailState extends State<_PaladDetail> {
  List<RepairItem> _items = [];
  String? _surveyNote;
  bool _loadingItems = true;
  bool _busy = false;
  bool _makingPdf = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final r = await ComplaintService.getItems(widget.complaint.id);
      if (!mounted) return;
      setState(() {
        _items = r.items;
        _surveyNote = r.surveyNote;
        _loadingItems = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingItems = false);
    }
  }

  double get _total => _items.fold(0.0, (s, it) => s + it.total);

  // สร้างใบคำร้อง PDF แล้วเปิด preview (เซฟ/แชร์ได้จากหน้า preview)
  Future<void> _makePdf() async {
    setState(() => _makingPdf = true);
    try {
      // ชื่อเจ้าหน้าที่เทศบาลที่กดสร้าง (ผู้ยื่นคำร้อง)
      final p = AppSession.profile;
      final name = [
        (p?['title'] as String?) ?? '',
        (p?['first_name'] as String?) ?? '',
        (p?['last_name'] as String?) ?? '',
      ].where((s) => s.isNotEmpty).join(' ');

      final bytes = await RequestPdfService.build(
        complaint: widget.complaint,
        items: _items,
        officerName: name.isEmpty ? '-' : name,
      );
      if (!mounted) return;
      setState(() => _makingPdf = false);
      // เปิด preview (มีปุ่มเซฟ/แชร์/พิมพ์ในตัว)
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() => _makingPdf = false);
      AppDialog.error(context, 'สร้าง PDF ไม่สำเร็จ');
    }
  }

  // ยืนยันก่อนทำ (รับเรื่อง / สมทบงบ อนุมัติ)
  Future<void> _confirmAction() async {
    final isApprove = widget.mode == PaladMode.approve;
    final title = isApprove ? 'ยืนยันสมทบงบและอนุมัติ' : 'ยืนยันรับเรื่อง';
    final message = isApprove
        ? 'เมื่ออนุมัติแล้ว เรื่องจะเข้าสู่ขั้นตอนซ่อม และย้อนกลับมาแก้ไขไม่ได้'
        : 'ยืนยันรับเรื่องนี้เข้าสู่การพิจารณาของเทศบาล';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(message,
            style: const TextStyle(fontSize: 14, height: 1.5)),
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
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );

    if (ok == true) _action();
  }

  Future<void> _action() async {
    setState(() => _busy = true);
    try {
      if (widget.mode == PaladMode.receive) {
        await ComplaintService.paladReceive(widget.complaint.id);
        if (!mounted) return;
        // ปลัดรับเรื่องแล้วเด้งไปหน้าสมทบงบเลย
        Navigator.popUntil(context, (route) => route.isFirst);
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const PaladListScreen(mode: PaladMode.approve)),
        );
        return;
      } else {
        await ComplaintService.paladApprove(widget.complaint.id);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppDialog.error(context, e.toString().replaceFirst('Exception: ', ''));
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
            Padding(
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
                  const Expanded(
                    child: Text('รายละเอียดงบประมาณ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
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
                      _info(c),
                      const SizedBox(height: 16),
                      _itemsCard(c),
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

  Widget _info(Complaint c) {
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

  Widget _itemsCard(Complaint c) {
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
          const Text('รายการวัสดุ',
              style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary)),
          const SizedBox(height: 12),
          if (_loadingItems)
            const Center(child: CircularProgressIndicator(color: AppColors.primary))
          else if (_items.isEmpty)
            const Text('ไม่มีรายการ',
                style: TextStyle(color: AppColors.textGrey, fontSize: 13))
          else ...[
            ..._items.map((it) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                          child: Text('${it.name} x${it.quantity}',
                              style: const TextStyle(fontSize: 14))),
                      Text('${_money(it.total)}',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('รวมทั้งหมด',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                Text('${_money(_total)} บาท',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary)),
              ],
            ),
            if (widget.complaint.shortfall != null) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('เงินที่ขาด',
                      style: TextStyle(
                          fontSize: 14, color: Color(0xFFD9534F))),
                  Text('${_money(widget.complaint.shortfall!)} บาท',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD9534F))),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _bottomBar() {
    final label =
        widget.mode == PaladMode.receive ? 'รับเรื่อง' : 'สมทบงบ อนุมัติ';
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ปุ่มสร้างใบคำร้อง PDF (เฉพาะตอนเทศบาลรับเรื่องแล้ว = โหมดสมทบงบ)
          if (widget.mode == PaladMode.approve) ...[
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: (_busy || _makingPdf) ? null : _makePdf,
                icon: _makingPdf
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2))
                    : const Icon(Icons.picture_as_pdf),
                label: Text(_makingPdf ? 'กำลังสร้าง...' : 'สร้างใบคำร้อง PDF'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _busy ? null : _confirmAction,
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
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(label,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
            ),
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