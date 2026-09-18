import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_toast.dart';
import '../widgets/app_dialog.dart';
import '../widgets/image_gallery.dart';
import '../data/villages.dart';
import '../data/water_tank.dart';
import '../services/session.dart';
import '../services/tank_service.dart';
import 'water_tank_add_screen.dart';

// หน้าจัดการข้อมูลแทงค์น้ำ (รายการทั้งหมด)
class WaterTankListScreen extends StatefulWidget {
  const WaterTankListScreen({super.key});

  @override
  State<WaterTankListScreen> createState() => _WaterTankListScreenState();
}

class _WaterTankListScreenState extends State<WaterTankListScreen> {
  final _searchController = TextEditingController();

  String _keyword = ''; // คำค้นหา
  int? _villageMooFilter; // ตัวกรองหมู่บ้าน (null = ทุกหมู่บ้าน)

  List<WaterTank> _tanks = [];
  bool _loading = true; // กำลังโหลดข้อมูลอยู่ไหม
  String? _error; // ข้อความ error (ถ้ามี)

  @override
  void initState() {
    super.initState();
    // เริ่มต้นให้แสดงหมู่บ้านที่ผู้ใช้ลงทะเบียนไว้
    _villageMooFilter = _myMoo();
    _loadTanks();
  }

  // หาหมู่บ้าน default ให้ตรงกับบทบาท (คืนเป็นเลขหมู่ กันชื่อซ้ำ 2 หมู่ปนกัน)
  // - ผู้ใหญ่บ้าน/เจ้าหน้าที่หมู่บ้าน -> หมู่บ้านที่ตัวเอง "ดูแล" (อาจไม่ใช่หมู่บ้านที่อยู่)
  // - ประชาชน/เจ้าหน้าที่เทศบาล -> หมู่บ้านที่อยู่อาศัยจากโปรไฟล์
  // โปรไฟล์/officerVillage/headVillage เก็บเป็น "หมู่ 1 บ้านบุญเรืองเหนือ" -> ตัดเอาเลขหมู่
  int? _myMoo() {
    if (AppSession.isOfficer && AppSession.officerVillage != null) {
      return mooFromLabel(AppSession.officerVillage);
    }
    if (AppSession.isVillageHead && AppSession.headVillage != null) {
      return mooFromLabel(AppSession.headVillage);
    }

    final v = AppSession.profile?['village'] as String?;
    if (v == null || v.isEmpty) return null;
    return mooFromLabel(v);
  }

