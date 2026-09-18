import 'package:flutter/material.dart';
import '../data/villages.dart';
import '../services/admin_service.dart';
import '../services/session.dart';
import '../theme/app_colors.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_toast.dart';
import 'addon_features_screen.dart';

// หน้าจัดการผู้ใช้ (เฉพาะ admin)
// ค้นหาแยก คำนำหน้า/ชื่อ/สกุล + แบ่งหน้าทีละ 10 คน
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  String? _title; // คำนำหน้าที่เลือก (null = ทั้งหมด)
  String? _role; // ตำแหน่งที่เลือก (null = ทั้งหมด)
  int _page = 0; // หน้าปัจจุบัน (เริ่มที่ 0)

  UserPage? _result; // ผลลัพธ์หน้าปัจจุบัน
  bool _loading = false; // เริ่มต้นไม่โหลด
  bool _hasSearched = false; // เคยกดค้นหาแล้วหรือยัง
  String? _error;

  static const List<String> _titleOptions = ['นาย', 'นาง', 'นางสาว'];

  static const Map<String, String> _assignableRoles = {
    'officer': 'เจ้าหน้าที่',
    'village_head': 'ผู้ใหญ่บ้าน',
    'palad': 'เจ้าหน้าที่เทศบาล',
  };

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasSearched = true;
      _error = null;
    });
    try {
      final result = await AdminService.listUsers(
        title: _title,
        role: _role,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        page: _page,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'โหลดข้อมูลไม่สำเร็จ: $e';
        _loading = false;
      });
    }
  }

  // กดปุ่มค้นหา -> กลับหน้าแรกแล้วค้น
  void _onSearch() {
    FocusScope.of(context).unfocus(); // ปิดคีย์บอร์ด
    setState(() => _page = 0);
    _load();
  }

  // ล้างเงื่อนไขค้นหาทั้งหมด กลับเป็นหน้าว่าง (ไม่ยิง server)
  void _onClear() {
    FocusScope.of(context).unfocus();
    setState(() {
      _title = null;
      _role = null;
      _firstNameController.clear();
      _lastNameController.clear();
      _page = 0;
      _result = null;
      _hasSearched = false;
      _error = null;
    });
  }

  void _goPage(int page) {
    setState(() => _page = page);
    _load();
  }

  void _openRoleSheet(ManagedUser user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RoleSheet(
        user: user,
        assignableRoles: _assignableRoles,
        onChanged: _load,
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
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
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
                    _buildSearchFields(),
                    const SizedBox(height: 14),
                    _buildResultHeader(),
                    const SizedBox(height: 8),
                    Expanded(child: _buildList()),
                    _buildPager(),
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
                  'จัดการผู้ใช้',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'แต่งตั้งสิทธิ์ให้ผู้ใช้งาน',
                  style: TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddonFeaturesScreen()),
            ),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_open, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchFields() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 110, child: _buildTitleDropdown()),
            const SizedBox(width: 10),
            Expanded(child: _buildTextField(_firstNameController, 'ชื่อ')),
          ],
        ),
        const SizedBox(height: 10),
        _buildTextField(_lastNameController, 'นามสกุล'),
        const SizedBox(height: 10),
        _buildRoleDropdown(),
        const SizedBox(height: 12),
        Row(
          children: [
            // ปุ่มล้าง
            SizedBox(
              height: 46,
              child: OutlinedButton(
                onPressed: _loading ? null : _onClear,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textGrey,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('ล้าง'),
              ),
            ),
            const SizedBox(width: 10),
            // ปุ่มค้นหา
            Expanded(
              child: SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _onSearch,
                  icon: const Icon(Icons.search, size: 20),
                  label: const Text('ค้นหา',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleDropdown() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _role,
          isExpanded: true,
          hint: const Text('ตำแหน่ง',
              style: TextStyle(color: AppColors.textGrey, fontSize: 13.5)),
          icon: const Icon(Icons.keyboard_arrow_down,
              color: AppColors.textGrey),
          items: [
            const DropdownMenuItem<String?>(
                value: null, child: Text('ทุกตำแหน่ง')),
            ..._assignableRoles.entries.map(
              (e) => DropdownMenuItem<String?>(
                  value: e.key, child: Text(e.value)),
            ),
          ],
          onChanged: (v) => setState(() => _role = v),
        ),
      ),
    );
  }

  Widget _buildTitleDropdown() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _title,
          isExpanded: true,
          hint: const Text('คำนำหน้า',
              style: TextStyle(color: AppColors.textGrey, fontSize: 13.5)),
          icon: const Icon(Icons.keyboard_arrow_down,
              color: AppColors.textGrey),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('ทั้งหมด')),
            ..._titleOptions.map(
                (t) => DropdownMenuItem<String?>(value: t, child: Text(t))),
          ],
          onChanged: (v) => setState(() => _title = v),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _onSearch(), // กด Enter บนคีย์บอร์ดก็ค้นได้
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textGrey, fontSize: 13.5),
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
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildResultHeader() {
    if (!_hasSearched) return const SizedBox.shrink();
    final total = _result?.total ?? 0;
    return Text(
      'พบ $total คน',
      style: const TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.bold,
        color: AppColors.textDark,
      ),
    );
  }

  Widget _buildList() {
    // ยังไม่เคยกดค้นหา -> หน้าว่าง ชวนให้ค้น
    if (!_hasSearched) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search, color: AppColors.textGrey, size: 46),
            SizedBox(height: 12),
            Text(
              'ค้นหาผู้ใช้เพื่อจัดการสิทธิ์',
              style: TextStyle(color: AppColors.textGrey, fontSize: 14),
            ),
            SizedBox(height: 4),
            Text(
              'เลือกคำนำหน้า หรือพิมพ์ชื่อ/นามสกุล แล้วกดค้นหา',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textGrey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
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
                  style: const TextStyle(
                      color: AppColors.textGrey, fontSize: 13)),
            ),
            TextButton(onPressed: _load, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }

    final users = _result?.users ?? [];
    if (users.isEmpty) {
      return const Center(
        child: Text('ไม่พบผู้ใช้ที่ตรงกับเงื่อนไข',
            style: TextStyle(color: AppColors.textGrey)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _userCard(users[i]),
    );
  }

  Widget _buildPager() {
    final result = _result;
    if (result == null || result.totalPages <= 1) {
      return const SizedBox(height: 8);
    }

    final canPrev = _page > 0;
    final canNext = _page < result.totalPages - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _pagerButton(
            icon: Icons.chevron_left,
            enabled: canPrev,
            onTap: () => _goPage(_page - 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              'หน้า ${_page + 1} / ${result.totalPages}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
          _pagerButton(
            icon: Icons.chevron_right,
            enabled: canNext,
            onTap: () => _goPage(_page + 1),
          ),
        ],
      ),
    );
  }

  Widget _pagerButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: enabled ? AppColors.primary : const Color(0xFFEDEDF2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon,
            color: enabled ? Colors.white : AppColors.textGrey),
      ),
    );
  }

  Widget _userCard(ManagedUser user) {
    final specialRoles = user.roles
        .where((r) => _assignableRoles.containsKey(r))
        .map((r) {
          final label = _assignableRoles[r]!;
          // ผู้ใหญ่บ้าน/เจ้าหน้าที่ -> ต่อท้ายด้วยเลขหมู่ที่ดูแล กันงงว่าคนไหนดูแลหมู่ไหน
          final village = r == 'village_head'
              ? user.headVillage
              : r == 'officer'
                  ? user.officerVillage
                  : null;
          final moo = mooFromLabel(village);
          return moo != null ? '$label หมู่ $moo' : label;
        })
        .toList();
    final isAdmin = user.roles.contains('admin');

    return GestureDetector(
      onTap: () => _openRoleSheet(user),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFEAE0FB),
                shape: BoxShape.circle,
                image: (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                    ? DecorationImage(
                        image: NetworkImage(user.avatarUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                  ? const Icon(Icons.person, color: AppColors.primary)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      if (isAdmin) ...[
                        const SizedBox(width: 6),
                        _roleTag('ผู้ดูแล', const Color(0xFF7C5CFC)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.village ?? '-',
                    style: const TextStyle(
                        color: AppColors.textGrey, fontSize: 12.5),
                  ),
                  if (specialRoles.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: specialRoles
                          .map((r) => _roleTag(r, const Color(0xFF5CB888)))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }

  Widget _roleTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ===== แผงจัดการ role ของผู้ใช้ 1 คน =====
class _RoleSheet extends StatefulWidget {
  final ManagedUser user;
  final Map<String, String> assignableRoles;
  final VoidCallback onChanged;

  const _RoleSheet({
    required this.user,
    required this.assignableRoles,
    required this.onChanged,
  });

  @override
  State<_RoleSheet> createState() => _RoleSheetState();
}

class _RoleSheetState extends State<_RoleSheet> {
  late Set<String> _roles;
  String? _busyRole;
  String? _headVillage; // หมู่บ้านที่ผู้ใหญ่บ้านดูแล
  String? _officerVillage; // หมู่บ้านที่เจ้าหน้าที่ดูแล
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _roles = widget.user.roles.toSet();
    _headVillage = widget.user.headVillage;
    _officerVillage = widget.user.officerVillage;
  }

  // เปลี่ยนหมู่บ้านของ role ที่เปิดอยู่แล้ว (ตั้ง role ซ้ำด้วยหมู่บ้านใหม่)
  // เรียก addRole พร้อมถามยืนยันถ้าหมู่บ้านมีคนดูแลอยู่แล้ว
  // คืน true = สำเร็จ, false = ยกเลิก/ล้มเหลว
  Future<bool> _addRoleWithConfirm(
      String role, String? village) async {
    final roleLabel = role == 'village_head' ? 'ผู้ใหญ่บ้าน' : 'เจ้าหน้าที่';
    // ชื่อคนใหม่ (คนที่กำลังจะตั้ง)
    final newName = [
      widget.user.title ?? '',
      widget.user.firstName,
      widget.user.lastName,
    ].where((s) => s.isNotEmpty).join(' ');
    try {
      var result =
          await AdminService.addRole(widget.user.id, role, village: village);

      // หมู่บ้านมีคนดูแลอยู่แล้ว -> ถามยืนยันเปลี่ยนตัว
      if (result.needConfirm) {
        if (!mounted) return false;
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Text('เปลี่ยน$roleLabel'),
            content: Text(
              'หมู่บ้าน "$village" มี$roleLabelอยู่แล้วคือ '
              '${result.currentHolder}\n\n'
              'ต้องการเปลี่ยนเป็น $newName แทนใช่หรือไม่?',
              style: const TextStyle(fontSize: 14, height: 1.5),
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
                child: const Text('เปลี่ยน'),
              ),
            ],
          ),
        );
        if (ok != true) return false;
        // ยืนยัน -> เรียกซ้ำแบบ force
        result = await AdminService.addRole(widget.user.id, role,
            village: village, force: true);
      }
      return true;
    } catch (e) {
      if (mounted) AppDialog.error(context, 'ทำรายการไม่สำเร็จ');
      return false;
    }
  }

  Future<void> _changeVillage(String role) async {
    final village = await _pickVillage();
    if (village == null) return;
    setState(() => _busyRole = role);
    final ok = await _addRoleWithConfirm(role, village);
    if (ok) {
      setState(() {
        if (role == 'village_head') _headVillage = village;
        if (role == 'officer') _officerVillage = village;
      });
      widget.onChanged();
    }
    if (mounted) setState(() => _busyRole = null);
  }

  Future<void> _toggle(String role, bool add) async {
    // เปิดสิทธิ์ผู้ใหญ่บ้าน หรือ เจ้าหน้าที่ -> ต้องเลือกหมู่บ้านก่อน
    String? pickedVillage;
    if ((role == 'village_head' || role == 'officer') && add) {
      final village = await _pickVillage();
      if (village == null) return; // ยกเลิก
      pickedVillage = village;
      if (role == 'village_head') _headVillage = village;
      if (role == 'officer') _officerVillage = village;
    }

    setState(() => _busyRole = role);
    try {
      if (add) {
        final ok = await _addRoleWithConfirm(
          role,
          (role == 'village_head' || role == 'officer')
              ? pickedVillage
              : null,
        );
        if (ok) {
          setState(() => _roles.add(role));
        } else {
          // ยกเลิก -> คืนค่า village state ที่ตั้งไว้ล่วงหน้า
          setState(() {
            if (role == 'village_head') _headVillage = null;
            if (role == 'officer') _officerVillage = null;
          });
        }
      } else {
        await AdminService.removeRole(widget.user.id, role);
        setState(() {
          _roles.remove(role);
          if (role == 'village_head') _headVillage = null;
          if (role == 'officer') _officerVillage = null;
        });
      }
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        AppDialog.error(context, 'ทำรายการไม่สำเร็จ');
      }
    } finally {
      if (mounted) setState(() => _busyRole = null);
    }
  }

  // เลือกหมู่บ้านที่ผู้ใหญ่บ้านดูแล
  Future<String?> _pickVillage() async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 4),
              child: Text('เลือกหมู่บ้านที่ดูแล',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text('ผู้ใหญ่บ้านจะเห็นเฉพาะเรื่องของหมู่บ้านนี้',
                  style: TextStyle(color: AppColors.textGrey, fontSize: 12.5)),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: kVillagesWithMoo.map((label) {
                  return ListTile(
                    leading: const Icon(Icons.home_work_outlined,
                        color: AppColors.primary),
                    title: Text(label),
                    onTap: () => Navigator.pop(ctx, label),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ลบบัญชีผู้ใช้ — ต้องกรอกรหัสยืนยันก่อน (กันกดพลาด)
  // ลบแล้วย้อนกลับไม่ได้ ถ้าคนนี้เข้า LINE อีกครั้งจะต้องสมัครสมาชิกใหม่
  // (ถ้ามีเรื่องแจ้งซ่อมผูกอยู่ จะล้างข้อมูลส่วนตัวแทนการลบทั้งบัญชี — ดู admin_service.dart)
  Future<void> _confirmDelete() async {
    final codeCtrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ลบบัญชีผู้ใช้'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ลบ ${widget.user.fullName} ออกจากระบบ (สิทธิ์และข้อมูลโปรไฟล์)\n'
              'ย้อนกลับไม่ได้ — ถ้าคนนี้เข้าสู่ระบบด้วย LINE อีกครั้ง '
              'จะต้องสมัครสมาชิกใหม่ทั้งหมด\n\n'
              'ถ้าคนนี้เคยแจ้งซ่อมไว้ ระบบจะลบแค่ข้อมูลส่วนตัวออก '
              '(ชื่อจะกลายเป็น "ผู้ใช้ที่ถูกลบ") '
              'แต่เรื่องแจ้งซ่อมเดิมจะยังอยู่ ไม่ถูกลบไปด้วย',
              style: const TextStyle(fontSize: 13.5, height: 1.5),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: codeCtrl,
              obscureText: true,
              autofocus: true,
              onSubmitted: (v) => Navigator.pop(ctx, v),
              decoration: const InputDecoration(
                labelText: 'รหัสยืนยัน',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก',
                style: TextStyle(color: AppColors.textGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, codeCtrl.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD9534F),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('ลบบัญชี'),
          ),
        ],
      ),
    );
    codeCtrl.dispose();

    if (code == null || code.isEmpty || !mounted) return;

    setState(() => _deleting = true);
    try {
      final anonymized = await AdminService.deleteUser(widget.user.id, code);
      if (!mounted) return;
      AppToast.show(
        context,
        anonymized
            ? 'มีเรื่องแจ้งซ่อมผูกอยู่ ลบได้แค่ข้อมูลส่วนตัว'
            : 'ลบบัญชีแล้ว',
      );
      widget.onChanged();
      Navigator.pop(context); // ปิดแผงนี้ กลับไปหน้ารายชื่อ
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      AppDialog.error(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.user.fullName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.user.village ?? '-',
            style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
          ),
          const SizedBox(height: 20),
          const Text(
            'สิทธิ์การใช้งาน',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'ทุกคนเป็นประชาชนโดยอัตโนมัติ เปิดสิทธิ์เพิ่มได้ตามต้องการ',
            style: TextStyle(color: AppColors.textGrey, fontSize: 12),
          ),
          const SizedBox(height: 14),
          ...widget.assignableRoles.entries.map((e) {
            final role = e.key;
            final label = e.value;
            final on = _roles.contains(role);
            final busy = _busyRole == role;

            // ข้อความหมู่บ้านที่ดูแล (แยกตาม role)
            String? subtitle;
            if (on && role == 'village_head') subtitle = _headVillage;
            if (on && role == 'officer') subtitle = _officerVillage;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textDark,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          GestureDetector(
                            onTap: busy ? null : () => _changeVillage(role),
                            child: Row(
                              children: [
                                Text('ดูแล: $subtitle',
                                    style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 12)),
                                const SizedBox(width: 4),
                                const Icon(Icons.edit,
                                    size: 13, color: AppColors.primary),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (busy)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  else
                    Switch(
                      value: on,
                      activeTrackColor: AppColors.primary,
                      onChanged: (v) => _toggle(role, v),
                    ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
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
          if (widget.user.id != AppSession.profileId &&
              !widget.user.roles.contains('admin')) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _deleting ? null : _confirmDelete,
                icon: _deleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.2, color: Color(0xFFD9534F)))
                    : const Icon(Icons.delete_outline,
                        color: Color(0xFFD9534F)),
                label: Text(_deleting ? 'กำลังลบ...' : 'ลบบัญชีผู้ใช้',
                    style: const TextStyle(
                        color: Color(0xFFD9534F),
                        fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFD9534F)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}