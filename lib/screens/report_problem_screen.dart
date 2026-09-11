import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data/complaint.dart';
import '../data/picked_image.dart';
import '../data/water_tank.dart';
import '../services/complaint_service.dart';
import '../theme/app_colors.dart';
import '../widgets/image_gallery.dart';
import '../widgets/app_dialog.dart';
import 'tank_map_picker_screen.dart';

// หน้ากรอกรายละเอียดปัญหา (หลังเลือกแทงค์จากแผนที่แล้ว)
class ReportProblemScreen extends StatefulWidget {
  final WaterTank tank; // แทงค์ที่เลือกมาจากแผนที่

  const ReportProblemScreen({super.key, required this.tank});

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  final _detailController = TextEditingController();

  String? _selectedProblem; // ประเภทปัญหา
  final List<PickedImage> _images = []; // รูปที่แนบ
  static const int _maxImages = 4;

  double? _lat; // จุดที่มีปัญหา
  double? _lng;

  bool _sending = false;
  String _sendingText = '';

  // แทงค์ที่เลือก (เปลี่ยนได้ถ้ากดเปลี่ยนแทงค์)
  late WaterTank _tank;

  @override
  void initState() {
    super.initState();
    _tank = widget.tank;
    _lat = _tank.lat;
    _lng = _tank.lng;
  }