  // ===== โหลดข้อมูลจาก PostgreSQL =====
  Future<void> _loadTanks() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tanks = await TankService.fetchTanks();
      if (!mounted) return;
      setState(() {
        _tanks = tanks;
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // กรองรายการตามคำค้นหา + หมู่บ้านที่เลือก
  List<WaterTank> get _filtered {
    return _tanks.where((t) {
      final matchVillage =
          _villageMooFilter == null || t.moo == _villageMooFilter;
      final kw = _keyword.trim();
      final matchKeyword = kw.isEmpty ||
          t.name.contains(kw) ||
          t.village.contains(kw);
      return matchVillage && matchKeyword;
    }).toList();
  }

  // ไปหน้าเพิ่มแทงค์น้ำ
  Future<void> _goAdd() async {
    final result = await Navigator.push<WaterTank>(
      context,
      MaterialPageRoute(builder: (_) => const WaterTankAddScreen()),
    );
    // ถ้าเพิ่มสำเร็จ โหลดรายการใหม่จากฐานข้อมูล
    if (result != null) _loadTanks();
  }

  void _onDelete(WaterTank tank) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบ "${tank.name}" ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await TankService.deleteTank(tank.id);
                if (!mounted) return;
                _loadTanks(); // โหลดใหม่หลังลบ
                AppToast.show(context, 'ลบ "${tank.name}" แล้ว');
              } catch (e) {
                if (!mounted) return;
                AppDialog.error(context, 'ลบไม่สำเร็จ');
              }
            },
            child: const Text('ลบ', style: TextStyle(color: Colors.red)),
          ),
        ],
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
            // การ์ดขาวเต็มพื้นที่ที่เหลือ
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
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
                    _buildSearchRow(),
                    const SizedBox(height: 12),
                    _buildVillageFilter(),
                    const SizedBox(height: 18),
                    const Text(
                      'รายการแทงค์น้ำ',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(child: _buildList()),
                  ],
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
                  'ข้อมูลแทงค์น้ำ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'จัดการข้อมูลระบบประปา',
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

  // เจ้าหน้าที่เท่านั้นที่แก้ไข/ลบ/เพิ่มได้ (ประชาชนดูอย่างเดียว)
  bool get _canEdit => AppSession.isOfficer;

  // แก้ไข/ลบได้เฉพาะแทงค์ในหมู่บ้านที่ตัวเองดูแลเท่านั้น (กันเห็นปุ่มของหมู่บ้านอื่น)
  // เทียบด้วยเลขหมู่ ไม่ใช่ชื่อ (ชื่อหมู่บ้านซ้ำกันได้ระหว่าง 2 หมู่)
  bool _canEditTank(WaterTank tank) =>
      AppSession.isOfficer &&
      tank.moo == mooFromLabel(AppSession.officerVillage);

  // เปิดหน้าแก้ไขแทงค์ แล้วโหลดรายการใหม่ถ้าแก้สำเร็จ
  Future<void> _openEdit(WaterTank tank) async {
    final updated = await Navigator.push<WaterTank>(
      context,
      MaterialPageRoute(builder: (_) => WaterTankAddScreen(tank: tank)),
    );
    if (updated != null && mounted) {
      _loadTanks();
      AppToast.show(context, 'แก้ไข "${updated.name}" แล้ว');
    }
  }

  // ===== ช่องค้นหา + ปุ่มเพิ่ม =====
  Widget _buildSearchRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _keyword = v),
            decoration: InputDecoration(
              hintText: 'ค้นหาชื่อแทงค์หรือหมู่บ้าน',
              hintStyle: const TextStyle(
                  color: AppColors.textGrey, fontSize: 13.5),
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
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
        ),
        // ปุ่มเพิ่ม: เฉพาะเจ้าหน้าที่
        if (_canEdit) ...[
        const SizedBox(width: 10),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _goAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '+ เพิ่ม',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ),
        ],
      ],
    );
  }

  // ===== dropdown กรองหมู่บ้าน =====
  Widget _buildVillageFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: _villageMooFilter,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down,
              color: AppColors.textGrey),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('ทุกหมู่บ้าน')),
            ...kVillageMooMap.keys.map((moo) {
              return DropdownMenuItem<int?>(
                  value: moo, child: Text(villageLabelOfMoo(moo)));
            }),
          ],
          onChanged: (moo) => setState(() => _villageMooFilter = moo),
        ),
      ),
    );
  }

  // ===== รายการแทงค์ =====
  Widget _buildList() {
    // กำลังโหลด
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    // โหลดไม่สำเร็จ
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, color: AppColors.textGrey, size: 40),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textGrey, fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loadTanks,
              child: const Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }

    final items = _filtered;

    if (items.isEmpty) {
      return const Center(
        child: Text(
          'ไม่พบข้อมูลแทงค์น้ำ',
          style: TextStyle(color: AppColors.textGrey),
        ),
      );
    }

    // ดึงลงเพื่อโหลดใหม่ได้
    return RefreshIndicator(
      onRefresh: _loadTanks,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _tankCard(items[i]),
      ),
    );
  }

  Widget _tankCard(WaterTank tank) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // รูปแทงค์ (รูปแรกที่แนบมา) — ถ้าไม่มีรูป ใช้ไอคอนหยดน้ำ
              _buildTankThumb(tank),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tank.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ประเภท : ${tank.type}',
                      style: const TextStyle(
                          color: AppColors.textGrey, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'หมู่ ${tank.moo} ${tank.village}',
                      style: const TextStyle(
                          color: AppColors.textGrey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ปุ่ม — ประชาชนเห็นแค่ "รายละเอียด" / เจ้าหน้าที่เห็นครบ
          Row(
            children: [
              Expanded(
                child: _smallButton(
                  'รายละเอียด',
                  bg: const Color(0xFFEFEAFD),
                  fg: AppColors.primary,
                  onTap: () => _showDetail(tank),
                ),
              ),
              if (_canEditTank(tank)) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _smallButton(
                    'แก้ไข',
                    bg: const Color(0xFFDDEBFB),
                    fg: const Color(0xFF3B7DD8),
                    onTap: () => _openEdit(tank),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _smallButton(
                    'ลบ',
                    bg: const Color(0xFFFBE0E0),
                    fg: const Color(0xFFD9534F),
                    onTap: () => _onDelete(tank),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ===== รูปย่อของแทงค์ =====
  // แสดงรูปแรกที่แนบไว้ พร้อมจัดการตอนกำลังโหลด และตอนโหลดไม่ขึ้น
  Widget _buildTankThumb(WaterTank tank) {
    const double size = 84;

    // ยังไม่มีรูป -> ไอคอนหยดน้ำ
    if (tank.imageUrls.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFF2F4FB),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.water_drop,
            color: Color(0xFF4A90E2), size: 34),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        tank.imageUrls.first,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // กำลังโหลดรูป
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child; // โหลดเสร็จแล้ว
          return Container(
            width: size,
            height: size,
            color: const Color(0xFFF2F4FB),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          );
        },
        // โหลดรูปไม่ขึ้น (เน็ตหลุด / รูปถูกลบ)
        errorBuilder: (context, error, stack) {
          return Container(
            width: size,
            height: size,
            color: const Color(0xFFF2F4FB),
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image,
                color: AppColors.textGrey, size: 30),
          );
        },
      ),
    );
  }

  Widget _smallButton(
    String label, {
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: fg, fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  // แสดงรายละเอียดแบบ popup
  void _showDetail(WaterTank tank) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // ชื่อแทงค์ + chip ประเภท
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('รายละเอียดแทงค์',
                              style: TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textGrey)),
                          const SizedBox(height: 4),
                          Text(
                            tank.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(tank.type,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // รูปทั้งหมด (แตะดูเต็มจอ)
                if (tank.imageUrls.isNotEmpty) ...[
                  ImageGrid(urls: tank.imageUrls),
                  const SizedBox(height: 16),
                ],
                // การ์ดข้อมูล (แต่ละแถวมีไอคอน)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _iconRow(Icons.water_drop_outlined, 'ประเภทประปา',
                          tank.type),
                      _iconRow(Icons.home_outlined, 'หมู่บ้าน', tank.village),
                      _iconRow(Icons.tag, 'หมู่ที่', '${tank.moo}'),
                      if (tank.capacity != null)
                        _iconRow(Icons.speed_outlined, 'ความจุ',
                            '${_money(tank.capacity!)} ลิตร'),
                      if (tank.builtYear != null)
                        _iconRow(Icons.calendar_today_outlined, 'ปีที่สร้าง',
                            'พ.ศ. ${tank.builtYear}'),
                      if (tank.caretaker != null &&
                          tank.caretaker!.isNotEmpty)
                        _iconRow(Icons.person_outline, 'ผู้ดูแล',
                            tank.caretaker!),
                      if (tank.caretakerPhone != null &&
                          tank.caretakerPhone!.isNotEmpty)
                        _iconRow(Icons.phone_outlined, 'เบอร์ติดต่อ',
                            tank.caretakerPhone!),
                      if (tank.detail != null && tank.detail!.isNotEmpty)
                        _iconRow(Icons.description_outlined, 'รายละเอียด',
                            tank.detail!, isLast: true),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // ตำแหน่งที่ตั้ง (กล่องแยก)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.location_on_outlined,
                              size: 18, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text('ตำแหน่งที่ตั้ง',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textGrey)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        (tank.lat != null && tank.lng != null)
                            ? '${tank.lat}, ${tank.lng}'
                            : 'ยังไม่ได้ระบุ',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // แถวข้อมูลมีไอคอน (สไตล์การ์ด)
  Widget _iconRow(IconData icon, String label, String value,
      {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.border, width: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textGrey)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ใส่ comma คั่นหลักพัน เช่น 20,000
  String _money(double n) {
    final str = n.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write(',');
      buf.write(str[i]);
    }
    return buf.toString();
  }

}