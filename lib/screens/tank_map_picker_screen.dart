import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../data/water_tank.dart';
import '../data/tank_status.dart';
import '../data/complaint.dart';
import '../services/complaint_service.dart';
import '../theme/app_colors.dart';

// หน้าเลือกแทงค์น้ำจากแผนที่ (สำหรับแจ้งปัญหา)
// แสดงหมุดแทงค์ทั้งหมด -> แตะหมุด -> ดูข้อมูล -> เลือก
class TankMapPickerScreen extends StatefulWidget {
  const TankMapPickerScreen({super.key});

  @override
  State<TankMapPickerScreen> createState() => _TankMapPickerScreenState();
}

class _TankMapPickerScreenState extends State<TankMapPickerScreen> {
  final _mapController = MapController();

  // จุดสำรอง: เทศบาลตำบลบุญเรือง
  static const LatLng _fallbackCenter = LatLng(19.990329, 100.332384);

  List<TankStatus> _tanks = [];
  bool _loading = true;
  String? _error;

  LatLng? _myLocation;
  TankStatus? _selected; // แทงค์ที่แตะเลือกอยู่

  @override
  void initState() {
    super.initState();
    _loadTanks();
    _findMyLocation();
  }

  // ===== โหลดแทงค์ทั้งหมดจากฐานข้อมูล =====
  Future<void> _loadTanks() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tanks = await ComplaintService.fetchTankStatus(null);
      if (!mounted) return;
      setState(() {
        _tanks = tanks;
        _loading = false;
      });