  // ===== เปลี่ยนแทงค์ =====
  // เปิดหน้าแผนที่เลือกแทงค์ใหม่ — ข้อมูลอื่น (ประเภท/รายละเอียด/รูป) คงเดิม
  Future<void> _changeTank() async {
    final picked = await Navigator.push<WaterTank>(
      context,
      MaterialPageRoute(builder: (_) => const TankMapPickerScreen()),
    );
    if (picked != null && mounted) {
      setState(() {
        _tank = picked;
        _lat = picked.lat;
        _lng = picked.lng;
      });
    }
  }

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    AppDialog.warn(context, msg);
  }

  // แถวสรุปข้อมูลในป๊อปอัปยืนยัน
  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textGrey, fontSize: 13.5)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  // ===== เลือกรูป =====
  Future<void> _pickImages() async {
    final picker = ImagePicker();

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
              leading:
                  const Icon(Icons.photo_library, color: AppColors.primary),
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
        final picked = await picker.pickMultiImage(imageQuality: 70);

        if (picked.isNotEmpty) {
          final remain = _maxImages - _images.length;

          if (remain <= 0) {
            _toast('สามารถแนบรูปได้สูงสุด $_maxImages รูป');
            return;
          }

          final toAdd = <PickedImage>[];
          for (final x in picked.take(remain)) {
            toAdd.add(PickedImage(bytes: await x.readAsBytes(), name: x.name));
          }
          setState(() => _images.addAll(toAdd));

          if (picked.length > remain) {
            _toast('สามารถแนบรูปได้สูงสุด $_maxImages รูป');
          }
        }
      } else {
        final picked =
            await picker.pickImage(
              source: source,
              imageQuality: 70,
            );

        if (picked != null) {
          if (_images.length >= _maxImages) {
            _toast('สามารถแนบรูปได้สูงสุด $_maxImages รูป');
            return;
          }

          final bytes = await picked.readAsBytes();
          setState(() => _images.add(PickedImage(bytes: bytes, name: picked.name)));
        }
      }
    } catch (e) {
      _toast('เลือกรูปไม่สำเร็จ: $e');
    }
    } 

  // กรอกครบพร้อมส่งไหม (ต้องเลือกประเภท + แนบรูปอย่างน้อย 1)
  bool get _canSend => _selectedProblem != null && _images.isNotEmpty;

  // ===== ส่งเรื่อง =====
  Future<void> _onSend() async {
    // ยังกรอกไม่ครบ -> บอกให้กรอก
    if (!_canSend) {
      if (_selectedProblem == null) {
        _toast('กรุณาเลือกประเภทปัญหา');
      } else {
        _toast('กรุณาแนบรูปภาพอย่างน้อย 1 รูป');
      }
      return;
    }

    // สรุปข้อมูลให้ตรวจก่อนส่ง
    final detail = _detailController.text.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ตรวจสอบข้อมูล'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('กรุณาตรวจสอบก่อนส่งเรื่อง',
                  style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
              const SizedBox(height: 12),
              _summaryRow('แทงค์', _tank.name),
              _summaryRow('ประเภทปัญหา', _selectedProblem!),
              _summaryRow('รายละเอียด', detail.isEmpty ? '-' : detail),
              const SizedBox(height: 4),
              const Text('รูปภาพ',
                  style:
                      TextStyle(color: AppColors.textGrey, fontSize: 13.5)),
              const SizedBox(height: 8),
              // แสดงรูปจริง (เลื่อนดูแนวนอน)
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => Navigator.push(
                      ctx,
                      MaterialPageRoute(
                        builder: (_) => ImageViewerScreen(
                          files: _images,
                          initialIndex: i,
                        ),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        _images[i].bytes,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('แก้ไข',
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
            child: const Text('ถูกต้อง ส่งเรื่อง'),
          ),
        ],
      ),
    );

    if (confirmed != true) return; // กดแก้ไข -> ไม่ส่ง

    if (_sending) return;
    setState(() {
      _sending = true;
      _sendingText = 'กำลังส่ง...';
    });

    try {
      // 1) อัปโหลดรูปก่อน (ถ้ามี)
      List<String> imageUrls = [];
      if (_images.isNotEmpty) {
        setState(() => _sendingText = 'กำลังอัปโหลดรูป...');
        imageUrls = await ComplaintService.uploadImages(_images);
      }

      if (!mounted) return;
      setState(() => _sendingText = 'กำลังส่งเรื่อง...');

      // 2) ส่งเรื่องเข้าระบบ
      await ComplaintService.createComplaint(
        tankId: _tank.id,
        problemType: _selectedProblem!,
        detail: _detailController.text.trim().isEmpty
            ? null
            : _detailController.text.trim(),
        imageUrls: imageUrls,
        lat: _lat,
        lng: _lng,
      );

      if (!mounted) return;
      _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sendingText = '';
      });
      final msg = e.toString().replaceFirst('Exception: ', '');
      // ถ้าเป็นเรื่องแจ้งซ้ำ โชว์ dialog ชัดๆ
      if (msg.contains('กำลังดำเนินการ')) {
        _showBlockedDialog(msg);
      } else {
        _toast('ส่งเรื่องไม่สำเร็จ: $msg');
      }
    }
  }

  // แจ้งเตือนว่าแทงค์นี้มีเรื่องค้างอยู่ แจ้งซ้ำไม่ได้
  void _showBlockedDialog(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF0DA),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.info_outline,
                  color: Color(0xFFE8923A), size: 32),
            ),
            const SizedBox(height: 14),
            const Text('แจ้งซ้ำไม่ได้',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark)),
            const SizedBox(height: 8),
            Text(msg,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textGrey, fontSize: 13)),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context); // กลับหน้าเลือกแทงค์
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('เข้าใจแล้ว',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== แจ้งสำเร็จ =====
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: const BoxDecoration(
                color: Color(0xFFD9F2E3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check,
                  color: Color(0xFF5CB888), size: 34),
            ),
            const SizedBox(height: 16),
            const Text(
              'ส่งเรื่องเรียบร้อย',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'เจ้าหน้าที่จะตรวจสอบและดำเนินการต่อไป\nติดตามสถานะได้ที่เมนู "ประวัติแจ้งปัญหา"',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textGrey, fontSize: 13),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx); // ปิด dialog
                  Navigator.pop(context, true); // กลับหน้าหลัก
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('เสร็จสิ้น',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
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
                      _stepTitle(1, 'แทงค์ที่แจ้งปัญหา'),
                      const SizedBox(height: 12),
                      _buildTankCard(),
                      const SizedBox(height: 26),
                      _stepTitle(2, 'รายละเอียดปัญหา'),
                      const SizedBox(height: 16),
                      _label('ประเภทปัญหา'),
                      const SizedBox(height: 8),
                      _buildProblemDropdown(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _label('รายละเอียดเพิ่มเติม'),
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
                      _buildDetailField(),
                      const SizedBox(height: 26),
                      _stepTitle(3, 'รูปภาพปัญหา'),
                      const SizedBox(height: 12),
                      _buildImagePicker(),
                      const SizedBox(height: 26),
                      _stepTitle(4, 'จุดที่พบปัญหา'),
                      const SizedBox(height: 12),
                      _buildMapPicker(),
                      const SizedBox(height: 26),
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
          const Expanded(
            child: Column(
              children: [
                Text(
                  'แจ้งปัญหา',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'กรอกรายละเอียดให้ครบถ้วน',
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

  // ===== การ์ดแทงค์ที่เลือก (แก้ไม่ได้) =====
  Widget _buildTankCard() {
    final tank = _tank;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5FE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _tankThumb(tank),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tank.name,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ประเภท : ${tank.type}',
                  style: const TextStyle(
                      color: AppColors.textGrey, fontSize: 12.5),
                ),
                const SizedBox(height: 2),
                Text(
                  'หมู่ ${tank.moo} ${tank.village}',
                  style: const TextStyle(
                      color: AppColors.textGrey, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tankThumb(WaterTank tank) {
    const double size = 62;
    if (tank.imageUrls.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFF2F4FB),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.water_drop, color: Color(0xFF4A90E2)),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        tank.imageUrls.first,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: const Color(0xFFF2F4FB),
          child: const Icon(Icons.broken_image, color: AppColors.textGrey),
        ),
      ),
    );
  }

  // ===== dropdown ประเภทปัญหา =====
  Widget _buildProblemDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedProblem,
          isExpanded: true,
          hint: const Text('เลือกประเภทปัญหา',
              style: TextStyle(color: AppColors.textGrey)),
          icon: const Icon(Icons.keyboard_arrow_down,
              color: AppColors.textGrey),
          items: kProblemTypes.map((p) {
            return DropdownMenuItem<String>(value: p, child: Text(p));
          }).toList(),
          onChanged: (v) => setState(() => _selectedProblem = v),
        ),
      ),
    );
  }

  Widget _buildDetailField() {
    return TextField(
      controller: _detailController,
      maxLines: 4,
      decoration: InputDecoration(
        hintText: 'อธิบายปัญหาที่พบ...\nเช่น น้ำไม่ไหลตั้งแต่เมื่อวาน หรือ ท่อรั่วหน้าบ้าน',
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

  // ===== รูปภาพ =====
  Widget _buildImagePicker() {
    final isFull = _images.length >= _maxImages;
    final activeColor = AppColors.primary;
    final disabledColor = Colors.grey.shade400;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_images.isNotEmpty) ...[
          ImageGrid(
            files: _images,
            onRemove: (i) => setState(() => _images.removeAt(i)),
          ),
          const SizedBox(height: 12),
        ],
        GestureDetector(
          onTap: isFull ? null : _pickImages,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22),
            decoration: BoxDecoration(
              color: isFull
                  ? const Color(0xFFF5F5F7)
                  : const Color(0xFFFAFAFF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isFull
                    ? Colors.grey.shade300
                    : activeColor.withValues(alpha: 0.45),
                width: 1.4,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isFull
                        ? Colors.grey.shade200
                        : const Color(0xFFEFEAFD),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isFull ? Icons.check : Icons.add_a_photo,
                    color: isFull ? disabledColor : activeColor,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isFull ? 'เพิ่มรูปครบแล้ว' : 'เพิ่มรูปภาพ',
                  style: TextStyle(
                    color: isFull ? disabledColor : activeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  isFull
                      ? 'ครบ $_maxImages/$_maxImages รูปแล้ว'
                      : _images.isEmpty
                          ? 'เพิ่มได้สูงสุด $_maxImages รูป'
                          : 'เลือกแล้ว ${_images.length}/$_maxImages รูป',
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===== ปักหมุดจุดที่มีปัญหา =====
  Widget _buildMapPicker() {
    final hasPin = _lat != null && _lng != null;

    // แตะเพื่อเปลี่ยนแทงค์ (ข้อมูลอื่นคงเดิม)
    return GestureDetector(
      onTap: _sending ? null : _changeTank,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F1FD),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary, width: 1.4),
        ),
        child: Column(
        children: [
          const Icon(Icons.location_on, color: AppColors.primary, size: 30),
          const SizedBox(height: 8),
          Text(
            'ใช้ตำแหน่งของ ${_tank.name}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (hasPin) ...[
            const SizedBox(height: 4),
            Text(
              '${_lat!.toStringAsFixed(6)}, ${_lng!.toStringAsFixed(6)}',
              style: const TextStyle(
                  color: AppColors.textGrey, fontSize: 11.5),
            ),
          ] else ...[
            const SizedBox(height: 4),
            const Text(
              'แทงค์นี้ยังไม่ได้ระบุตำแหน่งบนแผนที่',
              style: TextStyle(color: AppColors.textGrey, fontSize: 11.5),
            ),
          ],
            const SizedBox(height: 10),
            // ป้ายบอกว่าแตะเพื่อเปลี่ยนแทงค์
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swap_horiz, color: Colors.white, size: 15),
                  SizedBox(width: 5),
                  Text('แตะเพื่อเปลี่ยนแทงค์',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== ปุ่มล่าง =====
  Widget _buildBottomButtons() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: _sending ? null : () => Navigator.maybePop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('ยกเลิก',
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
              onPressed: _sending ? null : _onSend,
              style: ElevatedButton.styleFrom(
                // ยังกรอกไม่ครบ -> ปุ่มสีเทา (แต่ยังกดได้ เพื่อบอกให้กรอก)
                backgroundColor:
                    _canSend ? AppColors.primary : const Color(0xFFBFBFCB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _sending
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
                        Text(_sendingText,
                            style: const TextStyle(fontSize: 13)),
                      ],
                    )
                  : const Text('ส่งเรื่อง',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

  // ===== ชิ้นส่วนที่ใช้ซ้ำ =====
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
            fontSize: 16.5,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

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
}