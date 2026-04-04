// نسخة قالب: انسخ إلى firebase-messaging-sw.js واملأ القيم من .env
// أو شغّل: node scripts/generate-firebase-sw.js
importScripts('https://www.gstatic.com/firebasejs/10.9.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.9.0/firebase-messaging-compat.js');

const firebaseConfig = {
  apiKey: "__FIREBASE_WEB_API_KEY__",
  authDomain: "__FIREBASE_WEB_AUTH_DOMAIN__",
  projectId: "__FIREBASE_WEB_PROJECT_ID__",
  storageBucket: "__FIREBASE_WEB_STORAGE_BUCKET__",
  messagingSenderId: "__FIREBASE_WEB_MESSAGING_SENDER_ID__",
  appId: "__FIREBASE_WEB_APP_ID__",
  measurementId: "__FIREBASE_WEB_MEASUREMENT_ID__"
};
const app = firebase.initializeApp(firebaseConfig);
const messaging = firebase.messaging();

const _kDebugSw =
  self.location.hostname === 'localhost' ||
  self.location.hostname === '127.0.0.1';

messaging.onBackgroundMessage(function(payload) {
  if (_kDebugSw) {
    console.log('[firebase-messaging-sw.js] Received background message ', payload);
  }
  // إن وُجد حقل `notification` في الحمولة، يعرض FCM للويب الإشعار تلقائياً.
  // استدعاء showNotification هنا يضاعف الإشعار (مرتين لنفس الرسالة).
  if (payload.notification && payload.notification.title) {
    return Promise.resolve();
  }
  const title = (payload.data && payload.data.title) || 'إشعار';
  const body = (payload.data && payload.data.body) || '';
  return self.registration.showNotification(title, { body: body });
});
