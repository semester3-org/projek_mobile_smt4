import '../../core/api_service.dart';
import '../../models/billing_record.dart';
import '../../models/notification.dart';
import '../../models/order.dart';
import '../../models/user_dashboard.dart';
import '../../models/user_merchant.dart';
import '../../models/user_profile.dart';
import 'kos_repository.dart' show RepoResult;

class UserRepository {
  UserRepository._();

  static Future<RepoResult<UserDashboard>> getDashboard({
    required String displayName,
  }) async {
    final res = await ApiService.get('api/user_dashboard');

    if (!res.success) {
      return RepoResult.ok(UserDashboard.fallback(displayName));
    }

    try {
      final data = res.data!['data'] as Map<String, dynamic>;
      return RepoResult.ok(UserDashboard.fromJson(data));
    } catch (_) {
      return RepoResult.ok(UserDashboard.fallback(displayName));
    }
  }

  static Future<RepoResult<List<UserMerchant>>> getMerchants(String type) async {
    final res = await ApiService.get(
      'api/user_merchants',
      queryParams: {'type': type},
    );

    if (!res.success) {
      return RepoResult.ok(_fallbackMerchants(type));
    }

    try {
      final list = (res.data!['data'] as List)
          .map((e) => UserMerchant.fromJson(e as Map<String, dynamic>))
          .toList();
      return RepoResult.ok(list.isEmpty ? _fallbackMerchants(type) : list);
    } catch (_) {
      return RepoResult.ok(_fallbackMerchants(type));
    }
  }

  static Future<RepoResult<UserMerchant>> getMerchantDetail({
    required String type,
    required String id,
  }) async {
    final res = await ApiService.get(
      'api/user_merchants',
      queryParams: {'type': type, 'id': id},
    );

    if (!res.success) {
      return RepoResult.ok(_fallbackMerchants(type).first);
    }

    try {
      final data = res.data!['data'] as Map<String, dynamic>;
      return RepoResult.ok(UserMerchant.fromJson(data));
    } catch (_) {
      return RepoResult.ok(_fallbackMerchants(type).first);
    }
  }

  static Future<RepoResult<List<BillingRecord>>> getBillings() async {
    final res = await ApiService.get('api/user_billings');

    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal memuat tagihan');
    }

    try {
      final list = (res.data!['data'] as List)
          .map((e) => BillingRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      return RepoResult.ok(list);
    } catch (_) {
      return const RepoResult.fail('Gagal membaca data tagihan');
    }
  }

  static Future<RepoResult<List<Order>>> getOrders() async {
    final res = await ApiService.get('api/user_orders');

    if (!res.success) {
      return RepoResult.ok(_fallbackOrders());
    }

    try {
      final list = (res.data!['data'] as List)
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList();
      return RepoResult.ok(list.isEmpty ? _fallbackOrders() : list);
    } catch (_) {
      return RepoResult.ok(_fallbackOrders());
    }
  }

  static Future<RepoResult<List<AppNotification>>> getNotifications() async {
    final res = await ApiService.get('api/user_notifications');

    if (!res.success) {
      return RepoResult.ok(_fallbackNotifications());
    }

    try {
      final list = (res.data!['data'] as List)
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();
      return RepoResult.ok(list.isEmpty ? _fallbackNotifications() : list);
    } catch (_) {
      return RepoResult.ok(_fallbackNotifications());
    }
  }

  static Future<RepoResult<UserProfile>> getProfile({
    required String displayName,
    required String email,
    required String role,
  }) async {
    final res = await ApiService.get('api/user_profile');

    if (!res.success) {
      return RepoResult.ok(UserProfile(
        id: '',
        email: email,
        displayName: displayName,
        role: role,
      ));
    }

    try {
      final data = res.data!['data'] as Map<String, dynamic>;
      return RepoResult.ok(UserProfile.fromJson(data));
    } catch (_) {
      return RepoResult.ok(UserProfile(
        id: '',
        email: email,
        displayName: displayName,
        role: role,
      ));
    }
  }

