-- phpMyAdmin SQL Dump
-- version 5.2.0
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Generation Time: May 05, 2026 at 07:34 PM
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
  `id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `vibe` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `rating` decimal(3,2) NOT NULL DEFAULT '0.00',
  `image_url` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `distance_km` decimal(5,2) NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `merchant_id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL
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
  `id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `address` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `specialty` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `rating` decimal(3,2) NOT NULL DEFAULT '0.00',
  `distance_km` decimal(5,2) NOT NULL,
  `image_url` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `min_order_portion` int NOT NULL DEFAULT '20',
  `merchant_id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `facilities`
--

CREATE TABLE `facilities` (
  `id` int NOT NULL,
  `name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL
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
  `kos_id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `facility_id` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `kos_images`
--

CREATE TABLE `kos_images` (
  `id` int NOT NULL,
  `kos_id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `image_url` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `display_order` int DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `kos_listings`
--

CREATE TABLE `kos_listings` (
  `id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `owner_id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `access_code` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `location` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `price_per_month` int NOT NULL,
  `rating` decimal(3,2) NOT NULL DEFAULT '0.00',
  `owner_contact` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `kos_listings`
--

INSERT INTO `kos_listings` (`id`, `owner_id`, `access_code`, `title`, `location`, `description`, `price_per_month`, `rating`, `owner_contact`, `created_at`, `updated_at`) VALUES
('254952fa-366a-417f-bbf7-43126254772c', '8b7bb846-be70-4a29-8fd1-f29d9f248f8d', 'KOS-254952', 'kosku', 'disini', 'p', 5000000, '0.00', '0812345678', '2026-04-26 14:21:28', '2026-04-26 14:21:28');

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
('588ea0ad-708b-47df-90e1-6591b885c456', '254952fa-366a-417f-bbf7-43126254772c', 'A02', 'Standard Single', 300000, 'monthly', 'occupied', 1, NULL, '2026-04-26 15:35:22', '2026-04-29 23:56:44'),
('5ed6dc94-b084-4505-af02-16fd6f8ee38d', '254952fa-366a-417f-bbf7-43126254772c', 'A04', 'Standard Single', 20000, 'daily', 'available', 1, NULL, '2026-04-29 16:14:32', '2026-04-29 16:20:58'),
('930a9f7d-e912-476c-b836-973c31b8e535', '254952fa-366a-417f-bbf7-43126254772c', 'A03', 'Standard Single', 10000, 'daily', 'available', 1, NULL, '2026-04-29 16:22:04', '2026-05-05 19:33:01'),
('9455bdec-b0d5-4d0c-9d76-0d197b8db240', '254952fa-366a-417f-bbf7-43126254772c', 'A01', 'Standard Single', 200000, 'monthly', 'occupied', 1, NULL, '2026-04-26 15:19:28', '2026-04-29 23:41:43');

-- --------------------------------------------------------

--
-- Table structure for table `laundry_places`
--

CREATE TABLE `laundry_places` (
  `id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `address` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `rating` decimal(3,2) NOT NULL DEFAULT '0.00',
  `distance_km` decimal(5,2) NOT NULL,
  `image_url` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `open_hours` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `merchant_id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL
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
  `id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `user_id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `business_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `merchant_type` enum('catering','cafe','laundry') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `phone` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `address` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `password_resets`
--

CREATE TABLE `password_resets` (
  `id` int NOT NULL,
  `email` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `token` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `expires_at` timestamp NOT NULL,
  `used_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `user_id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `payment_history`
--

CREATE TABLE `payment_history` (
  `id` int NOT NULL,
  `registration_id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `amount` int NOT NULL,
  `period_month` varchar(7) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Format: YYYY-MM, contoh: 2026-04',
  `payment_status` enum('unpaid','paid','overdue','cancelled') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'unpaid',
  `payment_method` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'transfer, cash, dll',
  `proof_url` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci COMMENT 'Bukti transfer',
  `paid_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `payment_history`
--

INSERT INTO `payment_history` (`id`, `registration_id`, `amount`, `period_month`, `payment_status`, `payment_method`, `proof_url`, `paid_at`, `created_at`) VALUES
(1, 'db51febd-ecde-445f-9c9c-ec83e448bb67', 200000, '2026-05', 'paid', 'bank_transfer', NULL, '2026-05-05 19:11:32', '2026-05-05 19:11:21'),
(2, '3da74e70-942b-47fc-b5e6-198bad98794b', 300000, '2026-05', 'paid', 'bank_transfer', NULL, '2026-05-05 19:27:16', '2026-05-05 19:27:02');

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
  `room_id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `facility_id` int NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `room_facilities`
--

INSERT INTO `room_facilities` (`room_id`, `facility_id`, `created_at`) VALUES
('588ea0ad-708b-47df-90e1-6591b885c456', 2, '2026-04-29 23:55:09'),
('588ea0ad-708b-47df-90e1-6591b885c456', 4, '2026-04-29 23:55:09'),
('588ea0ad-708b-47df-90e1-6591b885c456', 6, '2026-04-29 23:55:09'),
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
  `status` enum('pending','approved','active','completed','rejected','cancelled') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `start_date` date DEFAULT NULL COMMENT 'NULL jika belum disetujui atau belum mulai',
  `end_date` date DEFAULT NULL COMMENT 'NULL jika belum ditentukan',
  `notes` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci COMMENT 'Catatan dari user saat daftar',
  `reviewed_by` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'owner_id yang approve/reject',
  `reviewed_at` timestamp NULL DEFAULT NULL,
  `registered_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `room_registrations`
--

INSERT INTO `room_registrations` (`id`, `user_id`, `room_id`, `kos_id`, `status`, `start_date`, `end_date`, `notes`, `reviewed_by`, `reviewed_at`, `registered_at`, `updated_at`) VALUES
('3da74e70-942b-47fc-b5e6-198bad98794b', 'ac2cab5d-10ee-4a89-9586-a263e78df0c0', '588ea0ad-708b-47df-90e1-6591b885c456', '254952fa-366a-417f-bbf7-43126254772c', 'approved', '2026-04-30', NULL, NULL, NULL, NULL, '2026-04-29 23:56:44', '2026-04-29 23:57:05'),
('ad760b8d-277a-49e1-8389-c272d89a7a03', 'ac2cab5d-10ee-4a89-9586-a263e78df0c0', '930a9f7d-e912-476c-b836-973c31b8e535', '254952fa-366a-417f-bbf7-43126254772c', 'rejected', NULL, NULL, NULL, NULL, NULL, '2026-04-29 23:54:21', '2026-04-29 23:55:39'),
('db51febd-ecde-445f-9c9c-ec83e448bb67', 'fd7a0a79-e540-4acc-b486-1159fde58e66', '9455bdec-b0d5-4d0c-9d76-0d197b8db240', '254952fa-366a-417f-bbf7-43126254772c', 'approved', '2026-04-30', NULL, NULL, NULL, NULL, '2026-04-29 23:41:43', '2026-04-29 23:42:22');

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `email` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `password` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Password harus disimpan sebagai hash, bukan teks biasa',
  `display_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `role` enum('admin','merchant','user','owner') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'user',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `email`, `password`, `display_name`, `role`, `created_at`, `updated_at`) VALUES
('2940a8c6-6a2d-4e11-8f15-347f8fdd63d6', 'test@gmail.com', '$2y$12$4KzresTejEcWprLSOCjVo.STFs.zvkthMk82CBNn571Wz7XeIExUK', 'Test User', 'user', '2026-04-26 13:06:32', '2026-04-26 13:06:32'),
('8b7bb846-be70-4a29-8fd1-f29d9f248f8d', 'naufalzyram@gmail.com', '$2y$12$C8Lr1KwhYxOtZYTSBAHesefwEz9wa1dCux3GGpWpawYq5K1W4Ytri', 'ramzuy', 'owner', '2026-04-22 17:01:40', '2026-04-22 17:01:40'),
('ac2cab5d-10ee-4a89-9586-a263e78df0c0', 'user2@gmail.com', '$2y$12$efP3ZA6Ha1yX/ZkprVb0geRcN109/8EyfyeY6m9cYuVJGHUHf7.eK', 'user2', 'user', '2026-04-29 23:53:31', '2026-04-29 23:53:31'),
('cf9ab5ba-6cb0-4368-bd51-9c036357980e', 'ramzynaufal77@gmail.com', '$2y$12$RMrfs.4t2W2uvLOf1UggEejJfYIu/SY4Tk2KSuoWVL90IoVr.nOfy', 'ramzy', 'owner', '2026-04-26 15:42:43', '2026-04-26 15:42:43'),
('fd7a0a79-e540-4acc-b486-1159fde58e66', 'user1@gmail.com', '$2y$12$AFYmqUnAK.RhMAdMZGYo5.HyNyrr2G4Kd4WtofTA/p9yNe.yuB12u', 'tes1', 'user', '2026-04-29 23:41:16', '2026-04-29 23:41:16'),
('user_admin', 'admin@gmail.com', '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9', 'Admin KosFinder', 'admin', '2026-04-19 17:06:30', '2026-04-19 17:06:30');

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
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

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
