import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_toast.dart';
import '../widgets/app_dialog.dart';
import '../data/villages.dart';
import '../services/auth_service.dart';
import 'citizen_home_screen.dart';

// หน้ากรอกข้อมูลสมาชิกครั้งแรก (หลังเชื่อมบัญชี LINE แล้ว)
class LineRegisterScreen extends StatefulWidget {
  // ข้อมูลที่ได้จาก LINE ส่งต่อมาจากหน้าต้อนรับ
  final String lineUserId;
  final String displayName;
  final String? pictureUrl;

  const LineRegisterScreen({
    super.key,
    required this.lineUserId,
    required this.displayName,
    this.pictureUrl,
  });

  @override
  State<LineRegisterScreen> createState() => _LineRegisterScreenState();
}

class _LineRegisterScreenState extends State<LineRegisterScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _houseNoController = TextEditingController();

  String? _selectedTitle;
  String? _selectedVillage;
  bool _saving = false;

  final List<String> _titleOptions = ['นาย', 'นาง', 'นางสาว'];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _houseNoController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    // เช็คว่ากรอกครบไหม
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty) {
      AppDialog.warn(context, 'กรุณากรอกชื่อและนามสกุล');
      return;
    }
    if (_selectedVillage == null) {
      AppDialog.warn(context, 'กรุณาเลือกหมู่บ้าน');
      return;
    }

    if (_saving) return;
    setState(() => _saving = true);

    try {
      final result = await AuthService.registerNewUser(
        title: _selectedTitle,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        houseNo: _houseNoController.text.trim(),
        village: _selectedVillage == null
            ? null
            : villageWithMoo(_selectedVillage!),
        avatarUrl: widget.pictureUrl,
      );

      if (!mounted) return;

      // สมัครสำเร็จ -> เข้าหน้า Home (ได้ role citizen อัตโนมัติ)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CitizenHomeScreen(
            roles: rolesFromStrings(result.roles),
            profile: result.profile,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppDialog.error(context, 'สมัครไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPurpleHeader(),
              const SizedBox(height: 12),
              _buildWhiteCard(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPurpleHeader() {
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
                  'กรอกข้อมูลสมาชิก',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'กรอกข้อมูลครั้งแรกเพื่อเริ่มใช้งานระบบ',
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

  Widget _buildWhiteCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // รูปโปรไฟล์จาก LINE (ถ้ามี)
          Center(
            child: Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: const Color(0xFFEAE0FB),
                shape: BoxShape.circle,
                image: widget.pictureUrl != null
                    ? DecorationImage(
                        image: NetworkImage(widget.pictureUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: widget.pictureUrl == null
                  ? const Icon(Icons.person,
                      color: AppColors.primary, size: 34)
                  : null,
            ),
          ),
          const SizedBox(height: 14),
          const Center(
            child: Text(
              'ข้อมูลจาก LINE ถูกเชื่อมต่อแล้ว',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              widget.displayName.isNotEmpty
                  ? 'สวัสดี ${widget.displayName}'
                  : 'กรุณากรอกข้อมูลที่อยู่และชื่อให้ครบถ้วน',
              style: const TextStyle(
                  color: AppColors.textGrey, fontSize: 12.5),
            ),
          ),
          const SizedBox(height: 24),
          _label('คำนำหน้า'),
          const SizedBox(height: 8),
          _buildDropdown(
            value: _selectedTitle,
            hint: 'เลือกคำนำหน้า',
            options: _titleOptions,
            onChanged: (v) => setState(() => _selectedTitle = v),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('ชื่อ'),
                    const SizedBox(height: 8),
                    _textField(_firstNameController, 'ชื่อ'),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('นามสกุล'),
                    const SizedBox(height: 8),
                    _textField(_lastNameController, 'นามสกุล'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _label('บ้านเลขที่'),
          const SizedBox(height: 8),
          _textField(_houseNoController, 'กรอกบ้านเลขที่'),
          const SizedBox(height: 16),
          _label('หมู่บ้าน'),
          const SizedBox(height: 8),
          _buildDropdown(
            value: _selectedVillage,
            hint: 'เลือกหมู่บ้าน',
            options: kVillages,
            onChanged: (v) => setState(() {
              _selectedVillage = v;
            }),
          ),
          const SizedBox(height: 28),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(hint, style: const TextStyle(color: AppColors.textGrey)),
          icon: const Icon(Icons.keyboard_arrow_down,
              color: AppColors.textGrey),
          items: options.map((o) {
            return DropdownMenuItem<String>(value: o, child: Text(o));
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _textField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textGrey),
        filled: true,
        fillColor: const Color(0xFFFAFAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _saving ? null : _onSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _saving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Text(
                'บันทึกข้อมูล',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
      ),
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