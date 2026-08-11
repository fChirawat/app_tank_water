import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'session.dart';

// ===== จัดการแจ้งเตือน (Push Notification) =====
//
// หน้าที่:
// 1) ขออนุญาตส่งแจ้งเตือนจากผู้ใช้
// 2) ขอ "รหัสเครื่อง" (token) จาก Firebase
// 3) สร้าง notification channel ความสำคัญสูง (ให้เด้งเด่นกลางจอ)
// 4) แสดงแจ้งเตือนแบบเด้ง (heads-up) ตอนแอปเปิดอยู่

// ตัวแสดงแจ้งเตือนบนเครื่อง (local notification)
final FlutterLocalNotificationsPlugin _localNotif =
    FlutterLocalNotificationsPlugin();

// ช่องแจ้งเตือนความสำคัญสูง — ต้องตรงกับ channel_id ที่ server ส่งมา
// ===== เสียงพิเศษ water_alert =====
const AndroidNotificationChannel _alertChannel = AndroidNotificationChannel(
  'water_app_alert_channel',
  'การแจ้งเตือนสำคัญ',
  description: 'ประกาศและเรื่องใหม่ที่ต้องดำเนินการ',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  sound: RawResourceAndroidNotificationSound('water_alert'),
);

// ===== เสียงแจ้งเตือนปกติ =====
const AndroidNotificationChannel _defaultChannel =
    AndroidNotificationChannel(
  'water_app_default_channel',
  'การแจ้งเตือนทั่วไป',
  description: 'แจ้งเตือนสถานะงานทั่วไป',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

// ===== ตัวรับแจ้งเตือนตอนแอปปิด/อยู่เบื้องหลัง =====
// ต้องอยู่นอกคลาส และเป็นฟังก์ชันระดับบนสุด (Flutter บังคับ)
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // ตอนแอปปิด ถ้า payload มี notification อยู่แล้ว Android จะแสดงให้เอง
  debugPrint('แจ้งเตือนเข้า (แอปปิดอยู่): ${message.notification?.title}');
}

class PushService {
  // รหัสเครื่องล่าสุดที่ได้มา
  static String? token;

  // ตั้งค่าตอนเปิดแอป
  static Future<void> init() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // บอก Firebase ว่าให้ใช้ฟังก์ชันไหนตอนแอปปิด
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

      // 1) ขออนุญาตแจ้งเตือน (Android 13+ / iOS จำเป็น)
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('สถานะอนุญาตแจ้งเตือน: ${settings.authorizationStatus}');

      // 2) ตั้งค่าตัวแสดงแจ้งเตือนบนเครื่อง + สร้าง channel ความสำคัญสูง
      await _setupLocalNotifications();

      // 3) ขอรหัสเครื่อง
      token = await messaging.getToken();
      debugPrint('รหัสเครื่อง (FCM token): $token');

      // 4) ถ้า Firebase เปลี่ยนรหัสให้ใหม่ ก็รับไว้
      messaging.onTokenRefresh.listen((newToken) {
        token = newToken;
        debugPrint('รหัสเครื่องเปลี่ยนเป็น: $newToken');
        syncToken();
      });

      // 5) รับแจ้งเตือนตอนเปิดแอปค้างอยู่ -> แสดงเป็น heads-up เอง
      // (ตอนแอปเปิดอยู่ Android จะไม่เด้งให้อัตโนมัติ ต้องสั่งแสดงเอง)
      FirebaseMessaging.onMessage.listen((message) {
        debugPrint('ได้รับแจ้งเตือน: ${message.notification?.title}');
        _showHeadsUp(message);
      });
    } catch (e) {
      debugPrint('ตั้งค่าแจ้งเตือนไม่สำเร็จ: $e');
    }
  }

  // ตั้งค่าตัวแสดงแจ้งเตือน + สร้าง channel
  static Future<void> _setupLocalNotifications() async {
    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(
      android: androidInit,
    );

    await _localNotif.initialize(
      settings: initSettings,
    );

    final android = _localNotif.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await android?.createNotificationChannel(_alertChannel);
    await android?.createNotificationChannel(_defaultChannel);
  }

    // แสดงแจ้งเตือนแบบเด้ง (heads-up) ตอนแอปเปิดอยู่
  static Future<void> _showHeadsUp(RemoteMessage message) async {
    final notif = message.notification;
    if (notif == null) return;

    // Server จะส่งค่านี้มาให้
    final useWaterAlert =
        message.data['useWaterAlert'] == 'true';

    final channel =
        useWaterAlert ? _alertChannel : _defaultChannel;

    await _localNotif.show(
      id: message.messageId?.hashCode ??
          DateTime.now()
              .millisecondsSinceEpoch
              .remainder(100000),
      title: notif.title,
      body: notif.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,

          // ใช้เสียงพิเศษเฉพาะ alert
          sound: useWaterAlert
              ? const RawResourceAndroidNotificationSound(
                  'water_alert',
                )
              : null,

          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  // ===== ส่งรหัสเครื่องขึ้นเซิร์ฟเวอร์ =====
  static Future<void> syncToken() async {
    if (AppSession.accessToken == null || token == null) return;
    try {
      await Supabase.instance.client.functions.invoke(
        'complaints',
        body: {
          'accessToken': AppSession.accessToken,
          'action': 'save-token',
          'deviceToken': token,
        },
      );
      debugPrint('ส่งรหัสเครื่องขึ้นเซิร์ฟเวอร์แล้ว');
    } catch (e) {
      debugPrint('ส่งรหัสเครื่องไม่สำเร็จ: $e');
    }
  }

  // ===== ลบรหัสเครื่องออกจากเซิร์ฟเวอร์ (ตอนออกจากระบบ) =====
  static Future<void> removeToken() async {
    if (AppSession.accessToken == null || token == null) return;
    try {
      await Supabase.instance.client.functions.invoke(
        'complaints',
        body: {
          'accessToken': AppSession.accessToken,
          'action': 'delete-token',
          'deviceToken': token,
        },
      );
    } catch (_) {}
  }
}