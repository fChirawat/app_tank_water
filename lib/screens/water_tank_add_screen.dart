import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_colors.dart';
import '../widgets/image_gallery.dart';
import '../widgets/app_dialog.dart';
import '../data/picked_image.dart';
import '../data/villages.dart';
import '../data/water_tank.dart';
import '../services/tank_service.dart';
import '../services/session.dart';
import 'map_picker_screen.dart';

// หน้าเพิ่ม/แก้ไขข้อมูลแทงค์น้ำ
// ถ้าส่ง tank เข้ามา = โหมดแก้ไข / ไม่ส่ง = โหมดเพิ่มใหม่
class WaterTankAddScreen extends StatefulWidget {
  final WaterTank? tank;

  const WaterTankAddScreen({super.key, this.tank});

  @override
  State<WaterTankAddScreen> createState() => _WaterTankAddScreenState();
}

class _WaterTankAddScreenState extends State<WaterTankAddScreen> {
  final _nameController = TextEditingController();
  final _detailController = TextEditingController();
  final _capacityController = TextEditingController();
  final _builtYearController = TextEditingController();
  final _caretakerController = TextEditingController();
  final _caretakerPhoneController = TextEditingController();

  // รูปเดิมที่เคยอัปโหลดไว้ (เฉพาะโหมดแก้ไข)
  final List<String> _existingImageUrls = [];

  // โหมดแก้ไขไหม
  bool get _isEdit => widget.tank != null;

  String? _selectedType; // ประเภทประปา
  String? _selectedVillage; // หมู่บ้าน
  int? _selectedMoo; // หมู่ที่

  double? _lat; // ตำแหน่งบนแผนที่
  double? _lng;

  final List<PickedImage> _images = []; // รูปที่เลือกไว้ (ยังไม่ได้อัปโหลด)
  bool _saving = false; // กำลังบันทึกอยู่ไหม (กันกดซ้ำ)
  String _savingText = ''; // บอกว่ากำลังทำอะไรอยู่

