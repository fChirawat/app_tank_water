import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_toast.dart';
import '../services/auth_service.dart';
import 'welcome_screen.dart';
import 'water_tank_list_screen.dart';
import 'tank_map_picker_screen.dart';
import 'report_problem_screen.dart';
import 'admin_users_screen.dart';
import 'complaint_list_screen.dart';
import 'tank_status_screen.dart';
import 'my_reports_screen.dart';
import 'repair_status_screen.dart';
import 'village_head_receive_screen.dart';
import 'budget_approve_screen.dart';
import 'palad_list_screen.dart';
import 'palad_dashboard_screen.dart';
import 'village_head_dashboard_screen.dart';
import 'announcement_create_screen.dart';
import 'announcement_list_screen.dart';
import '../data/announcement.dart';
import '../services/announcement_service.dart';
import '../services/complaint_service.dart';
import '../data/water_tank.dart';
import '../services/push_service.dart';

// ===== role ในระบบ =====
// ทุกคนมี citizen (ประชาชน) เป็นพื้นฐาน role อื่นเพิ่มทีหลังได้
enum UserRole { citizen, officer, villageHead, palad, admin }

// ===== ข้อมูลของเมนู 1 อัน =====
class MenuItemData {
  final IconData icon;
  final Color circleColor; // สีวงกลมพาสเทล
  final Color iconColor; // สีไอคอน
  final String label;
  const MenuItemData({
    required this.icon,
    required this.circleColor,
    required this.iconColor,
    required this.label,
  });
}

// ===== เมนูของแต่ละ role (อ้างอิงจาก diagram) =====
// อยากเพิ่ม/แก้เมนูของ role ไหน แก้ตรงนี้ที่เดียว
final Map<UserRole, List<MenuItemData>> _roleMenus = {
  // ประชาชน — ทุกคนมี
  UserRole.citizen: const [
    MenuItemData(
      icon: Icons.water_drop,
      circleColor: Color(0xFFDCEBFF),
      iconColor: Color(0xFF4A90E2),
      label: 'สถานะประปา',
    ),
    MenuItemData(
      icon: Icons.water_damage,
      circleColor: Color(0xFFEAE0FB),
      iconColor: AppColors.primary,
      label: 'ข้อมูลแทงค์น้ำ',
    ),
    MenuItemData(
      icon: Icons.history,
      circleColor: Color(0xFFD9F2E3),
      iconColor: Color(0xFF5CB888),
      label: 'ประวัติแจ้งปัญหา',
    ),
  ],
  // เจ้าหน้าที่ — เมนูนี้จะเพิ่มต่อท้ายเมนูประชาชน
  UserRole.officer: const [
    MenuItemData(
      icon: Icons.assignment,
      circleColor: Color(0xFFFFE9D6),
      iconColor: Color(0xFFE8923A),
      label: 'รับเรื่องแจ้งซ่อม',
    ),
    MenuItemData(
      icon: Icons.build,
      circleColor: Color(0xFFD6F0EE),
      iconColor: Color(0xFF3FA7A0),
      label: 'อัปเดตสถานะการซ่อม',
    ),
    MenuItemData(
      icon: Icons.campaign,
      circleColor: Color(0xFFFFE4EF),
      iconColor: Color(0xFFD84A85),
      label: 'สร้างประกาศ',
    ),
    MenuItemData(
      icon: Icons.dashboard,
      circleColor: Color(0xFFEAE0FB),
      iconColor: AppColors.primary,
      label: 'Dashboard',
    ),
    // เมนูอื่นของเจ้าหน้าที่ (ตาม diagram) รอ Figma แล้วค่อยเพิ่มที่นี่ เช่น:
    // จัดการข้อมูลประปา
  ],
  // ผู้ใหญ่บ้าน
  UserRole.villageHead: const [
    MenuItemData(
      icon: Icons.move_to_inbox,
      circleColor: Color(0xFFFFE9D6),
      iconColor: Color(0xFFE8923A),
      label: 'รับเรื่องจากเจ้าหน้าที่',
    ),
    MenuItemData(
      icon: Icons.verified,
      circleColor: Color(0xFFD9F2E3),
      iconColor: Color(0xFF5CB888),
      label: 'อนุมัติงบประมาณ',
    ),
    MenuItemData(
      icon: Icons.dashboard,
      circleColor: Color(0xFFEAE0FB),
      iconColor: AppColors.primary,
      label: 'Dashboard',
    ),
  ],
  // ปลัด
  UserRole.palad: const [
    MenuItemData(
      icon: Icons.move_to_inbox,
      circleColor: Color(0xFFFFE9D6),
      iconColor: Color(0xFFE8923A),
      label: 'รับเรื่องจากผู้ใหญ่บ้าน',
    ),
    MenuItemData(
      icon: Icons.account_balance_wallet,
      circleColor: Color(0xFFD9F2E3),
      iconColor: Color(0xFF5CB888),
      label: 'สมทบงบประมาณ',
    ),
    MenuItemData(
      icon: Icons.dashboard,
      circleColor: Color(0xFFEAE0FB),
      iconColor: AppColors.primary,
      label: 'Dashboard',
    ),
    MenuItemData(
      icon: Icons.campaign,
      circleColor: Color(0xFFFFE4EF),
      iconColor: Color(0xFFD84A85),
      label: 'สร้างประกาศ',
    ),
  ],
  // ผู้ดูแลระบบ (ดูแลระบบเท่านั้น ไม่ใช่คนออกประกาศ)
  UserRole.admin: const [
    MenuItemData(
      icon: Icons.manage_accounts,
      circleColor: Color(0xFFEAE0FB),
      iconColor: AppColors.primary,
      label: 'จัดการผู้ใช้',
    ),
  ],
};

