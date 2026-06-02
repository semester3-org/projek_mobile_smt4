# App Branding

Folder ini untuk menyimpan source logo aplikasi sebelum di-generate menjadi asset Android/iOS/Web.

Yang aman diubah untuk nama dan logo aplikasi:

- `android/app/src/main/res/values/strings.xml`
  - `app_name` adalah nama aplikasi Android.
- `lib/main.dart`
  - `MaterialApp.title` memengaruhi nama task/recent apps Flutter.
- `android/app/src/main/res/mipmap-*/ic_launcher.png`
  - launcher icon Android untuk ukuran density berbeda.
- `android/app/src/main/res/drawable/ic_notification.xml`
  - small icon notifikasi Android/FCM. Ikon ini harus bentuk solid putih.
- `android/app/src/main/res/values/colors.xml`
  - `notification_color` untuk aksen notifikasi FCM.
- `web/index.html` dan `web/icons/*`
  - dipakai kalau build Flutter Web.

Yang jangan diubah hanya untuk rebranding visual:

- package name Android (`com.example.projek_mobile`)
- nama database
- nama tabel
- endpoint backend
- Firebase project id / google-services.json

Mengubah nama app tidak mengubah backend atau database selama package name dan endpoint tetap sama.
