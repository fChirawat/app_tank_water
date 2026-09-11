// Service worker สำหรับรับแจ้งเตือน (push) ตอนแท็บปิด/พับอยู่เบื้องหลัง (เว็บ)
//
// ค่า config ด้านล่างต้องตรงกับ lib/firebase_options.dart (DefaultFirebaseOptions.web)
// เอามาจาก Firebase Console -> Project settings -> General -> Your apps -> Web app

importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'TODO-ใส่ค่าจริงจาก Firebase Console',
  appId: 'TODO-ใส่ค่าจริงจาก Firebase Console',
  messagingSenderId: '358801425890',
  projectId: 'water-app-bunrueang',
  authDomain: 'water-app-bunrueang.firebaseapp.com',
  storageBucket: 'water-app-bunrueang.firebasestorage.app',
});

firebase.messaging();
