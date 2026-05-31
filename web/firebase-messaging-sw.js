importScripts('https://www.gstatic.com/firebasejs/9.10.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.10.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAYYoBmpapnbsw4L-p7BWvJWYt5FZxNFu8',
  appId: '1:474454721171:web:032c21180b7176a42f0366',
  messagingSenderId: '474454721171',
  projectId: 'ngekos-app-project',
  authDomain: 'ngekos-app-project.firebaseapp.com',
  storageBucket: 'ngekos-app-project.firebasestorage.app',
  measurementId: 'G-K7ZE98PR4E',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((message) => {
  const notification = message.notification || {};
  const title = notification.title || message.data?.title || 'Notifikasi baru';
  const options = {
    body: notification.body || message.data?.body || 'Ada update baru.',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: message.data || {},
  };

  self.registration.showNotification(title, options);
});
