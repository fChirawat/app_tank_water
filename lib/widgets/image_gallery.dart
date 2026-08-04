import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

// ===================================================
//  widget กลางสำหรับแสดงรูป — ใช้ร่วมกันทุกหน้า
//  แก้ที่ไฟล์นี้ที่เดียว ทุกหน้าเปลี่ยนตาม
// ===================================================

// ===== ตารางรูป 2 รูปต่อแถว =====
// แตะที่รูปเพื่อเปิดดูเต็มจอ (ซูมได้)
class ImageGrid extends StatelessWidget {
  // รูปจากอินเทอร์เน็ต (URL)
  final List<String> urls;

  // รูปจากเครื่อง (ไฟล์ที่เพิ่งเลือก ยังไม่อัปโหลด)
  final List<File> files;

  // ถ้าใส่มา จะมีปุ่มกากบาทให้ลบ (ส่ง index ของรูปกลับไป)
  // index จะนับ urls ก่อน แล้วต่อด้วย files
  final void Function(int index)? onRemove;

  const ImageGrid({
    super.key,
    this.urls = const [],
    this.files = const [],
    this.onRemove,
  });

  int get _total => urls.length + files.length;

  @override
  Widget build(BuildContext context) {
    if (_total == 0) return const SizedBox.shrink();

    return GridView.builder(
      // ให้สูงตามเนื้อหา ไม่เลื่อนเอง (อยู่ในหน้าที่เลื่อนได้อยู่แล้ว)
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 2 รูปต่อแถว
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1, // สี่เหลี่ยมจัตุรัส
      ),
      itemCount: _total,
      itemBuilder: (context, i) => _thumb(context, i),
    );
  }

  Widget _thumb(BuildContext context, int index) {
    final isUrl = index < urls.length;

    final Widget image = isUrl
        ? Image.network(
            urls[index],
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                color: const Color(0xFFF2F4FB),
                child: const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  ),
                ),
              );
            },
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFFF2F4FB),
              child:
                  const Icon(Icons.broken_image, color: AppColors.textGrey),
            ),
          )
        : Image.file(files[index - urls.length], fit: BoxFit.cover);

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: () => _openViewer(context, index),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: image,
          ),
        ),
        // ปุ่มลบ (ถ้าเปิดใช้)
        if (onRemove != null)
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: () => onRemove!(index),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
      ],
    );
  }

  void _openViewer(BuildContext context, int startIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageViewerScreen(
          urls: urls,
          files: files,
          initialIndex: startIndex,
        ),
      ),
    );
  }
}

// ===== หน้าดูรูปเต็มจอ =====
// ซูมได้ (นิ้วถ่างเข้าออก / แตะสองครั้ง) และปัดซ้ายขวาเปลี่ยนรูป
class ImageViewerScreen extends StatefulWidget {
  final List<String> urls;
  final List<File> files;
  final int initialIndex;

  const ImageViewerScreen({
    super.key,
    this.urls = const [],
    this.files = const [],
    this.initialIndex = 0,
  });

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late PageController _pageController;
  late int _current;

  // ตัวควบคุมการซูมของรูปที่กำลังดู
  final TransformationController _zoom = TransformationController();

  int get _total => widget.urls.length + widget.files.length;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _zoom.dispose();
    super.dispose();
  }

  // แตะสองครั้งเพื่อซูมเข้า/ออก
  void _onDoubleTap() {
    if (_zoom.value != Matrix4.identity()) {
      _zoom.value = Matrix4.identity(); // ซูมออกกลับปกติ
    } else {
      _zoom.value = Matrix4.identity()..scale(2.5); // ซูมเข้า
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // รูป
            PageView.builder(
              controller: _pageController,
              itemCount: _total,
              onPageChanged: (i) {
                setState(() => _current = i);
                _zoom.value = Matrix4.identity(); // เปลี่ยนรูปแล้วรีเซ็ตซูม
              },
              itemBuilder: (_, i) {
                final isUrl = i < widget.urls.length;
                return GestureDetector(
                  onDoubleTap: _onDoubleTap,
                  child: InteractiveViewer(
                    transformationController: _zoom,
                    minScale: 1,
                    maxScale: 5,
                    child: Center(
                      child: isUrl
                          ? Image.network(
                              widget.urls[i],
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.white),
                                );
                              },
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.broken_image,
                                color: Colors.white54,
                                size: 60,
                              ),
                            )
                          : Image.file(
                              widget.files[i - widget.urls.length],
                              fit: BoxFit.contain,
                            ),
                    ),
                  ),
                );
              },
            ),

            // ปุ่มปิด
            Positioned(
              top: 10,
              left: 10,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),

            // บอกว่ารูปที่เท่าไหร่ จากทั้งหมดกี่รูป
            if (_total > 1)
              Positioned(
                top: 18,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_current + 1} / $_total',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}