  static Future<RepoResult<UserProfile>> connectKosCode(String accessCode) async {
    final res = await ApiService.post('api/user_profile', {
      'accessCode': accessCode,
    });

    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal menyambungkan kode kos');
    }

    try {
      final data = res.data!['data'] as Map<String, dynamic>;
      return RepoResult.ok(UserProfile.fromJson(data));
    } catch (_) {
      return RepoResult.fail('Gagal membaca data profil terbaru');
    }
  }

  static Future<RepoResult<bool>> submitMerchantRating({
    required String type,
    required String merchantId,
    required int rating,
    required String comment,
  }) async {
    final res = await ApiService.post('api/user_ratings', {
      'type': type,
      'merchantId': merchantId,
      'rating': rating,
      'comment': comment,
    });

    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal mengirim ulasan');
    }

    return RepoResult.ok(true);
  }

  static List<UserMerchant> _fallbackMerchants(String type) {
    switch (type) {
      case 'laundry':
        return const [
          UserMerchant(
            id: 'l1',
            type: 'laundry',
            name: 'Clean & Fresh Laundry',
            subtitle: 'Antar jemput dan express 6 jam',
            address: 'Jl. Sudirman No. 45, Jakarta Pusat',
            rating: 4.8,
            reviewCount: 120,
            distanceKm: 0.8,
            imageUrl:
                'https://images.unsplash.com/photo-1582735689369-4fe89db7114c?w=900',
            status: 'Tersedia',
            tags: ['ANTAR JEMPUT', 'EXPRESS 6 JAM'],
            minPrice: 8000,
            priceUnit: '/kg',
            eta: '25-30 mnt',
            openHours: '08:00 - 21:00',
            description:
                'Laundry cepat dengan layanan cuci lipat, setrika, satuan, dan antar jemput area Sentra Ruang.',
            phone: '+62 812-3456-7890',
            email: 'halo@cleanfresh.id',
            menuItems: [
              MerchantMenuItem(
                id: 'l1-s1',
                name: 'Cuci Lipat (Kg)',
                description: 'Regular',
                price: 8000,
                imageUrl:
                    'https://images.unsplash.com/photo-1517677200551-7920f4b53198?w=400',
              ),
              MerchantMenuItem(
                id: 'l1-s2',
                name: 'Cuci Setrika (Kg)',
                description: 'Rapi dan wangi',
                price: 12000,
                imageUrl:
                    'https://images.unsplash.com/photo-1521656693074-0ef32e80a5d5?w=400',
              ),
            ],
            reviews: [
              MerchantReview(
                reviewer: 'Siska Amelia',
                rating: 5,
                comment:
                    'Hasil cucian sangat bersih dan wangi. Pengirimannya juga cepat, kurirnya ramah.',
                timeLabel: '2 hari yang lalu',
              ),
              MerchantReview(
                reviewer: 'Budi Santoso',
                rating: 4,
                comment:
                    'Layanan oke, lipatan rapi sekali. Secara keseluruhan puas dengan hasilnya.',
                timeLabel: '1 minggu yang lalu',
              ),
            ],
          ),
          UserMerchant(
            id: 'l2',
            type: 'laundry',
            name: 'Kiloan Express',
            subtitle: 'Cuci sepatu dan kiloan cepat',
            address: 'Jl. Melati No. 18, Jakarta Selatan',
            rating: 4.5,
            reviewCount: 80,
            distanceKm: 1.2,
            imageUrl:
                'https://images.unsplash.com/photo-1626806819282-2c1dc01a5e0c?w=900',
            status: 'Tersedia',
            tags: ['CUCI SEPATU', 'KILOAN'],
            minPrice: 7500,
            priceUnit: '/kg',
            eta: '35-45 mnt',
            openHours: '07:00 - 22:00',
            description:
                'Pilihan praktis untuk cuci kiloan, sepatu, dan perawatan pakaian harian.',
            phone: '+62 812-1111-2244',
            email: 'cs@kiloanexpress.id',
            menuItems: [],
            reviews: [],
          ),
        ];
      case 'catering':
        return const [
          UserMerchant(
            id: 'cat1',
            type: 'catering',
            name: 'Green Garden Catering',
            subtitle: 'Masakan sehat dan diet kalori',
            address: 'Jl. Kemang Raya No. 9, Jakarta Selatan',
            rating: 4.8,
            reviewCount: 124,
            distanceKm: 1.2,
            imageUrl:
                'https://images.unsplash.com/photo-1543353071-873f17a7a088?w=900',
            status: 'Tersedia',
            tags: ['DIET SEHAT', 'HARIAN'],
            minPrice: 25000,
            priceUnit: '',
            eta: '25-30 mnt',
            openHours: '08:00 - 20:00',
            description:
                'Menu harian bergizi untuk penghuni kos, cocok untuk makan siang dan makan malam.',
            phone: '+62 812-4455-7788',
            email: 'order@greengarden.id',
            menuItems: [
              MerchantMenuItem(
                id: 'cat1-m1',
                name: 'Paket Nasi Kotak Premium',
                description: 'Lengkap dengan 5 lauk pauk',
                price: 45000,
                imageUrl:
                    'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?w=400',
              ),
              MerchantMenuItem(
                id: 'cat1-m2',
                name: 'Catering Diet Sehat',
                description: 'Rendah kalori, tinggi protein',
                price: 55000,
                imageUrl:
                    'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=400',
              ),
            ],
            reviews: [
              MerchantReview(
                reviewer: 'Anita Wijaya',
                rating: 5,
                comment:
                    'Makanannya enak dan porsinya pas. Kemasan juga sangat rapi.',
                timeLabel: '2 jam yang lalu',
              ),
              MerchantReview(
                reviewer: 'Budi Santoso',
                rating: 4.5,
                comment:
                    'Pengirimannya tepat waktu. Menu catering dietnya membantu pola makan.',
                timeLabel: 'Kemarin',
              ),
            ],
          ),
          UserMerchant(
            id: 'cat2',
            type: 'catering',
            name: 'Dapur Nusantara',
            subtitle: 'Masakan tradisional Indonesia',
            address: 'Jl. Panglima Polim No. 11',
            rating: 4.9,
            reviewCount: 210,
            distanceKm: 2.5,
            imageUrl:
                'https://images.unsplash.com/photo-1512058564366-18510be2db19?w=900',
            status: 'Tersedia',
            tags: ['NASI BOX', 'PRASMANAN'],
            minPrice: 35000,
            priceUnit: '',
            eta: '35-45 mnt',
            openHours: '07:00 - 21:00',
            description: 'Menu nusantara untuk kebutuhan harian dan acara kos.',
            phone: '+62 812-9988-1010',
            email: 'dapur@nusantara.id',
            menuItems: [],
            reviews: [],
          ),
        ];
      default:
        return const [
          UserMerchant(
            id: 'c1',
            type: 'cafe',
            name: 'Kopi Senja',
            subtitle: 'Coffee & workspace',
            address: 'Sentra Ruang Ground Floor, Blok A1',
            rating: 4.8,
            reviewCount: 124,
            distanceKm: 0.8,
            imageUrl:
                'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=900',
            status: 'Buka',
            tags: ['WiFi Cepat', 'Stopkontak', 'Outdoor'],
            minPrice: 18000,
            priceUnit: '',
            eta: '',
            openHours: '08:00 - 22:00',
            description:
                'Ruang komunal yang menggabungkan kenikmatan kopi artisan dengan kenyamanan ruang kerja.',
            phone: '+62 812-3456-7890',
            email: 'halo@kopisenja.com',
            menuItems: [
              MerchantMenuItem(
                id: 'c1-m1',
                name: 'Signature Coffee',
                description: 'Kopi susu gula aren',
                price: 18000,
                imageUrl:
                    'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=400',
              ),
              MerchantMenuItem(
                id: 'c1-m2',
                name: 'Croissant Butter',
                description: 'Fresh baked',
                price: 22000,
                imageUrl:
                    'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400',
              ),
            ],
            reviews: [
              MerchantReview(
                reviewer: 'Andi Wijaya',
                rating: 5,
                comment:
                    'Tempat paling nyaman buat WFC di area Sentra Ruang. Kopinya enak.',
                timeLabel: '2 hari lalu',
              ),
              MerchantReview(
                reviewer: 'Siti Rahma',
                rating: 4,
                comment:
                    'Suasananya tenang banget, cocok buat fokus kerja.',
                timeLabel: '1 minggu lalu',
              ),
            ],
          ),
          UserMerchant(
            id: 'c2',
            type: 'cafe',
            name: 'Ruang Kopi',
            subtitle: 'Tenang dan parkir luas',
            address: 'Jl. Cendana No. 21',
            rating: 4.6,
            reviewCount: 85,
            distanceKm: 1.2,
            imageUrl:
                'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=900',
            status: 'Buka',
            tags: ['AC', 'Tenang', 'Parkir Luas'],
            minPrice: 20000,
            priceUnit: '',
            eta: '',
            openHours: '09:00 - 22:00',
            description: 'Kafe santai dengan area duduk luas dan Wi-Fi stabil.',
            phone: '+62 811-2222-3344',
            email: 'halo@ruangkopi.id',
            menuItems: [],
            reviews: [],
          ),
        ];
    }
  }

  static List<Order> _fallbackOrders() {
    return [
      Order(
        id: 'SR-CATER-88219',
        merchantName: 'Dapur Nusantara',
        service: 'catering',
        orderDate: DateTime(2023, 10, 24, 14, 20),
        totalAmount: 90000,
        status: 'pending',
        paymentMethod: 'GOPAY',
        items: [
          OrderItem(
            name: 'Nasi Goreng Spesial Nusantara',
            quantity: 2,
            price: 35000,
            subtotal: 70000,
          ),
          OrderItem(
            name: 'Es Jeruk Peras Murni',
            quantity: 1,
            price: 15000,
            subtotal: 15000,
          ),
        ],
      ),
      Order(
        id: 'SR-LAUNDRY-001',
        merchantName: 'Clean & Fresh Laundry Express',
        service: 'laundry',
        orderDate: DateTime(2023, 10, 24, 14, 20),
        totalAmount: 70000,
        status: 'pending',
        paymentMethod: 'GOPAY',
        items: [
          OrderItem(
            name: 'Cuci Lipat (Regular)',
            quantity: 5,
            price: 8000,
            subtotal: 40000,
          ),
          OrderItem(
            name: 'Cuci Satuan - Jaket',
            quantity: 1,
            price: 25000,
            subtotal: 25000,
          ),
        ],
      ),
    ];
  }

  static List<AppNotification> _fallbackNotifications() {
    return [
      AppNotification(
        id: 'notif-1',
        title: 'Pembayaran Laundry Berhasil',
        message:
            'Pembayaran untuk layanan laundry #L-9928 senilai Rp 45.000 telah kami terima. Pakaian Anda sedang diproses.',
        type: 'payment',
        status: 'baru',
        createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
      ),
      AppNotification(
        id: 'notif-2',
        title: 'Pesanan Catering Gagal',
        message:
            'Maaf, pesanan katering untuk makan siang hari ini dibatalkan karena ketersediaan menu. Saldo Anda telah dikembalikan.',
        type: 'catering',
        status: 'dibaca',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      AppNotification(
        id: 'notif-3',
        title: 'Tagihan Kos Menunggu',
        message:
            'Masa sewa kamar Anda akan berakhir dalam 3 hari. Segera lakukan pembayaran untuk bulan depan.',
        type: 'room',
        status: 'dibaca',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        hasAction: true,
        actionButtonText: 'Bayar Sekarang',
      ),
      AppNotification(
        id: 'notif-4',
        title: 'Promo Khusus Member',
        message:
            'Dapatkan diskon 20% untuk layanan cleaning service setiap akhir pekan selama bulan ini.',
        type: 'promo',
        status: 'dibaca',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];
  }
}
