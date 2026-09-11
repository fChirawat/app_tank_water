import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

// ===== ค่า config Firebase สำหรับเว็บ =====
//
// Android/iOS ไม่ต้องใช้ไฟล์นี้ (อ่านจาก google-services.json /
// GoogleService-Info.plist โดยตรงอยู่แล้ว ผ่าน native plugin)
//
// เว็บไม่มีไฟล์ native ให้อ่าน ต้องส่งค่านี้ตรงๆ ตอนเรียก Firebase.initializeApp()
//
// วิธีหาค่าจริง:
//   1) ไปที่ Firebase Console -> โปรเจกต์ "water-app-bunrueang" -> Project settings
//   2) เลื่อนลงมาที่ "Your apps" -> ถ้ายังไม่มีแอปเว็บ กด "Add app" -> เลือกไอคอนเว็บ (</>)
//   3) ตั้งชื่อแอปอะไรก็ได้ (เช่น "water_app web") -> ไม่ต้องติ๊ก Firebase Hosting
//   4) คัดลอกค่าจาก firebaseConfig ที่ขึ้นมาใส่แทนค่า TODO ด้านล่างให้ครบทุกช่อง
//   5) (สำหรับ push บนเว็บ) ไปที่ Project settings -> Cloud Messaging ->
//      "Web configuration" -> กด "Generate key pair" แล้วเอาค่าไปใส่ที่
//      AppConfig.fcmVapidKey ใน lib/config.dart
//
// ก่อนใส่ค่าจริง เว็บจะยังใช้งานได้ปกติ (ล็อกอิน/ดูข้อมูล) แค่ระบบแจ้งเตือน
// push จะยังไม่ทำงาน
class DefaultFirebaseOptions {
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'TODO-ใส่ค่าจริงจาก Firebase Console',
    appId: 'TODO-ใส่ค่าจริงจาก Firebase Console',
    messagingSenderId: '358801425890',
    projectId: 'water-app-bunrueang',
    authDomain: 'water-app-bunrueang.firebaseapp.com',
    storageBucket: 'water-app-bunrueang.firebasestorage.app',
  );
}
