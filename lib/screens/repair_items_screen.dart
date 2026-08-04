import 'package:flutter/material.dart';
import '../data/repair.dart';
import '../services/complaint_service.dart';
import '../data/complaint.dart';
import '../theme/app_colors.dart';
import '../widgets/app_toast.dart';
import '../widgets/app_dialog.dart';

// หน้ากรอกรายการวัสดุซ่อม
// กรอก ชื่อ/จำนวน/ราคาต่อชิ้น -> ระบบรวมเงินให้
class RepairItemsScreen extends StatefulWidget {
  final String complaintId;
  final Complaint complaint; // เรื่องที่แจ้งมา (ไว้แสดงปัญหาที่ผู้แจ้งกรอก)

  const RepairItemsScreen({
    super.key,
    required this.complaintId,
    required this.complaint,
  });

  @override
  State<RepairItemsScreen> createState() => _RepairItemsScreenState();
}

// แถววัสดุ 1 รายการ (ยังกรอกอยู่ในหน้าจอ)
class _ItemRow {
  final nameCtrl = TextEditingController();
  final qtyCtrl = TextEditingController();
  final priceCtrl = TextEditingController();

  double get total {
    final q = int.tryParse(qtyCtrl.text) ?? 0;
    final p = double.tryParse(priceCtrl.text) ?? 0;
    return q * p;
  }

  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

class _RepairItemsScreenState extends State<RepairItemsScreen> {
  final List<_ItemRow> _rows = [];
  final _surveyCtrl = TextEditingController(); // วัตถุประสงค์
  // ประเภท + รายละเอียดปัญหา (ดึงของเดิมมา แก้ได้)
  late String _problemType;
  final _detailCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // เริ่มจากข้อมูลที่ผู้แจ้งกรอกมา (เจ้าหน้าที่แก้ให้ตรงกับที่เจอจริงได้)
    _problemType = widget.complaint.problemType;
    _detailCtrl.text = widget.complaint.detail ?? '';
    _loadExisting();
  }