  @override
  void initState() {
    super.initState();
    // โหมดแก้ไข -> เติมข้อมูลเดิมลงฟอร์ม
    final t = widget.tank;
    if (t != null) {
      // เจ้าหน้าที่หมู่บ้าน (ไม่ใช่เทศบาล/แอดมิน) แก้ได้เฉพาะแทงค์ในหมู่บ้าน
      // ตัวเองเท่านั้น — ถ้าหลุดเข้ามาแก้แทงค์หมู่บ้านอื่นได้ (เช่นจากลิงก์เก่า)
      // ให้เตะออกทันที กันฟอร์มโชว์ค่าหมู่บ้านผิด (ล็อกช่องเป็นหมู่บ้านของแทงค์
      // แทนที่จะเป็นหมู่บ้านที่ตัวเองดูแลจริง ทำให้บันทึกไปเซิร์ฟเวอร์ก็ปฏิเสธอยู่ดี
      // แต่ผู้ใช้จะงงว่าทำไมกดบันทึกไม่ผ่าน)
      if (_lockVillage && t.moo != mooFromLabel(AppSession.officerVillage)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          AppDialog.error(context, 'แก้ไขได้เฉพาะแทงค์น้ำในหมู่บ้านที่ดูแลเท่านั้น');
          Navigator.pop(context);
        });
      }
      _nameController.text = t.name;
      _detailController.text = t.detail ?? '';
      _capacityController.text =
          t.capacity != null ? t.capacity!.toStringAsFixed(0) : '';
      _builtYearController.text = t.builtYear?.toString() ?? '';
      _caretakerController.text = t.caretaker ?? '';
      _caretakerPhoneController.text = t.caretakerPhone ?? '';
      _selectedType = t.type;
      _selectedVillage = t.village;
      _selectedMoo = t.moo;
      _lat = t.lat;
      _lng = t.lng;
      _existingImageUrls.addAll(t.imageUrls);
    } else {
      // โหมดเพิ่มใหม่: ถ้าเป็นเจ้าหน้าที่หมู่บ้าน (ไม่ใช่เทศบาล/แอดมิน)
      // ล็อกหมู่บ้านเป็นหมู่ที่ตัวเองดูแล
      if (_lockVillage) {
        final officerMoo = mooFromLabel(AppSession.officerVillage);
        _selectedMoo = officerMoo;
        _selectedVillage = villageNameOfMoo(officerMoo);
      }
    }
  }

  // เมนูเพิ่มแทงค์เป็นของเจ้าหน้าที่หมู่บ้าน -> ล็อกหมู่บ้านตัวเองเสมอ
  bool get _lockVillage => AppSession.officerVillage != null;

  @override
  void dispose() {
    _nameController.dispose();
    _detailController.dispose();
    _capacityController.dispose();
    _builtYearController.dispose();
    _caretakerController.dispose();
    _caretakerPhoneController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    // เช็คข้อมูลที่จำเป็น
    if (_nameController.text.trim().isEmpty) {
      _toast('กรุณากรอกชื่อแทงค์');
      return;
    }
    if (_selectedType == null) {
      _toast('กรุณาเลือกประเภทประปา');
      return;
    }
    if (_selectedVillage == null) {
      _toast('กรุณาเลือกหมู่บ้าน');
      return;
    }
    if (_saving) return;
    setState(() {
      _saving = true;
      _savingText = 'กำลังบันทึก...';
    });

    try {
      // 1) อัปโหลดรูปใหม่ (ถ้ามี) แล้วได้ URL กลับมา
      List<String> imageUrls = List.of(_existingImageUrls); // รูปเดิมที่เก็บไว้
      if (_images.isNotEmpty) {
        setState(() => _savingText = 'กำลังอัปโหลดรูป...');
        final uploaded = await TankService.uploadImages(_images);
        imageUrls.addAll(uploaded);
      }

      if (!mounted) return;
      setState(() => _savingText = 'กำลังบันทึก...');

      final detail = _detailController.text.trim().isEmpty
          ? null
          : _detailController.text.trim();
      final capacity = double.tryParse(_capacityController.text.trim());
      final builtYear = int.tryParse(_builtYearController.text.trim());
      final caretaker = _caretakerController.text.trim().isEmpty
          ? null
          : _caretakerController.text.trim();
      final caretakerPhone = _caretakerPhoneController.text.trim().isEmpty
          ? null
          : _caretakerPhoneController.text.trim();

      // 2) บันทึกลง PostgreSQL ผ่าน Edge Function (ตรวจ role เจ้าหน้าที่ก่อน)
      final WaterTank tank;
      if (_isEdit) {
        tank = await TankService.updateTank(
          tankId: widget.tank!.id,
          name: _nameController.text.trim(),
          type: _selectedType!,
          village: _selectedVillage!,
          moo: _selectedMoo!,
          detail: detail,
          imageUrls: imageUrls,
          lat: _lat,
          lng: _lng,
          capacity: capacity,
          builtYear: builtYear,
          caretaker: caretaker,
          caretakerPhone: caretakerPhone,
        );
      } else {
        tank = await TankService.createTank(
          name: _nameController.text.trim(),
          type: _selectedType!,
          village: _selectedVillage!,
          moo: _selectedMoo!,
          detail: detail,
          imageUrls: imageUrls,
          lat: _lat,
          lng: _lng,
          capacity: capacity,
          builtYear: builtYear,
          caretaker: caretaker,
          caretakerPhone: caretakerPhone,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, tank); // ส่งกลับไปให้หน้ารายการ
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _savingText = '';
      });
      AppDialog.error(context, 'บันทึกไม่สำเร็จ');
    }
  }

  void _toast(String msg) {
    AppDialog.warn(context, msg);
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _stepTitle(1, 'ข้อมูลแทงค์น้ำ'),
                      const SizedBox(height: 18),
                      _label('ชื่อแทงค์'),
                      const SizedBox(height: 8),
                      _textField(
                        _nameController,
                        'กรอกชื่อแทงค์ เช่น แทงค์ประปาเหนือ',
                      ),
                      const SizedBox(height: 16),
                      _label('ประเภทประปา'),
                      const SizedBox(height: 8),
                      _dropdown<String>(
                        value: _selectedType,
                        hint: 'เลือกประเภทประปา',
                        items: kTankTypes,
                        itemLabel: (t) => t,
                        onChanged: (v) => setState(() => _selectedType = v),
                      ),
                      const SizedBox(height: 16),
                      _label('หมู่บ้าน'),
                      const SizedBox(height: 8),
                      // เจ้าหน้าที่หมู่บ้าน -> ล็อกหมู่ตัวเอง / เทศบาล-แอดมิน -> เลือกได้
                      _lockVillage
                          ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F0FD),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: AppColors.primaryLight),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.lock_outline,
                                      size: 18, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectedMoo != null
                                          ? villageLabelOfMoo(_selectedMoo!)
                                          : '-',
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textDark),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _dropdown<int>(
                              value: _selectedMoo,
                              hint: 'เลือกหมู่บ้าน',
                              items: kVillageMooMap.keys.toList(),
                              itemLabel: (moo) => villageLabelOfMoo(moo),
                              onChanged: (moo) => setState(() {
                                _selectedMoo = moo;
                                _selectedVillage = villageNameOfMoo(moo);
                              }),
                            ),
                      const SizedBox(height: 16),
                      // ===== ข้อมูลเพิ่มเติมของแทงค์ =====
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('ความจุ (ลิตร)'),
                                const SizedBox(height: 8),
                                _textField(_capacityController, 'เช่น 20000',
                                    keyboardType: TextInputType.number),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('ปีที่สร้าง (พ.ศ.)'),
                                const SizedBox(height: 8),
                                _textField(_builtYearController, 'เช่น 2560',
                                    keyboardType: TextInputType.number),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _label('ผู้ดูแล'),
                      const SizedBox(height: 8),
                      _textField(_caretakerController, 'ชื่อผู้ดูแลแทงค์'),
                      const SizedBox(height: 16),
                      _label('เบอร์ติดต่อผู้ดูแล'),
                      const SizedBox(height: 8),
                      _textField(_caretakerPhoneController, '08x-xxx-xxxx',
                          keyboardType: TextInputType.phone),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _label('รายละเอียด'),
                          const SizedBox(width: 6),
                          const Text(
                            '(แนะนำ)',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _textField(
                        _detailController,
                        'กรอกรายละเอียดของแทงค์น้ำ...\nเช่น ความจุ การใช้งาน หรือข้อมูลเพิ่มเติม',
                        maxLines: 4,
                      ),
                      const SizedBox(height: 28),
                      _stepTitle(2, 'รูปภาพแทงค์น้ำ'),
                      const SizedBox(height: 14),
                      _buildImagePicker(),
                      const SizedBox(height: 28),
                      _stepTitle(3, 'ตำแหน่งแทงค์น้ำ'),
                      const SizedBox(height: 14),
                      _label('ระบุตำแหน่งบนแผนที่'),
                      const SizedBox(height: 8),
                      _buildMapPicker(),
                      const SizedBox(height: 28),
                      _buildBottomButtons(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== หัวสีม่วง =====
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
          Expanded(
            child: Column(
              children: [
                Text(
                  _isEdit ? 'แก้ไขข้อมูลแทงค์น้ำ' : 'เพิ่มข้อมูลแทงค์น้ำ',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'กรอกข้อมูลแทงค์น้ำให้ครบถ้วน',
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

  // ===== หัวข้อแต่ละส่วน (วงกลมเลข + ชื่อ) =====
  Widget _stepTitle(int number, String title) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  // ===== กล่องเพิ่มรูปภาพ =====
  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // รูปทั้งหมด: รูปเดิมที่เคยอัปโหลด (URL) + รูปใหม่ที่เพิ่งเลือก (ไฟล์)
        if (_existingImageUrls.isNotEmpty || _images.isNotEmpty) ...[
          ImageGrid(
            urls: _existingImageUrls,
            files: _images,
            onRemove: (i) {
              setState(() {
                // index นับรูปเดิมก่อน แล้วต่อด้วยรูปใหม่
                if (i < _existingImageUrls.length) {
                  _existingImageUrls.removeAt(i);
                } else {
                  _images.removeAt(i - _existingImageUrls.length);
                }
              });
            },
          ),
          const SizedBox(height: 12),
        ],
        // ปุ่มเพิ่มรูป
        GestureDetector(
          onTap: _pickImages,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.45),
                width: 1.4,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFEAFD),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: AppColors.primary),
                ),
                const SizedBox(height: 10),
                const Text(
                  'เพิ่มรูปภาพ',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  (_existingImageUrls.length + _images.length) == 0
                      ? 'เพิ่มได้หลายรูป'
                      : 'มีรูปแล้ว ${_existingImageUrls.length + _images.length} รูป',
                  style: const TextStyle(
                      color: AppColors.textGrey, fontSize: 12),
                ),
                const Text(
                  'รูปแรกจะแสดงในรายการแทงค์',
                  style: TextStyle(color: AppColors.textGrey, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // รูปย่อ 1 รูป พร้อมปุ่มลบ
  // ===== เลือกรูปภาพ =====
  Future<void> _pickImages() async {
    final picker = ImagePicker();

    // ให้เลือกว่าจะถ่ายรูป หรือเลือกจากแกลเลอรี
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('ถ่ายรูป'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library,
                  color: AppColors.primary),
              title: const Text('เลือกจากแกลเลอรี'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      if (source == ImageSource.gallery) {
        // เลือกได้หลายรูป — imageQuality ย่อรูปให้เล็กลง ประหยัดเน็ต
        final picked = await picker.pickMultiImage(imageQuality: 70);
        if (picked.isNotEmpty) {
          final toAdd = <PickedImage>[];
          for (final x in picked) {
            toAdd.add(PickedImage(bytes: await x.readAsBytes(), name: x.name));
          }
          if (!mounted) return;
          setState(() => _images.addAll(toAdd));
        }
      } else {
        final picked =
            await picker.pickImage(source: source, imageQuality: 70);
        if (picked != null) {
          final bytes = await picked.readAsBytes();
          if (!mounted) return;
          setState(() => _images.add(PickedImage(bytes: bytes, name: picked.name)));
        }
      }
    } catch (e) {
      if (!mounted) return;
      AppDialog.error(context, 'เลือกรูปไม่สำเร็จ');
    }
  }

  // เปิดหน้าแผนที่ให้ปักหมุด
  Future<void> _openMapPicker() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initialLat: _lat,
          initialLng: _lng,
        ),
      ),
    );
    // ถ้าเลือกตำแหน่งมา ให้เก็บไว้
    if (result != null) {
      setState(() {
        _lat = result.latitude;
        _lng = result.longitude;
      });
    }
  }

  // ===== กล่องเลือกตำแหน่งบนแผนที่ =====
  Widget _buildMapPicker() {
    final hasPin = _lat != null && _lng != null;

    return GestureDetector(
      onTap: _openMapPicker,
      child: Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F1FD),
          borderRadius: BorderRadius.circular(14),
          border: hasPin
              ? Border.all(color: AppColors.primary, width: 1.4)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasPin ? Icons.location_on : Icons.add_location_alt,
              color: AppColors.primary,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              hasPin ? 'ปักหมุดแล้ว' : 'แตะเพื่อเลือกตำแหน่ง',
              style: TextStyle(
                color: hasPin ? AppColors.primary : AppColors.textGrey,
                fontSize: 13.5,
                fontWeight: hasPin ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (hasPin) ...[
              const SizedBox(height: 4),
              Text(
                '${_lat!.toStringAsFixed(6)}, ${_lng!.toStringAsFixed(6)}',
                style: const TextStyle(
                    color: AppColors.textGrey, fontSize: 11.5),
              ),
              const SizedBox(height: 2),
              const Text(
                'แตะอีกครั้งเพื่อแก้ไข',
                style: TextStyle(color: AppColors.textGrey, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ===== ปุ่มยกเลิก / บันทึก =====
  Widget _buildBottomButtons() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: () => Navigator.maybePop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'ยกเลิก',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _saving
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _savingText,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    )
                  : const Text(
                      'บันทึกข้อมูล',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  // ===== ชิ้นส่วนที่ใช้ซ้ำ =====
  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.bold,
        color: AppColors.textDark,
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textGrey, fontSize: 13.5),
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

  // dropdown ที่ใช้ได้กับทั้ง String และ int
  Widget _dropdown<T>({
    required T? value,
    required String hint,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
    bool enabled = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Text(hint,
              style: const TextStyle(color: AppColors.textGrey)),
          icon: const Icon(Icons.keyboard_arrow_down,
              color: AppColors.textGrey),
          items: items.map((i) {
            return DropdownMenuItem<T>(value: i, child: Text(itemLabel(i)));
          }).toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}