      // เลื่อนแผนที่ไปให้เห็นแทงค์แรกที่มีพิกัด
      final withCoords = _tanksWithCoords;
      if (withCoords.isNotEmpty && _myLocation == null) {
        _mapController.move(
          LatLng(withCoords.first.lat!, withCoords.first.lng!),
          15,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'โหลดข้อมูลไม่สำเร็จ: $e';
        _loading = false;
      });
    }
  }

  // แทงค์ที่มีพิกัดเท่านั้น (ตัวที่ไม่มีพิกัดวาดบนแผนที่ไม่ได้)
  List<TankStatus> get _tanksWithCoords =>
      _tanks.where((t) => t.lat != null && t.lng != null).toList();

  // จำนวนแทงค์ที่ยังไม่ได้ปักหมุด
  int get _noCoordCount => _tanks.length - _tanksWithCoords.length;

  // ===== หาตำแหน่งปัจจุบัน =====
  Future<void> _findMyLocation({bool moveMap = false}) async {
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;
      final here = LatLng(pos.latitude, pos.longitude);
      setState(() => _myLocation = here);

      if (moveMap) _mapController.move(here, 16);
    } catch (_) {
      // หาไม่ได้ก็ไม่เป็นไร ใช้แผนที่ปกติ
    }
  }

  // ยืนยันเลือกแทงค์นี้ (แปลง TankStatus -> WaterTank ส่งกลับ)
  void _onConfirm() {
    if (_selected == null) return;
    if (!_selected!.isNormal) return; // มีเรื่องค้าง เลือกไม่ได้
    final t = _selected!;
    Navigator.pop(
      context,
      WaterTank(
        id: t.tankId,
        name: t.name,
        type: t.type,
        village: t.village,
        moo: t.moo,
        imageUrls: t.imageUrls,
        lat: t.lat,
        lng: t.lng,
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
            const SizedBox(height: 8),
            Expanded(
              child: Stack(
                children: [
                  _buildMap(),
                  if (_loading) _buildLoadingBadge(),
                  if (!_loading && _error != null) _buildErrorBadge(),
                  if (!_loading && _error == null && _tanks.isEmpty)
                    _buildEmptyBadge(),
                  if (!_loading && _noCoordCount > 0) _buildNoCoordHint(),
                  _buildMyLocationButton(),
                  // การ์ดข้อมูลแทงค์ที่เลือก โผล่ขึ้นมาด้านล่าง
                  if (_selected != null) _buildSelectedCard(),
                ],
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
                  'เลือกแทงค์ที่มีปัญหา',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'แตะหมุดบนแผนที่เพื่อเลือก',
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

  // ===== แผนที่ =====
  Widget _buildMap() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
      ),
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _fallbackCenter,
          initialZoom: 14,
          // แตะที่ว่าง = ยกเลิกการเลือก
          onTap: (_, __) => setState(() => _selected = null),
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
            userAgentPackageName: 'com.example.water_app',
          ),
          // จุดสีฟ้า = ตำแหน่งเรา
          if (_myLocation != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _myLocation!,
                  width: 22,
                  height: 22,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90E2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          // หมุดแทงค์น้ำทั้งหมด
          MarkerLayer(
            markers: _tanksWithCoords.map(_tankMarker).toList(),
          ),
        ],
      ),
    );
  }

  // หมุด 1 อัน — ตัวที่เลือกอยู่จะใหญ่กว่าและเป็นสีม่วง
  Marker _tankMarker(TankStatus tank) {
    final isSelected = _selected?.tankId == tank.tankId;
    final hasActive = !tank.isNormal; // มีเรื่องค้าง

    // สีหมุด: เลือกอยู่=ม่วง, มีเรื่องค้าง=เทา, ปกติ=ฟ้า
    final Color pinColor = isSelected
        ? AppColors.primary
        : (hasActive ? const Color(0xFF9AA0A6) : const Color(0xFF4A90E2));

    return Marker(
      point: LatLng(tank.lat!, tank.lng!),
      width: isSelected ? 52 : 44,
      height: isSelected ? 52 : 44,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () {
          setState(() => _selected = tank);
          _mapController.move(LatLng(tank.lat!, tank.lng!), 16);
        },
        child: Icon(
          Icons.location_on,
          color: pinColor,
          size: isSelected ? 52 : 44,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
            ),
          ],
        ),
      ),
    );
  }

  // ===== การ์ดข้อมูลแทงค์ที่เลือก =====
  Widget _buildSelectedCard() {
    final tank = _selected!;

    return Positioned(
      left: 14,
      right: 14,
      bottom: 14,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _thumb(tank),
                const SizedBox(width: 12),
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
                            color: AppColors.textGrey, fontSize: 12.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'หมู่ ${tank.moo} ${tank.village}',
                        style: const TextStyle(
                            color: AppColors.textGrey, fontSize: 12.5),
                      ),
                      // ป้ายสถานะถ้ามีเรื่องค้าง
                      if (!tank.isNormal) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8923A)
                                .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            tank.latestStatus != null
                                ? statusLabel(tank.latestStatus!)
                                : 'มีเรื่องแจ้งอยู่',
                            style: const TextStyle(
                                color: Color(0xFFB5701F),
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // ปุ่มปิดการ์ด
                GestureDetector(
                  onTap: () => setState(() => _selected = null),
                  child: const Icon(Icons.close,
                      color: AppColors.textGrey, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // มีเรื่องค้าง -> แจ้งซ้ำไม่ได้
            if (!tank.isNormal)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline,
                        size: 17, color: AppColors.textGrey),
                    SizedBox(width: 6),
                    Text('แทงค์นี้มีเรื่องแจ้งอยู่แล้ว',
                        style: TextStyle(
                            color: AppColors.textGrey,
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: _onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'เลือกแทงค์นี้',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _thumb(TankStatus tank) {
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

  // ===== ปุ่มกลับไปตำแหน่งปัจจุบัน =====
  Widget _buildMyLocationButton() {
    return Positioned(
      right: 16,
      bottom: _selected != null ? 190 : 16, // ขยับขึ้นเมื่อมีการ์ด
      child: GestureDetector(
        onTap: () => _findMyLocation(moveMap: true),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.my_location, color: AppColors.primary),
        ),
      ),
    );
  }

  // ===== ป้ายบอกสถานะต่างๆ ด้านบน =====
  Widget _badge(Widget child) {
    return Positioned(
      top: 12,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _buildLoadingBadge() {
    return _badge(
      Row(
        children: const [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'กำลังโหลดแทงค์น้ำ...',
            style: TextStyle(fontSize: 13, color: AppColors.textDark),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBadge() {
    return _badge(
      Row(
        children: [
          const Icon(Icons.cloud_off, size: 18, color: AppColors.textGrey),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textDark),
            ),
          ),
          TextButton(
            onPressed: _loadTanks,
            child: const Text('ลองใหม่', style: TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBadge() {
    return _badge(
      Row(
        children: const [
          Icon(Icons.info_outline, size: 18, color: AppColors.textGrey),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'ยังไม่มีข้อมูลแทงค์น้ำในระบบ',
              style: TextStyle(fontSize: 12.5, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }

  // เตือนว่ามีแทงค์บางตัวยังไม่ได้ปักหมุด เลยไม่โผล่บนแผนที่
  Widget _buildNoCoordHint() {
    return Positioned(
      top: _loading || _error != null ? 62 : 12,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4E0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 16, color: Color(0xFFE8923A)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'มีแทงค์ $_noCoordCount แห่งที่ยังไม่ได้ปักหมุด จึงไม่แสดงบนแผนที่',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF8A5A1A)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}