-- phpMyAdmin SQL Dump
-- version 5.2.0
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Generation Time: Apr 26, 2026 at 05:22 PM
-- Server version: 8.0.30
-- PHP Version: 8.3.30

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `projek_kos`
--

-- --------------------------------------------------------

--
-- Table structure for table `cafe_places`
--

CREATE TABLE `cafe_places` (
  `id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `vibe` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `rating` decimal(3,2) NOT NULL DEFAULT '0.00',
  `image_url` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `distance_km` decimal(5,2) NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `merchant_id` varchar(36) COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `cafe_places`
--

INSERT INTO `cafe_places` (`id`, `name`, `vibe`, `rating`, `image_url`, `distance_km`, `created_at`, `updated_at`, `merchant_id`) VALUES
('c1', 'Kopi Kenangan', 'Modern Casual', '4.80', 'https://images.unsplash.com/photo-15210174322fbe91904029cad6cbee1ab2409b1d?w=800', '0.30', '2026-04-19 17:06:30', '2026-04-19 17:06:30', NULL),
('c2', 'Warung Kopi Lesehan', 'Traditional', '4.50', 'https://images.unsplash.com/photo-1570968915860-54d8d3532ca0?w=800', '0.80', '2026-04-19 17:06:30', '2026-04-19 17:06:30', NULL),
('c3', 'Kedai Kopi Artisan', 'Minimalist', '4.90', 'https://images.unsplash.com/photo-1511537190424-3c373c0fbead?w=800', '0.50', '2026-04-19 17:06:30', '2026-04-19 17:06:30', NULL),
('c4', 'Café Bintang 5', 'Luxury', '4.70', 'https://images.unsplash.com/photo-1495521821757-a1efb6729352?w=800', '1.20', '2026-04-19 17:06:30', '2026-04-19 17:06:30', NULL),
('c5', 'Teras Kopi Rumahan', 'Cozy', '4.60', 'https://images.unsplash.com/photo-1442512595331-e89e73853f31?w=800', '0.60', '2026-04-19 17:06:30', '2026-04-19 17:06:30', NULL),
('c6', 'Espresso House', 'Contemporary', '4.80', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800', '0.90', '2026-04-19 17:06:30', '2026-04-19 17:06:30', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `catering_places`
--

CREATE TABLE `catering_places` (
  `id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `address` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `specialty` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `rating` decimal(3,2) NOT NULL DEFAULT '0.00',
  `distance_km` decimal(5,2) NOT NULL,
  `image_url` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `min_order_portion` int NOT NULL DEFAULT '20',
  `merchant_id` varchar(36) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `facilities`
--

CREATE TABLE `facilities` (
  `id` int NOT NULL,
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by` varchar(36) COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `facilities`
--

INSERT INTO `facilities` (`id`, `name`, `created_at`, `created_by`) VALUES
(1, 'WiFi', '2026-04-19 17:06:30', NULL),
(2, 'AC', '2026-04-19 17:06:30', NULL),
(3, 'Kamar mandi dalam', '2026-04-19 17:06:30', NULL),
(4, 'Dapur bersama', '2026-04-19 17:06:30', NULL),
(5, 'Parkir motor', '2026-04-19 17:06:30', NULL),
(6, 'Laundry', '2026-04-19 17:06:30', NULL),
(7, 'Keamanan 24 jam', '2026-04-19 17:06:30', NULL),
(8, 'Kulkas bersama', '2026-04-19 17:06:30', NULL),
(9, 'Teras rokok', '2026-04-19 17:06:30', NULL),
(10, 'Gazebo', '2026-04-19 17:06:30', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `kos_facilities`
--

CREATE TABLE `kos_facilities` (
  `id` int NOT NULL,
  `kos_id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `facility_id` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `kos_facilities`
--

INSERT INTO `kos_facilities` (`id`, `kos_id`, `facility_id`) VALUES
(1, 'k1', 1),
(2, 'k1', 2),
(3, 'k1', 3),
(4, 'k1', 5),
(5, 'k2', 1),
(6, 'k2', 3),
(7, 'k2', 4),
(8, 'k3', 1),
(9, 'k3', 2),
(10, 'k3', 3),
(12, 'k3', 6),
(11, 'k3', 7),
(13, 'k4', 1),
(14, 'k4', 2),
(15, 'k4', 3),
(16, 'k4', 5),
(17, 'k4', 6),
(18, 'k5', 1),
(19, 'k5', 2),
(20, 'k5', 3),
(22, 'k5', 6),
(21, 'k5', 7),
(23, 'k5', 8);

-- --------------------------------------------------------

--
-- Table structure for table `kos_images`
--

CREATE TABLE `kos_images` (
  `id` int NOT NULL,
  `kos_id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `image_url` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `display_order` int DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `kos_images`
--

INSERT INTO `kos_images` (`id`, `kos_id`, `image_url`, `display_order`, `created_at`) VALUES
(1, 'k1', 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800', 1, '2026-04-19 17:06:30'),
(2, 'k1', 'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800', 2, '2026-04-19 17:06:30'),
(3, 'k1', 'https://images.unsplash.com/photo-1584622650111-993a426fbf80?w=800', 3, '2026-04-19 17:06:30'),
(4, 'k2', 'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800', 1, '2026-04-19 17:06:30'),
(5, 'k2', 'https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=800', 2, '2026-04-19 17:06:30'),
(6, 'k3', 'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800', 1, '2026-04-19 17:06:30'),
(7, 'k3', 'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?w=800', 2, '2026-04-19 17:06:30'),
(8, 'k4', 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800', 1, '2026-04-19 17:06:30'),
(9, 'k4', 'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800', 2, '2026-04-19 17:06:30'),
(10, 'k5', 'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800', 1, '2026-04-19 17:06:30'),
(11, 'k5', 'https://images.unsplash.com/photo-1584622650111-993a426fbf80?w=800', 2, '2026-04-19 17:06:30');

-- --------------------------------------------------------

--
-- Table structure for table `kos_listings`
--

CREATE TABLE `kos_listings` (
  `id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `owner_id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `access_code` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `location` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `price_per_month` int NOT NULL,
  `rating` decimal(3,2) NOT NULL DEFAULT '0.00',
  `owner_contact` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `kos_listings`
--

INSERT INTO `kos_listings` (`id`, `owner_id`, `access_code`, `title`, `location`, `description`, `price_per_month`, `rating`, `owner_contact`, `created_at`, `updated_at`) VALUES
('254952fa-366a-417f-bbf7-43126254772c', '8b7bb846-be70-4a29-8fd1-f29d9f248f8d', 'KOS-254952', 'kosku', 'disini', 'p', 5000000, '0.00', '0812345678', '2026-04-26 14:21:28', '2026-04-26 14:21:28'),
('k1', 'user_owner_1', 'KOS-K1-7971', 'Kos Hijau Asri', 'Jl. Melati No. 12, Sleman', 'Kos nyaman dengan taman kecil di depan. Cocok untuk mahasiswa dan pekerja. Lingkungan tenang.', 1200000, '4.80', '0812-3456-7890', '2026-04-19 17:06:30', '2026-04-23 07:05:30'),
('k2', 'user_owner_2', 'KOS-K2-9510', 'Kost Minimalis Putih', 'Jl. Kenanga 5, Depok', 'Desain minimalis, bersih, dekat kampus dan angkot.', 950000, '4.50', '0813-9999-0001', '2026-04-19 17:06:30', '2026-04-23 07:05:30'),
('k3', 'user_owner_3', 'KOS-K3-4637', 'Green House Residence', 'Jl. Merpati 88, Condongcatur', 'Fasilitas lengkap, akses kartu, area joging dekat kos.', 1500000, '4.90', '0821-1111-2222', '2026-04-19 17:06:30', '2026-04-23 07:05:30'),
('k4', 'user_owner_1', 'KOS-K4-2655', 'Kos Nyaman Dian', 'Jl. Cendana 45, Yogyakarta', 'Kos yang sangat nyaman dengan lokasi strategis dekat dengan berbagai tempat umum.', 850000, '4.60', '0812-3456-7890', '2026-04-19 17:06:30', '2026-04-23 07:05:30'),
('k5', 'user_owner_2', 'KOS-K5-7366', 'Rumah Kost Makmur', 'Jl. Sudirman 23, Jakarta', 'Rumah kost dengan fasilitas modern dan lokasi premium.', 2000000, '4.70', '0813-9999-0001', '2026-04-19 17:06:30', '2026-04-23 07:05:30');

-- --------------------------------------------------------

--
-- Table structure for table `kos_rooms`
--

CREATE TABLE `kos_rooms` (
  `id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `kos_id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `room_number` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Contoh: A1, B2, 101',
  `room_type` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Contoh: Standard, Deluxe, AC',
  `price_per_month` int NOT NULL,
  `rental_type` enum('daily','monthly','yearly') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'monthly',
  `status` enum('available','occupied','maintenance') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'available',
  `max_occupant` int NOT NULL DEFAULT '1',
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `kos_rooms`
--

INSERT INTO `kos_rooms` (`id`, `kos_id`, `room_number`, `room_type`, `price_per_month`, `rental_type`, `status`, `max_occupant`, `description`, `created_at`, `updated_at`) VALUES
('588ea0ad-708b-47df-90e1-6591b885c456', '254952fa-366a-417f-bbf7-43126254772c', 'A02', 'Standard Single', 300000, 'monthly', 'available', 1, NULL, '2026-04-26 15:35:22', '2026-04-26 15:35:22'),
('9455bdec-b0d5-4d0c-9d76-0d197b8db240', '254952fa-366a-417f-bbf7-43126254772c', 'A01', 'Standard Single', 200000, 'monthly', 'available', 1, NULL, '2026-04-26 15:19:28', '2026-04-26 15:19:28');

-- --------------------------------------------------------

--
-- Table structure for table `laundry_places`
--

CREATE TABLE `laundry_places` (
  `id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `address` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `rating` decimal(3,2) NOT NULL DEFAULT '0.00',
  `distance_km` decimal(5,2) NOT NULL,
  `image_url` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `open_hours` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `merchant_id` varchar(36) COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `laundry_places`
--

INSERT INTO `laundry_places` (`id`, `name`, `address`, `rating`, `distance_km`, `image_url`, `open_hours`, `created_at`, `updated_at`, `merchant_id`) VALUES
('l1', 'Laundry Fresh Express', 'Jl. Kaliurang Km 5', '4.70', '0.40', 'https://images.unsplash.com/photo-1582735689369-4fe89db7114c?w=800', '08:00 – 20:00', '2026-04-19 17:06:30', '2026-04-19 17:06:30', NULL),
('l2', 'Cuci Kilat Jaya', 'Jl. Gejayan No. 22', '4.40', '0.90', 'https://images.unsplash.com/photo-1517677200551-7920f4b53198?w=800', '07:00 – 21:00', '2026-04-19 17:06:30', '2026-04-19 17:06:30', NULL),
('l3', 'Bersih Laundry', 'Jl. Magelang 101', '4.60', '1.20', 'https://images.unsplash.com/photo-1626806819282-2c1dc01a5e0c?w=800', '07:00 – 22:00', '2026-04-19 17:06:30', '2026-04-19 17:06:30', NULL),
('l4', 'Laundry Cepat Saja', 'Jl. Affandi No. 55', '4.50', '0.70', 'https://images.unsplash.com/photo-1582735689369-4fe89db7114c?w=800', '08:00 – 20:30', '2026-04-19 17:06:30', '2026-04-19 17:06:30', NULL),
('l5', 'Express Wash Laundry', 'Jl. Diponegoro 12', '4.80', '1.00', 'https://images.unsplash.com/photo-1517677200551-7920f4b53198?w=800', '06:00 – 21:00', '2026-04-19 17:06:30', '2026-04-19 17:06:30', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `merchants`
--

CREATE TABLE `merchants` (
  `id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `user_id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `business_name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `merchant_type` enum('catering','cafe','laundry') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `phone` varchar(25) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `address` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `password_resets`
--

CREATE TABLE `password_resets` (
  `id` int NOT NULL,
  `email` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `token` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `expires_at` timestamp NOT NULL,
  `used_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `user_id` varchar(36) COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `password_resets`
--

INSERT INTO `password_resets` (`id`, `email`, `token`, `expires_at`, `used_at`, `created_at`, `user_id`) VALUES
(2, 'owner1@gmail.com', '81b4a719dd9cd8067c72d5c4904fbd727871c4c05568f6fe1aaa7bd6ade1f75d', '2026-04-22 09:56:38', NULL, '2026-04-22 15:56:38', 'user_owner_1');

-- --------------------------------------------------------

--
-- Table structure for table `payment_history`
--

CREATE TABLE `payment_history` (
  `id` int NOT NULL,
  `registration_id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `amount` int NOT NULL,
  `period_month` varchar(7) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Format: YYYY-MM, contoh: 2026-04',
  `payment_status` enum('unpaid','paid','overdue') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'unpaid',
  `payment_method` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'transfer, cash, dll',
  `proof_url` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci COMMENT 'Bukti transfer',
  `paid_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `registration_documents`
--

CREATE TABLE `registration_documents` (
  `id` int NOT NULL,
  `registration_id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `doc_type` enum('ktp','foto_diri','surat_keterangan','lainnya') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'ktp',
  `file_url` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `uploaded_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `room_facilities`
--

CREATE TABLE `room_facilities` (
  `room_id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `facility_id` int NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `room_facilities`
--

INSERT INTO `room_facilities` (`room_id`, `facility_id`, `created_at`) VALUES
('588ea0ad-708b-47df-90e1-6591b885c456', 2, '2026-04-26 15:35:22'),
('588ea0ad-708b-47df-90e1-6591b885c456', 4, '2026-04-26 15:35:22'),
('588ea0ad-708b-47df-90e1-6591b885c456', 6, '2026-04-26 15:35:22'),
('9455bdec-b0d5-4d0c-9d76-0d197b8db240', 2, '2026-04-26 15:41:32'),
('9455bdec-b0d5-4d0c-9d76-0d197b8db240', 4, '2026-04-26 15:41:32');

-- --------------------------------------------------------

--
-- Table structure for table `room_registrations`
--

CREATE TABLE `room_registrations` (
  `id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `user_id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `room_id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `kos_id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Redundan untuk query cepat',
  `status` enum('pending','active','completed','rejected','cancelled') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `start_date` date NOT NULL,
  `end_date` date DEFAULT NULL COMMENT 'NULL jika belum ditentukan',
  `notes` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci COMMENT 'Catatan dari user saat daftar',
  `reviewed_by` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'owner_id yang approve/reject',
  `reviewed_at` timestamp NULL DEFAULT NULL,
  `registered_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `email` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `password` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Password harus disimpan sebagai hash, bukan teks biasa',
  `display_name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `role` enum('admin','merchant','user','owner') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'user',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `email`, `password`, `display_name`, `role`, `created_at`, `updated_at`) VALUES
('2940a8c6-6a2d-4e11-8f15-347f8fdd63d6', 'test@gmail.com', '$2y$12$4KzresTejEcWprLSOCjVo.STFs.zvkthMk82CBNn571Wz7XeIExUK', 'Test User', 'user', '2026-04-26 13:06:32', '2026-04-26 13:06:32'),
('8b7bb846-be70-4a29-8fd1-f29d9f248f8d', 'naufalzyram@gmail.com', '$2y$12$C8Lr1KwhYxOtZYTSBAHesefwEz9wa1dCux3GGpWpawYq5K1W4Ytri', 'ramzuy', 'owner', '2026-04-22 17:01:40', '2026-04-22 17:01:40'),
('cf9ab5ba-6cb0-4368-bd51-9c036357980e', 'ramzynaufal77@gmail.com', '$2y$12$RMrfs.4t2W2uvLOf1UggEejJfYIu/SY4Tk2KSuoWVL90IoVr.nOfy', 'ramzy', 'owner', '2026-04-26 15:42:43', '2026-04-26 15:42:43'),
('user_admin', 'admin@gmail.com', '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9', 'Admin KosFinder', 'admin', '2026-04-19 17:06:30', '2026-04-19 17:06:30'),
('user_merchant_1', 'merchant1@gmail.com', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 'Dian Permata', 'merchant', '2026-04-19 17:06:30', '2026-04-19 17:06:30'),
('user_owner_1', 'owner1@gmail.com', '$2y$12$Nx/X1agj8Ijh.bzk9VqR4.Fibq3N39vCTz76GApfP9ph8eHox6fvq', 'Budi Santoso', 'owner', '2026-04-19 17:06:30', '2026-04-26 13:06:04'),
('user_owner_2', 'owner2@gmail.com', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 'Siti Nurhaliza', 'owner', '2026-04-19 17:06:30', '2026-04-19 17:06:30'),
('user_owner_3', 'owner3@gmail.com', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 'Rini Wijaya', 'owner', '2026-04-19 17:06:30', '2026-04-19 17:06:30'),
('user_user_1', 'user1@gmail.com', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 'Andi Prasetyo', 'user', '2026-04-19 17:06:30', '2026-04-19 17:06:30');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `cafe_places`
--
ALTER TABLE `cafe_places`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_rating` (`rating`),
  ADD KEY `idx_cafe_merchant_id` (`merchant_id`);

--
-- Indexes for table `catering_places`
--
ALTER TABLE `catering_places`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_rating` (`rating`),
  ADD KEY `idx_catering_merchant_id` (`merchant_id`);

--
-- Indexes for table `facilities`
--
ALTER TABLE `facilities`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `name` (`name`),
  ADD KEY `idx_facilities_created_by` (`created_by`);

--
-- Indexes for table `kos_facilities`
--
ALTER TABLE `kos_facilities`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_kos_facility` (`kos_id`,`facility_id`),
  ADD KEY `idx_kos_id` (`kos_id`),
  ADD KEY `idx_facility_id` (`facility_id`);

--
-- Indexes for table `kos_images`
--
ALTER TABLE `kos_images`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_kos_id` (`kos_id`);

--
-- Indexes for table `kos_listings`
--
ALTER TABLE `kos_listings`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_access_code` (`access_code`),
  ADD KEY `idx_owner_id` (`owner_id`),
  ADD KEY `idx_location` (`location`);
ALTER TABLE `kos_listings` ADD FULLTEXT KEY `ft_title_desc` (`title`,`description`);
ALTER TABLE `kos_listings` ADD FULLTEXT KEY `ft_location` (`location`);

--
-- Indexes for table `kos_rooms`
--
ALTER TABLE `kos_rooms`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_room_per_kos` (`kos_id`,`room_number`),
  ADD KEY `idx_kos_id` (`kos_id`),
  ADD KEY `idx_status` (`status`);

--
-- Indexes for table `laundry_places`
--
ALTER TABLE `laundry_places`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_rating` (`rating`),
  ADD KEY `idx_laundry_merchant_id` (`merchant_id`);

--
-- Indexes for table `merchants`
--
ALTER TABLE `merchants`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uniq_merchants_user_id` (`user_id`);

--
-- Indexes for table `password_resets`
--
ALTER TABLE `password_resets`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_email` (`email`),
  ADD KEY `idx_token` (`token`),
  ADD KEY `idx_password_resets_user_id` (`user_id`);

--
-- Indexes for table `payment_history`
--
ALTER TABLE `payment_history`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_payment_period` (`registration_id`,`period_month`),
  ADD KEY `idx_registration_id` (`registration_id`),
  ADD KEY `idx_payment_status` (`payment_status`);

--
-- Indexes for table `registration_documents`
--
ALTER TABLE `registration_documents`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_registration_id` (`registration_id`);

--
-- Indexes for table `room_facilities`
--
ALTER TABLE `room_facilities`
  ADD PRIMARY KEY (`room_id`,`facility_id`),
  ADD KEY `idx_room_facility_id` (`facility_id`);

--
-- Indexes for table `room_registrations`
--
ALTER TABLE `room_registrations`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_user_id` (`user_id`),
  ADD KEY `idx_room_id` (`room_id`),
  ADD KEY `idx_kos_id` (`kos_id`),
  ADD KEY `idx_status` (`status`),
  ADD KEY `room_registrations_ibfk_4` (`reviewed_by`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `email` (`email`),
  ADD KEY `idx_role` (`role`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `facilities`
--
ALTER TABLE `facilities`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT for table `kos_facilities`
--
ALTER TABLE `kos_facilities`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=24;

--
-- AUTO_INCREMENT for table `kos_images`
--
ALTER TABLE `kos_images`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=12;

--
-- AUTO_INCREMENT for table `password_resets`
--
ALTER TABLE `password_resets`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `payment_history`
--
ALTER TABLE `payment_history`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `registration_documents`
--
ALTER TABLE `registration_documents`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `cafe_places`
--
ALTER TABLE `cafe_places`
  ADD CONSTRAINT `fk_cafe_places_merchant` FOREIGN KEY (`merchant_id`) REFERENCES `merchants` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `catering_places`
--
ALTER TABLE `catering_places`
  ADD CONSTRAINT `fk_catering_places_merchant` FOREIGN KEY (`merchant_id`) REFERENCES `merchants` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `facilities`
--
ALTER TABLE `facilities`
  ADD CONSTRAINT `fk_facilities_created_by` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `kos_facilities`
--
ALTER TABLE `kos_facilities`
  ADD CONSTRAINT `kos_facilities_ibfk_1` FOREIGN KEY (`kos_id`) REFERENCES `kos_listings` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `kos_facilities_ibfk_2` FOREIGN KEY (`facility_id`) REFERENCES `facilities` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `kos_images`
--
ALTER TABLE `kos_images`
  ADD CONSTRAINT `kos_images_ibfk_1` FOREIGN KEY (`kos_id`) REFERENCES `kos_listings` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `kos_listings`
--
ALTER TABLE `kos_listings`
  ADD CONSTRAINT `kos_listings_ibfk_1` FOREIGN KEY (`owner_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `kos_rooms`
--
ALTER TABLE `kos_rooms`
  ADD CONSTRAINT `kos_rooms_ibfk_1` FOREIGN KEY (`kos_id`) REFERENCES `kos_listings` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `laundry_places`
--
ALTER TABLE `laundry_places`
  ADD CONSTRAINT `fk_laundry_places_merchant` FOREIGN KEY (`merchant_id`) REFERENCES `merchants` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `merchants`
--
ALTER TABLE `merchants`
  ADD CONSTRAINT `fk_merchants_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `password_resets`
--
ALTER TABLE `password_resets`
  ADD CONSTRAINT `fk_password_resets_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `payment_history`
--
ALTER TABLE `payment_history`
  ADD CONSTRAINT `payment_history_ibfk_1` FOREIGN KEY (`registration_id`) REFERENCES `room_registrations` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `registration_documents`
--
ALTER TABLE `registration_documents`
  ADD CONSTRAINT `registration_documents_ibfk_1` FOREIGN KEY (`registration_id`) REFERENCES `room_registrations` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `room_facilities`
--
ALTER TABLE `room_facilities`
  ADD CONSTRAINT `fk_room_facilities_facility` FOREIGN KEY (`facility_id`) REFERENCES `facilities` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_room_facilities_room` FOREIGN KEY (`room_id`) REFERENCES `kos_rooms` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `room_registrations`
--
ALTER TABLE `room_registrations`
  ADD CONSTRAINT `room_registrations_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `room_registrations_ibfk_2` FOREIGN KEY (`room_id`) REFERENCES `kos_rooms` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `room_registrations_ibfk_3` FOREIGN KEY (`kos_id`) REFERENCES `kos_listings` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `room_registrations_ibfk_4` FOREIGN KEY (`reviewed_by`) REFERENCES `users` (`id`) ON DELETE SET NULL;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
