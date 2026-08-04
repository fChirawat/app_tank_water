import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../data/villages.dart';
import '../services/session.dart';
import '../services/announcement_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_dialog.dart';

// หน้าเจ้าหน้าที่สร้างประกาศ
class AnnouncementCreateScreen extends StatefulWidget {
  const AnnouncementCreateScreen({super.key});

  @override
  State<AnnouncementCreateScreen> createState() =>
      _AnnouncementCreateScreenState();
}

class _AnnouncementCreateScreenState extends State<AnnouncementCreateScreen> {
  final _titleCtrl = TextEditingController();
  final _detailCtrl = TextEditingController();

  DateTime? _date;
  TimeOfDay? _start;
  TimeOfDay? _end;

  // หมู่บ้านที่เลือกไว้ (ว่าง = ทุกหมู่บ้าน)
  final Set<String> _villages = {};

  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _detailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final current = (isStart ? _start : _end) ?? TimeOfDay.now();
    int hour = current.hour;
    int minute = current.minute;

    final picked = await showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // หัว
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('ยกเลิก',
                          style: TextStyle(color: AppColors.textGrey)),
                    ),
                    Text(isStart ? 'เวลาเริ่ม' : 'เวลาสิ้นสุด',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark)),
                    TextButton(
                      onPressed: () => Navigator.pop(
                          ctx, TimeOfDay(hour: hour, minute: minute)),
                      child: const Text('ตกลง',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 200,
                child: Row(
                  children: [
                    // ล้อชั่วโมง 0-23
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(
                            initialItem: hour),
                        itemExtent: 40,
                        onSelectedItemChanged: (i) => hour = i,
                        children: List.generate(
                          24,
                          (i) => Center(
                            child: Text(
                              i.toString().padLeft(2, '0'),
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Text(':',
                        style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.bold)),
                    // ล้อนาที 0-59
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(
                            initialItem: minute),
                        itemExtent: 40,
                        onSelectedItemChanged: (i) => minute = i,
                        children: List.generate(
                          60,
                          (i) => Center(
                            child: Text(
                              i.toString().padLeft(2, '0'),
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _start = picked;
        } else {
          _end = picked;
        }
      });
    }
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      _toast('กรุณากรอกเรื่อง');
      return;
    }
    if (_date == null) {
      _toast('กรุณาเลือกวันที่');
      return;
    }

    setState(() => _saving = true);
    try {
      await AnnouncementService.create(
        title: _titleCtrl.text.trim(),
        detail: _detailCtrl.text.trim().isEmpty
            ? null
            : _detailCtrl.text.trim(),
        eventDate: _date!,
        startTime: _start != null ? _fmtTime(_start!) : null,
        endTime: _end != null ? _fmtTime(_end!) : null,
        // เทศบาล/แอดมิน ส่งที่เลือก / เจ้าหน้าที่หมู่บ้าน ส่งว่าง (server บังคับหมู่ตัวเอง)
        villages: AppSession.canAnnounceAll ? _villages.toList() : [],
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast('สร้างประกาศไม่สำเร็จ: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  void _toast(String m) => AppDialog.warn(context, m);

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
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                  children: [
                    _label('เรื่อง'),
                    _textField(_titleCtrl, 'เช่น น้ำจะหยุดไหลชั่วคราว'),
                    const SizedBox(height: 16),
                    _label('รายละเอียด'),
                    _textField(_detailCtrl, 'อธิบายเพิ่มเติม (ถ้ามี)',
                        maxLines: 3),
                    const SizedBox(height: 16),
                    _label('วันที่'),
                    _pickerBox(
                      _date == null
                          ? 'เลือกวันที่'
                          : _fmtDate(_date!),
                      Icons.calendar_today,
                      _pickDate,
                      filled: _date != null,
                    ),
                    const SizedBox(height: 16),
                    _label('ช่วงเวลา'),
                    Row(
                      children: [
                        Expanded(
                          child: _pickerBox(
                            _start == null ? 'เริ่ม' : _fmtTime(_start!),
                            Icons.access_time,
                            () => _pickTime(true),
                            filled: _start != null,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text('ถึง',
                              style: TextStyle(color: AppColors.textGrey)),
                        ),
                        Expanded(
                          child: _pickerBox(
                            _end == null ? 'สิ้นสุด' : _fmtTime(_end!),
                            Icons.access_time,
                            () => _pickTime(false),
                            filled: _end != null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _label('แจ้งให้'),
                    // เทศบาล/แอดมิน เลือกหมู่บ้านได้ / เจ้าหน้าที่หมู่บ้าน = หมู่ตัวเอง
                    AppSession.canAnnounceAll
                        ? _villagePicker()
                        : _myVillageOnly(),
                    const SizedBox(height: 28),
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
                                    color: Colors.white, strokeWidth: 2.5))
                            : const Text('ประกาศ',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
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
            child: Text('สร้างประกาศ',
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

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark)),
      );

  Widget _textField(TextEditingController c, String hint,
      {int maxLines = 1}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textGrey, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFFAFAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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

  Widget _pickerBox(String text, IconData icon, VoidCallback onTap,
      {bool filled = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textGrey),
            const SizedBox(width: 10),
            Text(text,
                style: TextStyle(
                    color:
                        filled ? AppColors.textDark : AppColors.textGrey,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }

  // ปุ่มเลือกหมู่บ้าน (เลือกได้หลายหมู่)
  // เจ้าหน้าที่หมู่บ้าน: ประกาศได้เฉพาะหมู่ตัวเอง (ล็อกไว้)
  Widget _myVillageOnly() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F0FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryLight),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'หมู่บ้านของคุณ: ${AppSession.myVillage ?? '-'}',
              style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // เลือกหมู่บ้านได้หลายหมู่ (ไม่ติ๊กเลย = ทุกหมู่บ้าน)
  Widget _villagePicker() {
    final isAll = _villages.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ปุ่ม "ทุกหมู่บ้าน" — กดแล้วล้างที่ติ๊กไว้ทั้งหมด
        GestureDetector(
          onTap: () => setState(_villages.clear),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: isAll ? const Color(0xFFEFEAFD) : const Color(0xFFFAFAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isAll ? AppColors.primary : AppColors.border,
                width: isAll ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isAll ? Icons.check_circle : Icons.circle_outlined,
                  color: isAll ? AppColors.primary : AppColors.textGrey,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'ทุกหมู่บ้าน',
                  style: TextStyle(
                    color: isAll ? AppColors.primary : AppColors.textDark,
                    fontSize: 14.5,
                    fontWeight: isAll ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'หรือเลือกเฉพาะหมู่บ้าน (เลือกได้หลายหมู่)',
          style: TextStyle(color: AppColors.textGrey, fontSize: 12.5),
        ),
        const SizedBox(height: 8),
        // รายการหมู่บ้านให้ติ๊ก
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: kVillages.map((v) {
              final checked = _villages.contains(v);
              return InkWell(
                onTap: () => setState(() {
                  if (checked) {
                    _villages.remove(v);
                  } else {
                    _villages.add(v);
                  }
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 11),
                  child: Row(
                    children: [
                      Icon(
                        checked
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        color:
                            checked ? AppColors.primary : AppColors.textGrey,
                        size: 21,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        villageWithMoo(v),
                        style: TextStyle(
                          fontSize: 14.5,
                          color: AppColors.textDark,
                          fontWeight:
                              checked ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // เปิดหน้าต่างติ๊กเลือกหมู่บ้าน

  String _fmtDate(DateTime d) {
    const months = [
      '', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
    ];
    return '${d.day} ${months[d.month]} ${d.year + 543}';
  }
}