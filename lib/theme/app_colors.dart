import 'package:flutter/material.dart';

// ===== สีกลางของทั้งแอป =====
// แก้สีที่นี่ที่เดียว แล้วทุกหน้าจะเปลี่ยนตามอัตโนมัติ
// ถ้ามีรหัสสีเป๊ะจาก Figma เอามาแก้ตรงค่าพวกนี้ได้เลย
class AppColors {
  static const Color primary = Color(0xFF7C5CFC);      // ม่วงหลัก (ปุ่มใหญ่ / ตัวอักษรเน้น)
  static const Color primaryLight = Color(0xFFCBB8F7); // ม่วงอ่อน (ปุ่ม "ส่ง OTP")
  static const Color background = Color(0xFFEDE9FB);   // พื้นหลังลาเวนเดอร์
  static const Color field = Color(0xFFFFFFFF);        // พื้นช่องกรอกข้อมูล (ขาว)
  static const Color textDark = Color(0xFF2B2B3A);     // ตัวหนังสือเข้ม
  static const Color textGrey = Color(0xFF9A97A8);     // ตัวหนังสือจาง (คำอธิบาย / placeholder)
  static const Color border = Color(0xFFE6E2F2);       // เส้นขอบช่องกรอก
}