// แปลงชื่อ role ที่ได้จากฐานข้อมูล (เช่น 'citizen') ให้เป็น UserRole
List<UserRole> rolesFromStrings(List<String> names) {
  final result = <UserRole>[];
  for (final name in names) {
    switch (name) {
      case 'citizen':
        result.add(UserRole.citizen);
      case 'officer':
        result.add(UserRole.officer);
      case 'village_head':
        result.add(UserRole.villageHead);
      case 'palad':
        result.add(UserRole.palad);
      case 'admin':
        result.add(UserRole.admin);
    }
  }
  // กันกรณีไม่มี role เลย ให้เป็นประชาชนไว้ก่อน
  return result.isEmpty ? [UserRole.citizen] : result;
}

// รวมเมนูจากทุก role ที่ผู้ใช้มี (ตัดเมนูชื่อซ้ำออก เช่น Dashboard)
List<MenuItemData> menusForRoles(List<UserRole> roles) {
  final seen = <String>{};
  final result = <MenuItemData>[];
  for (final role in roles) {
    for (final item in _roleMenus[role] ?? const <MenuItemData>[]) {
      if (seen.add(item.label)) result.add(item);
    }
  }
  return result;
}

// หน้าแรก (Home) — เมนูขึ้นตาม role ของผู้ใช้
class CitizenHomeScreen extends StatefulWidget {
  // role ของผู้ใช้คนนี้ (ดึงมาจากฐานข้อมูล)
  final List<UserRole> roles;

  // ข้อมูลโปรไฟล์จากฐานข้อมูล (ชื่อ, นามสกุล, รูปจาก LINE)
  final Map<String, dynamic>? profile;

  const CitizenHomeScreen({
    super.key,
    this.roles = const [UserRole.citizen],
    this.profile,
  });

  @override
  State<CitizenHomeScreen> createState() => _CitizenHomeScreenState();
}

