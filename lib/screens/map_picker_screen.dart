import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_colors.dart';
import '../widgets/app_dialog.dart';

// หน้าแผนที่สำหรับปักหมุดเลือกตำแหน่ง
// ใช้ OpenStreetMap (ฟรี ไม่ต้องมี API key)
// เปิดมาจะเลื่อนไปที่ตำแหน่งปัจจุบันของผู้ใช้อัตโนมัติ
class MapPickerScreen extends StatefulWidget {
  // ตำแหน่งเดิม (ถ้ามี) เพื่อให้เปิดมาแล้วเห็นหมุดเก่า
  final double? initialLat;
  final double? initialLng;

  const MapPickerScreen({
    super.key,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final _mapController = MapController();

  // จุดสำรอง ใช้เมื่อหาตำแหน่งปัจจุบันไม่ได้
  // (เช่น ผู้ใช้ไม่อนุญาต หรือปิด GPS)
  static const LatLng _fallbackCenter = LatLng(20.0431, 100.1123);

  LatLng? _picked; // หมุดที่เลือกไว้
  LatLng? _myLocation; // ตำแหน่งปัจจุบันของผู้ใช้
  bool _loadingLocation = true; // กำลังหาตำแหน่งอยู่ไหม

  @override
  void initState() {
    super.initState();
    // ถ้ามีตำแหน่งเดิมส่งมา ให้ปักหมุดไว้เลย
    if (widget.initialLat != null && widget.initialLng != null) {
      _picked = LatLng(widget.initialLat!, widget.initialLng!);
      _loadingLocation = false; // มีจุดอยู่แล้ว ไม่ต้องหาตำแหน่ง
    } else {
      _goToMyLocation(moveMap: true);
    }
  }

  // ===== หาตำแหน่งปัจจุบัน =====
  Future<void> _goToMyLocation({bool moveMap = true}) async {
    setState(() => _loadingLocation = true);

    try {
      // เช็คว่าเปิด GPS ไหม
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        _fail('กรุณาเปิด GPS แล้วลองใหม่');
        return;
      }

      // ขอสิทธิ์เข้าถึงตำแหน่ง
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _fail('ไม่ได้รับอนุญาตให้เข้าถึงตำแหน่ง');
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _fail('กรุณาเปิดสิทธิ์ตำแหน่งในตั้งค่าของเครื่อง');
        return;
      }

      // ได้สิทธิ์แล้ว ดึงตำแหน่ง
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final here = LatLng(pos.latitude, pos.longitude);

      if (!mounted) return;
      setState(() {
        _myLocation = here;
        _loadingLocation = false;
      });

      if (moveMap) _mapController.move(here, 16);
    } catch (e) {
      _fail('หาตำแหน่งไม่สำเร็จ');
    }
  }

  // หาตำแหน่งไม่ได้ -> ใช้จุดสำรอง แล้วบอกผู้ใช้
  void _fail(String msg) {
    AppDialog.warn(context, msg);
  }

  // กดบนแผนที่ = ย้ายหมุดไปจุดนั้น
  void _onMapTap(TapPosition tapPos, LatLng point) {
    setState(() => _picked = point);
  }

  // ยืนยันตำแหน่ง แล้วส่งค่ากลับไปหน้าเพิ่มแทงค์
  void _onConfirm() {
    if (_picked == null) {
      AppDialog.warn(context, 'กรุณาแตะบนแผนที่เพื่อปักหมุด');
      return;
    }
    Navigator.pop(context, _picked);
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
                  if (_picked != null) _buildCoordBadge(),
                  _buildMyLocationButton(),
                  if (_loadingLocation) _buildLoadingOverlay(),
                ],
              ),
            ),
            _buildBottomBar(),
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
                  'เลือกตำแหน่งแทงค์น้ำ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'แตะบนแผนที่เพื่อปักหมุด',
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
          // เปิดมาที่: หมุดเดิม > ตำแหน่งปัจจุบัน > จุดสำรอง
          initialCenter: _picked ?? _myLocation ?? _fallbackCenter,
          initialZoom: 16,
          onTap: _onMapTap,
        ),
        children: [
          // ชั้นแผนที่ดาวเทียมจาก Esri World Imagery
          TileLayer(
            urlTemplate:
                'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
            userAgentPackageName: 'com.example.water_app',
          ),
          // จุดสีฟ้าแสดงตำแหน่งปัจจุบันของเรา
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
          // หมุดที่ผู้ใช้ปัก
          if (_picked != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _picked!,
                  width: 44,
                  height: 44,
                  // ให้ปลายหมุดชี้ตรงจุดที่กด
                  alignment: Alignment.topCenter,
                  child: const Icon(
                    Icons.location_on,
                    color: AppColors.primary,
                    size: 44,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ===== ปุ่มกลับไปตำแหน่งปัจจุบัน =====
  Widget _buildMyLocationButton() {
    return Positioned(
      right: 16,
      bottom: 16,
      child: GestureDetector(
        onTap: () => _goToMyLocation(),
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

  // ===== ป้ายบอกพิกัด =====
  Widget _buildCoordBadge() {
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
        child: Row(
          children: [
            const Icon(Icons.location_on, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'พิกัด: ${_picked!.latitude.toStringAsFixed(6)}, '
                '${_picked!.longitude.toStringAsFixed(6)}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== ตอนกำลังหาตำแหน่ง =====
  Widget _buildLoadingOverlay() {
    return Positioned(
      top: 12,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
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
              'กำลังหาตำแหน่งปัจจุบัน...',
              style: TextStyle(fontSize: 13, color: AppColors.textDark),
            ),
          ],
        ),
      ),
    );
  }

  // ===== แถบปุ่มด้านล่าง =====
  Widget _buildBottomBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 50,
              child: OutlinedButton(
                onPressed: () => setState(() => _picked = null),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'ล้างหมุด',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 50,
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
                  'ยืนยันตำแหน่ง',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}