  @override
  void dispose() {
    _surveyCtrl.dispose();
    _detailCtrl.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  // โหลดวัสดุที่เคยกรอกไว้ (ถ้ามี) มาแก้ต่อได้
  Future<void> _loadExisting() async {
    try {
      final result = await ComplaintService.getItems(widget.complaintId);
      if (!mounted) return;
      setState(() {
        _surveyCtrl.text = result.surveyNote ?? '';
        for (final it in result.items) {
          final row = _ItemRow();
          row.nameCtrl.text = it.name;
          row.qtyCtrl.text = it.quantity.toString();
          row.priceCtrl.text = it.unitPrice.toStringAsFixed(0);
          _rows.add(row);
        }
        if (_rows.isEmpty) _rows.add(_ItemRow());
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _rows.add(_ItemRow());
        _loading = false;
      });
    }
  }

  double get _grandTotal =>
      _rows.fold(0.0, (sum, r) => sum + r.total);

  void _addRow() => setState(() => _rows.add(_ItemRow()));

  void _removeRow(int i) {
    setState(() {
      _rows[i].dispose();
      _rows.removeAt(i);
      if (_rows.isEmpty) _rows.add(_ItemRow());
    });
  }

  Future<void> _save() async {
    // เอาเฉพาะแถวที่มีชื่อวัสดุ (จำนวน/ราคาไม่ครบก็ให้ 0 ไปก่อน)
    final valid = _rows.where((r) {
      return r.nameCtrl.text.trim().isNotEmpty;
    }).toList();

    final surveyNote = _surveyCtrl.text.trim();

    // ต้องมีอย่างน้อยอย่างใดอย่างหนึ่ง: วัสดุ หรือ สาเหตุ
    if (valid.isEmpty && surveyNote.isEmpty) {
      AppDialog.warn(context, 'กรุณากรอกความประสงค์ หรือ วัสดุอย่างน้อย 1 อย่าง');
      return;
    }

    setState(() => _saving = true);
    try {
      final items = valid
          .map((r) => {
                'name': r.nameCtrl.text.trim(),
                // จำนวน/ราคาถ้าไม่กรอก ให้เป็น 0
                'quantity': int.tryParse(r.qtyCtrl.text) ?? 0,
                'unitPrice': double.tryParse(r.priceCtrl.text) ?? 0,
              })
          .toList();

      await ComplaintService.saveItems(
        widget.complaintId,
        items,
        surveyNote: surveyNote.isEmpty ? null : surveyNote,
        problemType: _problemType,
        detail: _detailCtrl.text.trim().isEmpty ? null : _detailCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true); // บอกหน้าก่อนหน้าว่าบันทึกแล้ว
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppDialog.error(context, 'บันทึกไม่สำเร็จ');
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
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(22),
                  ),
                ),
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary),
                      )
                    : Column(
                        children: [
                          Expanded(child: _buildRows()),
                          _buildTotalBar(),
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
                  'กรอกรายละเอียด',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'กรอกความประสงค์และวัสดุที่ใช้ (ไม่ครบก็บันทึกได้)',
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

  Widget _buildRows() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      children: [
        // ปัญหาที่ผู้แจ้งกรอกมา (อ่านอย่างเดียว)
        _buildReportedProblem(),
        const SizedBox(height: 18),
        // ช่องวัตถุประสงค์
        _buildSurveyField(),
        const SizedBox(height: 18),
        const Text('รายการวัสดุ',
            style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark)),
        const SizedBox(height: 10),
        ...List.generate(_rows.length, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _itemCard(i),
        )),
        _buildAddButton(),
      ],
    );
  }

  // ช่องกรอกสาเหตุที่เจอหน้างาน
  // ปัญหาที่ผู้แจ้งกรอกมา (อ่านอย่างเดียว)
  Widget _buildReportedProblem() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0C896)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.report_problem, color: Color(0xFFE8923A), size: 18),
              SizedBox(width: 6),
              Text('ปัญหาที่เจอจริงหน้างาน',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB5701F))),
            ],
          ),
          const SizedBox(height: 4),
          const Text('แก้ให้ตรงกับที่เจอจริงได้ (ดึงจากที่ผู้แจ้งกรอกมา)',
              style: TextStyle(color: AppColors.textGrey, fontSize: 11.5)),
          const SizedBox(height: 12),

          // ประเภทปัญหา (dropdown)
          const Text('ประเภท',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF0C896)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: kProblemTypes.contains(_problemType)
                    ? _problemType
                    : null,
                hint: const Text('เลือกประเภท'),
                isExpanded: true,
                items: kProblemTypes
                    .map((t) =>
                        DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _problemType = v);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // รายละเอียด (ช่องกรอก)
          const Text('รายละเอียด',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark)),
          const SizedBox(height: 6),
          TextField(
            controller: _detailCtrl,
            maxLines: 3,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'อธิบายปัญหาที่เจอจริงหน้างาน',
              hintStyle:
                  const TextStyle(color: AppColors.textGrey, fontSize: 13),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFF0C896)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFF0C896)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: Color(0xFFE8923A), width: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurveyField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('มีความประสงค์',
            style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark)),
        const SizedBox(height: 4),
        const Text('ระบุสิ่งที่ต้องการดำเนินการ',
            style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
        const SizedBox(height: 8),
        TextField(
          controller: _surveyCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'เช่น ต้องการเปลี่ยนท่อประปาที่แตก ให้น้ำไหลปกติ',
            hintStyle:
                const TextStyle(color: AppColors.textGrey, fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFFAFAFC),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _itemCard(int index) {
    final row = _rows[index];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'รายการที่ ${index + 1}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _removeRow(index),
                child: const Icon(Icons.delete_outline,
                    color: Color(0xFFD9534F), size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ชื่อวัสดุ
          _field(row.nameCtrl, 'ชื่อวัสดุ เช่น ท่อ PVC', onChanged: _refresh),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _field(row.qtyCtrl, 'จำนวน',
                    number: true, onChanged: _refresh),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _field(row.priceCtrl, 'ราคา/ชิ้น',
                    number: true, onChanged: _refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ราคารวมของแถวนี้
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'รวม ${_formatMoney(row.total)} บาท',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _addRow,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F1FD),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.4),
            width: 1.2,
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: AppColors.primary, size: 20),
            SizedBox(width: 6),
            Text('เพิ่มรายการวัสดุ',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // แถบรวมเงิน + ปุ่มยืนยัน
  Widget _buildTotalBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'รวมทั้งหมด',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                '${_formatMoney(_grandTotal)} บาท',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text('บันทึกรายละเอียด',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _refresh() => setState(() {});

  Widget _field(
    TextEditingController controller,
    String hint, {
    bool number = false,
    VoidCallback? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      onChanged: (_) => onChanged?.call(),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textGrey, fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  // ใส่ comma คั่นหลักพัน เช่น 12,500
  String _formatMoney(double n) {
    final s = n.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}