class _CitizenHomeScreenState extends State<CitizenHomeScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0; // แท็บที่เลือกในแถบเมนูล่าง

  // ประกาศ
  List<Announcement> _announcements = [];
  bool _loadingAnn = true;

  // จำนวนงานค้างของแต่ละเมนู (badge)
  Map<String, int> _menuCounts = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _loadAnnouncements();
    _loadMenuCounts();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNotificationPermission();
    });
  }
  
  Future<void> _checkNotificationPermission() async {
    final allowed = await PushService.isNotificationAllowed();

    if (allowed || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.notifications_active,
                color: AppColors.primary,
              ),
              SizedBox(width: 10),
              Text('เปิดการแจ้งเตือน'),
            ],
          ),
          content: const Text(
            'กรุณาอนุญาตการแจ้งเตือน เพื่อรับประกาศและติดตามสถานะงานประปา',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
              },
              child: const Text('ไว้ภายหลัง'),
            ),
            ElevatedButton(
              onPressed: () async {
                final allowed =
                    await PushService.requestNotificationPermission();

                if (!ctx.mounted) return;

                Navigator.pop(ctx);

                if (allowed) {
                  // ได้รับอนุญาตแล้ว
                  await PushService.syncToken();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('อนุญาต'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // แอปกลับมา foreground -> โหลด badge ใหม่
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadMenuCounts();
      _loadAnnouncements();
    }
  }

  // โหลดข้อมูลทั้งหมดใหม่ (ใช้กับ pull to refresh)
  Future<void> _refreshAll() async {
    await Future.wait([
      _loadMenuCounts(),
      _loadAnnouncements(),
    ]);
  }

  Future<void> _loadMenuCounts() async {
    try {
      final counts = await ComplaintService.menuCounts();
      if (!mounted) return;
      setState(() => _menuCounts = counts);
    } catch (_) {
      // ถ้าโหลดไม่ได้ก็ไม่เป็นไร (แค่ไม่มี badge)
    }
  }

  Future<void> _loadAnnouncements() async {
    try {
      final list = await AnnouncementService.list();
      if (!mounted) return;
      setState(() {
        _announcements = list;
        _loadingAnn = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingAnn = false);
    }
  }

  // เป็นเจ้าหน้าที่ไหม (ไว้โชว์ปุ่มสร้างประกาศ)
  bool get _isOfficer => widget.roles.contains(UserRole.officer);

  @override
  Widget build(BuildContext context) {
    final menus = menusForRoles(widget.roles);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGreetingCard(),
                const SizedBox(height: 24),
                // แสดงส่วนประกาศเฉพาะเมื่อมีประกาศ
                if (!_loadingAnn && _announcements.isNotEmpty) ...[
                  _buildAnnouncementHeader(),
                  const SizedBox(height: 12),
                  _buildAnnouncementSection(),
                  const SizedBox(height: 24),
                ],
                _sectionTitle('เมนูหลัก'),
                const SizedBox(height: 12),
                _buildMenuGrid(menus),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ดึงชื่อเต็มจากโปรไฟล์ (คำนำหน้า + ชื่อ + นามสกุล)
  String get _fullName {
    final p = widget.profile;
    if (p == null) return '';
    final title = (p['title'] as String?) ?? '';
    final first = (p['first_name'] as String?) ?? '';
    final last = (p['last_name'] as String?) ?? '';
    return '$title$first $last'.trim();
  }

  // ที่อยู่ย่อๆ (บ้านเลขที่ + หมู่บ้าน)
  String get _address {
    final p = widget.profile;
    if (p == null) return 'ผู้ใช้งานระบบประปาหมู่บ้าน';
    final houseNo = (p['house_no'] as String?) ?? '';
    final village = (p['village'] as String?) ?? '';
    if (houseNo.isEmpty && village.isEmpty) {
      return 'ผู้ใช้งานระบบประปาหมู่บ้าน';
    }
    return 'บ้านเลขที่ $houseNo  $village'.trim();
  }

  String? get _avatarUrl => widget.profile?['avatar_url'] as String?;

  // ===== การ์ดม่วง: รูปโปรไฟล์จาก LINE + ชื่อจริง =====
  Widget _buildGreetingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              // (ยังไม่มีหน้าโปรไฟล์)
            },
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                // ถ้ามีรูปจาก LINE ให้เอามาแสดง
                image: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                    ? DecorationImage(
                        image: NetworkImage(_avatarUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              // ถ้าไม่มีรูป ใช้ไอคอนคนแทน
              child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                  ? const Icon(Icons.person,
                      color: AppColors.primaryLight, size: 34)
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fullName.isEmpty ? 'สวัสดี' : 'สวัสดี $_fullName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== การ์ดประกาศ =====
  // หัวข้อประกาศ + ปุ่มสร้าง (เฉพาะเจ้าหน้าที่) + ดูทั้งหมด
  Widget _buildAnnouncementHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _sectionTitle('ประกาศ'),
        GestureDetector(
          onTap: _openAllAnnouncements,
          child: const Text('ดูทั้งหมด',
              style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Future<void> _openCreateAnnouncement() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AnnouncementCreateScreen()),
    );
    if (created == true) _loadAnnouncements();
  }

  Future<void> _openAllAnnouncements() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AnnouncementListScreen()),
    );
    _loadAnnouncements();
  }

  // ส่วนประกาศบนหน้าหลัก (แสดงล่าสุด 1-2 อัน)
  Widget _buildAnnouncementSection() {
    if (_loadingAnn) {
      return Container(
        height: 80,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.field,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: const CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_announcements.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.field,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text('ไม่มีประกาศในขณะนี้',
            style: TextStyle(color: AppColors.textGrey, fontSize: 13.5)),
      );
    }
    // โชว์สูงสุด 2 อันบนหน้าหลัก
    final show = _announcements.take(2).toList();
    return Column(
      children: show.map(_announcementCard).toList(),
    );
  }

  Widget _announcementCard(Announcement a) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(a.title,
                    style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark)),
              ),
              // ป้ายหมู่บ้าน
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  a.villageLabel,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(_annDateText(a),
              style: const TextStyle(
                  color: AppColors.textGrey, fontSize: 13)),
          if (a.detail != null && a.detail!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(a.detail!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textDark, fontSize: 13.5)),
          ],
        ],
      ),
    );
  }

  // ข้อความวันที่+เวลาของประกาศ
  String _annDateText(Announcement a) {
    const months = [
      '', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
    ];
    final d = a.eventDate;
    final date = '${d.day} ${months[d.month]} ${d.year + 543}';
    if (a.startTime != null && a.endTime != null) {
      return '$date เวลา ${a.startTime} - ${a.endTime} น.';
    } else if (a.startTime != null) {
      return '$date เวลา ${a.startTime} น.';
    }
    return date;
  }

  // ===== เมนูแบบตาราง 2 คอลัมน์ (จำนวนเปลี่ยนตาม role) =====
  Widget _buildMenuGrid(List<MenuItemData> items) {
    final rows = <Widget>[];
    for (int i = 0; i < items.length; i += 2) {
      final first = items[i];
      final second = (i + 1 < items.length) ? items[i + 1] : null;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _menuItem(first)),
              const SizedBox(width: 14),
              // ถ้าแถวนี้มีแค่อันเดียว ใส่ช่องว่างไว้ให้ขนาดเท่ากัน
              Expanded(
                child: second != null
                    ? _menuItem(second)
                    : const SizedBox(),
              ),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  // กดเมนูแล้วไปหน้าที่เกี่ยวข้อง
  Future<void> _onMenuTap(MenuItemData data) async {
    switch (data.label) {
      case 'ข้อมูลแทงค์น้ำ':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WaterTankListScreen()),
        );
      case 'สถานะประปา':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TankStatusScreen()),
        );
      case 'ประวัติแจ้งปัญหา':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MyReportsScreen()),
        );
      case 'แจ้งปัญหา':
        _reportProblem();
      case 'จัดการผู้ใช้':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
        );
      case 'รับเรื่องแจ้งซ่อม':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ComplaintListScreen()),
        );
        _loadMenuCounts(); // รีเฟรช badge หลังกลับ
      case 'อัปเดตสถานะการซ่อม':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RepairStatusScreen()),
        );
        _loadMenuCounts();
      case 'สร้างประกาศ':
        _openCreateAnnouncement();
      case 'รับเรื่องจากเจ้าหน้าที่':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const VillageHeadReceiveScreen()),
        );
        _loadMenuCounts(); // รีเฟรช badge หลังกลับ
      case 'อนุมัติงบประมาณ':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BudgetApproveScreen()),
        );
        _loadMenuCounts(); // รีเฟรช badge หลังกลับ
      case 'รับเรื่องจากผู้ใหญ่บ้าน':
        await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const PaladListScreen(mode: PaladMode.receive)),
        );
        _loadMenuCounts();
      case 'สมทบงบประมาณ':
        await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const PaladListScreen(mode: PaladMode.approve)),
        );
        _loadMenuCounts();
      case 'Dashboard':
        // เช็คผู้ใหญ่บ้าน/เจ้าหน้าที่หมู่บ้านก่อน (role เจาะจงหมู่บ้านตัวเอง)
        // เพื่อไม่ให้คนที่มี role admin ติดมาด้วย (เช่น admin ที่เพิ่มสิทธิ์ผู้ใหญ่บ้านให้ตัวเองไว้ทดสอบ)
        // ถูกเด้งไปหน้าเทศบาลทั้งที่ควรเห็น Dashboard เฉพาะหมู่บ้าน/แทงค์ของตัวเอง
        if (widget.roles.contains(UserRole.villageHead) ||
            widget.roles.contains(UserRole.officer)) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const VillageHeadDashboardScreen(),
            ),
          );
        } else if (widget.roles.contains(UserRole.palad) ||
            widget.roles.contains(UserRole.admin)) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PaladDashboardScreen()),
          );
        }
      default:
        break; // เมนูที่ยังไม่มีหน้า -> ไม่ทำอะไร
    }
  }

  // ===== แจ้งปัญหา =====
  // ขั้นที่ 1: เลือกแทงค์จากแผนที่ -> ขั้นที่ 2: กรอกรายละเอียด
  Future<void> _reportProblem() async {
    final tank = await Navigator.push<WaterTank>(
      context,
      MaterialPageRoute(builder: (_) => const TankMapPickerScreen()),
    );

    if (tank == null || !mounted) return;

    final sent = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ReportProblemScreen(tank: tank)),
    );

    if (sent == true && mounted) {
      AppToast.show(context, 'ส่งเรื่องเรียบร้อยแล้ว');
    }
  }

  // แปลงชื่อเมนู -> key ของ badge count
  int _badgeFor(String label) {
    const map = {
      'รับเรื่องแจ้งซ่อม': 'receiveComplaint',
      'อัปเดตสถานะการซ่อม': 'repairStatus',
      'รับเรื่องจากเจ้าหน้าที่': 'headReceive',
      'อนุมัติงบประมาณ': 'budgetApprove',
      'รับเรื่องจากผู้ใหญ่บ้าน': 'paladReceive',
      'สมทบงบประมาณ': 'paladApprove',
    };
    final key = map[label];
    if (key == null) return 0;
    return _menuCounts[key] ?? 0;
  }

  Widget _menuItem(MenuItemData data) {
    final badge = _badgeFor(data.label);
    return GestureDetector(
      onTap: () => _onMenuTap(data),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.field,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: data.circleColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(data.icon, color: data.iconColor, size: 28),
                ),
                const SizedBox(height: 12),
                Text(
                  data.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
          // badge วงกลมแดง มุมขวาบน (ถ้ามีงานค้าง)
          if (badge > 0)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                decoration: const BoxDecoration(
                  color: Color(0xFFD9534F),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    badge > 99 ? '99+' : '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // กดแถบเมนูล่าง
  void _onNavTap(int index) {
    switch (index) {
      case 1: // แจ้งปัญหา
        _reportProblem();
      case 2: // โปรไฟล์ -> เปิดเมนูโปรไฟล์
        _openProfileSheet();
      default:
        setState(() => _currentIndex = 0);
    }
  }

  // เมนูโปรไฟล์ (มีปุ่มออกจากระบบ)
  void _openProfileSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            // รูป + ชื่อ
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFEAE0FB),
                shape: BoxShape.circle,
                image: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                    ? DecorationImage(
                        image: NetworkImage(_avatarUrl!), fit: BoxFit.cover)
                    : null,
              ),
              child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                  ? const Icon(Icons.person, color: AppColors.primary, size: 32)
                  : null,
            ),
            const SizedBox(height: 10),
            Text(
              _fullName.isEmpty ? 'ผู้ใช้งาน' : _fullName,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            // ปุ่มออกจากระบบ
            ListTile(
              leading: const Icon(Icons.logout, color: Color(0xFFD9534F)),
              title: const Text('ออกจากระบบ',
                  style: TextStyle(
                      color: Color(0xFFD9534F),
                      fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmLogout();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ยืนยันก่อนออกจากระบบ
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ออกจากระบบ'),
        content: const Text('ต้องการออกจากระบบใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () async {
              await AuthService.logout(); // ล้าง session
              // กลับไปหน้า Welcome ล้าง stack ทั้งหมด
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD9534F),
              foregroundColor: Colors.white,
            ),
            child: const Text('ออกจากระบบ'),
          ),
        ],
      ),
    );
  }

  // ===== แถบเมนูล่าง =====
  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: _onNavTap,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textGrey,
      backgroundColor: Colors.white,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'หน้าหลัก'),
        BottomNavigationBarItem(
            icon: Icon(Icons.report_problem), label: 'แจ้งปัญหา'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'โปรไฟล์'),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.textDark,
      ),
    );
  }
}