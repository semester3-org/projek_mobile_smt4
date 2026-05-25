-- phpMyAdmin SQL Dump
-- version 5.2.0
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Generation Time: May 25, 2026 at 12:45 PM
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
-- Database: `merchant_ngekos`
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
('c4', 'CafÃ© Bintang 5', 'Luxury', '4.70', 'https://images.unsplash.com/photo-1495521821757-a1efb6729352?w=800', '1.20', '2026-04-19 17:06:30', '2026-04-19 17:06:30', NULL),
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
('930a9f7d-e912-476c-b836-973c31b8e535', '254952fa-366a-417f-bbf7-43126254772c', 'A03', 'Standard Single', 10000, 'daily', 'occupied', 1, NULL, '2026-04-29 16:22:04', '2026-05-10 21:01:01'),
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
('l1', 'Laundry Fresh Express', 'Jl. Kaliurang Km 5', '4.70', '0.40', 'https://images.unsplash.com/photo-1582735689369-4fe89db7114c?w=800', '08:00 â€“ 20:00', '2026-04-19 17:06:30', '2026-04-19 17:06:30', NULL),
('l2', 'Cuci Kilat Jaya', 'Jl. Gejayan No. 22', '4.40', '0.90', 'https://images.unsplash.com/photo-1517677200551-7920f4b53198?w=800', '07:00 â€“ 21:00', '2026-04-19 17:06:30', '2026-04-19 17:06:30', NULL),
('l3', 'Bersih Laundry', 'Jl. Magelang 101', '4.60', '1.20', 'https://images.unsplash.com/photo-1626806819282-2c1dc01a5e0c?w=800', '07:00 â€“ 22:00', '2026-04-19 17:06:30', '2026-04-19 17:06:30', NULL),
('l4', 'Laundry Cepat Saja', 'Jl. Affandi No. 55', '4.50', '0.70', 'https://images.unsplash.com/photo-1582735689369-4fe89db7114c?w=800', '08:00 â€“ 20:30', '2026-04-19 17:06:30', '2026-04-19 17:06:30', NULL),
('l5', 'Express Wash Laundry', 'Jl. Diponegoro 12', '4.80', '1.00', 'https://images.unsplash.com/photo-1517677200551-7920f4b53198?w=800', '06:00 â€“ 21:00', '2026-04-19 17:06:30', '2026-04-19 17:06:30', NULL);

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

--
-- Dumping data for table `merchants`
--

INSERT INTO `merchants` (`id`, `user_id`, `business_name`, `merchant_type`, `phone`, `address`, `created_at`, `updated_at`) VALUES
('5adcab75-c594-4ad0-bd0d-9ae9b1b9f345', '7d8955c0-ef78-47f8-83c7-0e172804d5b0', 'catering1', 'catering', NULL, NULL, '2026-05-18 14:20:15', '2026-05-18 14:20:15'),
('c85dc179-0049-4159-a9b1-cf9bdd2bf5de', 'c5c022ca-34a9-4d16-a3ce-cc7c0f3e2e25', 'laundry1', 'laundry', NULL, NULL, '2026-05-18 14:06:42', '2026-05-18 14:06:42');

-- --------------------------------------------------------

--
-- Table structure for table `password_resets`
--

CREATE TABLE `password_resets` (
  `id` int NOT NULL,
  `email` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `token` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `expires_at` datetime NOT NULL,
  `used_at` datetime DEFAULT NULL,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
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
  `period_month` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
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
(2, '3da74e70-942b-47fc-b5e6-198bad98794b', 300000, '2026-05', 'paid', 'bank_transfer', NULL, '2026-05-05 19:27:16', '2026-05-05 19:27:02'),
(3, '8d15da01-261f-478b-8b82-29c297314bdc', 10000, '2026-05', 'paid', 'bank_transfer', NULL, '2026-05-10 22:16:25', '2026-05-10 22:15:54'),
(4, '8d15da01-261f-478b-8b82-29c297314bdc', 10000, '2026-06', 'paid', 'bank_transfer', NULL, '2026-05-10 22:31:38', '2026-05-10 22:31:28'),
(5, '8d15da01-261f-478b-8b82-29c297314bdc', 10000, '2026-07', 'paid', 'bank_transfer', NULL, '2026-05-10 22:43:23', '2026-05-10 22:32:27'),
(6, '8d15da01-261f-478b-8b82-29c297314bdc', 10000, '2026-05-14', 'paid', 'bank_transfer', NULL, '2026-05-10 22:53:25', '2026-05-10 22:53:17'),
(7, '8d15da01-261f-478b-8b82-29c297314bdc', 10000, '2026-05-15', 'paid', 'bank_transfer', NULL, '2026-05-10 22:55:06', '2026-05-10 22:54:53'),
(8, '8d15da01-261f-478b-8b82-29c297314bdc', 10000, '2026-05-16', 'paid', 'bank_transfer', NULL, '2026-05-10 23:18:28', '2026-05-10 23:18:17'),
(9, '8d15da01-261f-478b-8b82-29c297314bdc', 10000, '2026-05-17', 'paid', 'bank_transfer', NULL, '2026-05-10 23:21:41', '2026-05-10 23:21:31'),
(10, 'db51febd-ecde-445f-9c9c-ec83e448bb67', 200000, '2026-06', 'paid', 'bank_transfer', NULL, '2026-05-10 23:26:43', '2026-05-10 23:26:25'),
(11, 'db51febd-ecde-445f-9c9c-ec83e448bb67', 200000, '2026-07', 'paid', 'bank_transfer', NULL, '2026-05-11 01:46:44', '2026-05-11 01:45:44');

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
('84eb1050-ddf6-4ed9-813f-67af24be7a7d', '7e540d9f-d01d-4168-b868-0f523f7767f4', '930a9f7d-e912-476c-b836-973c31b8e535', '254952fa-366a-417f-bbf7-43126254772c', 'rejected', NULL, NULL, NULL, NULL, NULL, '2026-05-05 19:42:45', '2026-05-10 20:58:54'),
('8d15da01-261f-478b-8b82-29c297314bdc', '7e540d9f-d01d-4168-b868-0f523f7767f4', '930a9f7d-e912-476c-b836-973c31b8e535', '254952fa-366a-417f-bbf7-43126254772c', 'approved', '2026-05-11', NULL, NULL, NULL, NULL, '2026-05-10 21:01:01', '2026-05-10 21:01:36'),
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
  `phone` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `address` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `latitude` decimal(10,8) DEFAULT NULL,
  `longitude` decimal(11,8) DEFAULT NULL,
  `photo_url` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `role` enum('admin','merchant','user','owner') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'user',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `email`, `password`, `display_name`, `role`, `created_at`, `updated_at`) VALUES
('2940a8c6-6a2d-4e11-8f15-347f8fdd63d6', 'test@gmail.com', '$2y$12$4KzresTejEcWprLSOCjVo.STFs.zvkthMk82CBNn571Wz7XeIExUK', 'Test User', 'user', '2026-04-26 13:06:32', '2026-04-26 13:06:32'),
('7d8955c0-ef78-47f8-83c7-0e172804d5b0', 'catering1@gmail.com', '$2y$12$1u454gpSQFVh4yfQrfVpguh9G8NC/EyaSmn3c1Nmtd8L60pDy/.JS', 'catering1', 'merchant', '2026-05-18 14:20:15', '2026-05-18 14:20:15'),
('7e540d9f-d01d-4168-b868-0f523f7767f4', 'user3@gmail.com', '$2y$12$t3ADTKNH0sUk.JtBn6GjDeCfJeUsLmIVYE4rK0Tb.bUd5EiFVE9X6', 'user3', 'user', '2026-05-05 19:38:08', '2026-05-05 19:38:08'),
('8b7bb846-be70-4a29-8fd1-f29d9f248f8d', 'naufalzyram@gmail.com', '$2y$12$C8Lr1KwhYxOtZYTSBAHesefwEz9wa1dCux3GGpWpawYq5K1W4Ytri', 'ramzuy', 'owner', '2026-04-22 17:01:40', '2026-04-22 17:01:40'),
('ac2cab5d-10ee-4a89-9586-a263e78df0c0', 'user2@gmail.com', '$2y$12$efP3ZA6Ha1yX/ZkprVb0geRcN109/8EyfyeY6m9cYuVJGHUHf7.eK', 'user2', 'user', '2026-04-29 23:53:31', '2026-04-29 23:53:31'),
('c5c022ca-34a9-4d16-a3ce-cc7c0f3e2e25', 'laundry1@gmail.com', '$2y$12$xP6DCuwgYJrAc4G2DtEWyOgiGVbUkyyLP1uDOWNcpo5bUMYP.o.te', 'laundry1', 'merchant', '2026-05-18 14:06:42', '2026-05-18 14:06:42'),
('cf9ab5ba-6cb0-4368-bd51-9c036357980e', 'ramzynaufal77@gmail.com', '$2y$12$RMrfs.4t2W2uvLOf1UggEejJfYIu/SY4Tk2KSuoWVL90IoVr.nOfy', 'ramzy', 'owner', '2026-04-26 15:42:43', '2026-04-26 15:42:43'),
('fd7a0a79-e540-4acc-b486-1159fde58e66', 'user1@gmail.com', '$2y$12$a1vd5ij7Nulr.Nhx5TkuAOMNZJl5.Qe8hVONiToT5BsDNbYBEwhpy', 'tes1', 'user', '2026-04-29 23:41:16', '2026-05-19 02:04:34'),
('user_admin', 'admin@gmail.com', '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9', 'Admin KosFinder', 'admin', '2026-04-19 17:06:30', '2026-04-19 17:06:30');


-- --------------------------------------------------------

--
-- Table structure for table `app_notifications`
--

CREATE TABLE `app_notifications` (
  `id` bigint UNSIGNED NOT NULL,
  `user_id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `message` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `read_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `cache`
--

CREATE TABLE `cache` (
  `key` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `value` mediumtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `expiration` bigint NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `cache_locks`
--

CREATE TABLE `cache_locks` (
  `key` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `owner` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `expiration` bigint NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `failed_jobs`
--

CREATE TABLE `failed_jobs` (
  `id` bigint UNSIGNED NOT NULL,
  `uuid` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `connection` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `queue` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `payload` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `exception` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `failed_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `job_batches`
--

CREATE TABLE `job_batches` (
  `id` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `total_jobs` int NOT NULL,
  `pending_jobs` int NOT NULL,
  `failed_jobs` int NOT NULL,
  `failed_job_ids` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `options` mediumtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `cancelled_at` int DEFAULT NULL,
  `created_at` int NOT NULL,
  `finished_at` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `jobs`
--

CREATE TABLE `jobs` (
  `id` bigint UNSIGNED NOT NULL,
  `queue` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `payload` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `attempts` tinyint UNSIGNED NOT NULL,
  `reserved_at` int UNSIGNED DEFAULT NULL,
  `available_at` int UNSIGNED NOT NULL,
  `created_at` int UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `migrations`
--

CREATE TABLE `migrations` (
  `id` int UNSIGNED NOT NULL,
  `migration` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `batch` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `orders`
--

CREATE TABLE `orders` (
  `id` bigint UNSIGNED NOT NULL,
  `user_id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `merchant_id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `total_harga` decimal(14,2) NOT NULL DEFAULT '0.00',
  `status` enum('pending','accepted','processing','delivered','done') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `order_items`
--

CREATE TABLE `order_items` (
  `id` bigint UNSIGNED NOT NULL,
  `order_id` bigint UNSIGNED NOT NULL,
  `product_id` bigint UNSIGNED NOT NULL,
  `qty` int UNSIGNED NOT NULL,
  `harga` decimal(14,2) NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `password_reset_tokens`
--

CREATE TABLE `password_reset_tokens` (
  `email` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `token` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `products`
--

CREATE TABLE `products` (
  `id` bigint UNSIGNED NOT NULL,
  `merchant_id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `nama_produk` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `harga` decimal(14,2) NOT NULL,
  `deskripsi` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `sessions`
--

CREATE TABLE `sessions` (
  `id` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `user_id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ip_address` varchar(45) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_agent` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `payload` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `last_activity` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- --------------------------------------------------------

--
-- Converted legacy data from merchant_ngekos.sql
-- Numeric legacy IDs are prefixed to keep them compatible with UUID-based fix tables.
--

--
-- Legacy data converted for table `users`
--
INSERT INTO `users` (`id`, `email`, `password`, `display_name`, `role`, `created_at`, `updated_at`) VALUES
('legacy_user_1', 'admin@ngekos.test', '$2y$12$fy.CrsfExi2tkQRb2QC3/OHjuNIOQDTYe0YhD4qD7hJZuJGZeEMeC', 'Admin Ngekos', 'admin', '2026-04-15 10:09:44', '2026-04-15 10:10:37'),
('legacy_user_2', 'owner@ngekos.test', '$2y$12$vMz8T1ZqCE4fwIqyj2pHUurjwp/xHm7Vodmdzlv121vifDqPm3fkS', 'Owner Ngekos', 'owner', '2026-04-15 10:09:44', '2026-04-15 10:10:37'),
('legacy_user_3', 'user@ngekos.test', '$2y$12$PBBTICZmr.QSLXKBJQVkhO7UnoLEMDA68KzX8sikXDiWJqQfGz5eC', 'Anak Kos', 'user', '2026-04-15 10:09:44', '2026-04-15 10:10:37'),
('legacy_user_4', 'merchant@ngekos.test', '$2y$12$IQ8zqaeP0.uzQnprtoPmOO/BPMG6nuZj5RApNonaTvnpgv41qAUIu', 'Merchant Ngekos', 'merchant', '2026-04-15 10:09:44', '2026-04-15 10:10:37'),
('legacy_user_5', 'dillon.hessel@example.com', '$2y$12$R6OS4gKoHn4Eq1BvFBAgS.me1h.yWI0MQEYyYR9XvthwO/LLMvXym', 'Keira Adams', 'user', '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('legacy_user_6', 'abahringer@example.com', '$2y$12$R6OS4gKoHn4Eq1BvFBAgS.me1h.yWI0MQEYyYR9XvthwO/LLMvXym', 'Korey Heidenreich', 'user', '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('legacy_user_7', 'streich.phoebe@example.com', '$2y$12$R6OS4gKoHn4Eq1BvFBAgS.me1h.yWI0MQEYyYR9XvthwO/LLMvXym', 'Estel Leannon', 'user', '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('legacy_user_8', 'malinda.kub@example.org', '$2y$12$R6OS4gKoHn4Eq1BvFBAgS.me1h.yWI0MQEYyYR9XvthwO/LLMvXym', 'Abdul Ledner II', 'user', '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('legacy_user_9', 'hyatt.gregory@example.net', '$2y$12$R6OS4gKoHn4Eq1BvFBAgS.me1h.yWI0MQEYyYR9XvthwO/LLMvXym', 'Rafaela Ward', 'user', '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('legacy_user_10', 'evan.crona@example.com', '$2y$12$R6OS4gKoHn4Eq1BvFBAgS.me1h.yWI0MQEYyYR9XvthwO/LLMvXym', 'Dr. Ashley Lubowitz MD', 'user', '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('legacy_user_11', 'rau.roger@example.net', '$2y$12$R6OS4gKoHn4Eq1BvFBAgS.me1h.yWI0MQEYyYR9XvthwO/LLMvXym', 'Mrs. Maya Doyle DVM', 'user', '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('legacy_user_12', 'cordie.mills@example.com', '$2y$12$R6OS4gKoHn4Eq1BvFBAgS.me1h.yWI0MQEYyYR9XvthwO/LLMvXym', 'Wanda Emard', 'user', '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('legacy_user_13', 'orpha.smitham@example.org', '$2y$12$R6OS4gKoHn4Eq1BvFBAgS.me1h.yWI0MQEYyYR9XvthwO/LLMvXym', 'Seamus Kiehn', 'user', '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('legacy_user_14', 'vandervort.liza@example.org', '$2y$12$R6OS4gKoHn4Eq1BvFBAgS.me1h.yWI0MQEYyYR9XvthwO/LLMvXym', 'Marcelo Thompson V', 'user', '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('legacy_user_15', 'merchant2@ngekos.test', '$2y$12$SfnXGKqTe/0d6brrH5WdBus57Ym1f0biJ6CKDRA9iC4rANzR/x55G', 'Merchant Kedua', 'merchant', '2026-04-15 10:09:44', '2026-04-15 10:10:38'),
('legacy_user_17', 'hills.ryder@example.net', '$2y$12$NbVHvox3qBURKTqNnwPNDuXtCNZUosOMBMaww8D/SCIab4uSJex1i', 'Bernardo Grimes', 'user', '2026-04-15 10:10:38', '2026-04-15 10:10:38'),
('legacy_user_18', 'sferry@example.net', '$2y$12$NbVHvox3qBURKTqNnwPNDuXtCNZUosOMBMaww8D/SCIab4uSJex1i', 'Lorna Kertzmann', 'user', '2026-04-15 10:10:38', '2026-04-15 10:10:38'),
('legacy_user_19', 'ciara73@example.net', '$2y$12$NbVHvox3qBURKTqNnwPNDuXtCNZUosOMBMaww8D/SCIab4uSJex1i', 'Mathias Schoen', 'user', '2026-04-15 10:10:38', '2026-04-15 10:10:38'),
('legacy_user_20', 'deborah53@example.net', '$2y$12$NbVHvox3qBURKTqNnwPNDuXtCNZUosOMBMaww8D/SCIab4uSJex1i', 'Prof. Hilbert O\'Connell II', 'user', '2026-04-15 10:10:38', '2026-04-15 10:10:38'),
('legacy_user_21', 'karelle.kreiger@example.com', '$2y$12$NbVHvox3qBURKTqNnwPNDuXtCNZUosOMBMaww8D/SCIab4uSJex1i', 'Javonte Aufderhar', 'user', '2026-04-15 10:10:38', '2026-04-15 10:10:38'),
('legacy_user_22', 'stamm.edyth@example.org', '$2y$12$NbVHvox3qBURKTqNnwPNDuXtCNZUosOMBMaww8D/SCIab4uSJex1i', 'Ellen Jones', 'user', '2026-04-15 10:10:38', '2026-04-15 10:10:38'),
('legacy_user_23', 'ashtyn.rogahn@example.com', '$2y$12$NbVHvox3qBURKTqNnwPNDuXtCNZUosOMBMaww8D/SCIab4uSJex1i', 'Prof. Geovany Lehner I', 'user', '2026-04-15 10:10:38', '2026-04-15 10:10:38'),
('legacy_user_24', 'aurelia93@example.com', '$2y$12$NbVHvox3qBURKTqNnwPNDuXtCNZUosOMBMaww8D/SCIab4uSJex1i', 'Prof. Buster Harvey', 'user', '2026-04-15 10:10:38', '2026-04-15 10:10:38'),
('legacy_user_25', 'wwaters@example.org', '$2y$12$NbVHvox3qBURKTqNnwPNDuXtCNZUosOMBMaww8D/SCIab4uSJex1i', 'Davonte Ziemann', 'user', '2026-04-15 10:10:38', '2026-04-15 10:10:38'),
('legacy_user_26', 'wallace.boyer@example.net', '$2y$12$NbVHvox3qBURKTqNnwPNDuXtCNZUosOMBMaww8D/SCIab4uSJex1i', 'Vivian Maggio', 'user', '2026-04-15 10:10:38', '2026-04-15 10:10:38'),
('legacy_user_27', 'abuyya@gmail.com', '$2y$12$6gnaK7oDQTZu36rTKE8GXum771bBUU4EG3ivWVxL7p0RYQD3gyU8e', 'Abuyya Gufron', 'user', '2026-05-10 05:26:47', '2026-05-10 05:26:47'),
('legacy_user_28', 'owner1@gmail.com', '$2y$12$NQGH38N2BhMlgEVynyNlOu/AB5zbLokpxo6Z0yQkTE82UXDlizxYa', 'Owner1', 'owner', '2026-05-10 05:28:14', '2026-05-10 05:37:20'),
('legacy_user_29', 'merchant1@gmail.com', '$2y$12$lQolerCgtn23qLI65s0kmucOd/X1RfkZCf42RQA0lB6/bWsbzenFK', 'Merchant1', 'merchant', '2026-05-10 05:29:35', '2026-05-10 05:37:23'),
('legacy_user_4_merchant_3', 'legacy-merchant-3+merchant@ngekos.test', '$2y$12$IQ8zqaeP0.uzQnprtoPmOO/BPMG6nuZj5RApNonaTvnpgv41qAUIu', 'Merchant Ngekos (Marvin-Sawayn)', 'merchant', '2026-04-15 10:10:37', '2026-04-15 10:10:37'),
('legacy_user_15_merchant_4', 'legacy-merchant-4+merchant2@ngekos.test', '$2y$12$SfnXGKqTe/0d6brrH5WdBus57Ym1f0biJ6CKDRA9iC4rANzR/x55G', 'Merchant Kedua (Hettinger, Kutch and Reynolds)', 'merchant', '2026-04-15 10:10:38', '2026-04-15 10:10:38');

--
-- Legacy data converted for table `kos_listings`
--
INSERT INTO `kos_listings` (`id`, `owner_id`, `access_code`, `title`, `location`, `description`, `price_per_month`, `rating`, `owner_contact`, `created_at`, `updated_at`) VALUES
('legacy_kos_1', 'legacy_user_2', 'LEG-KOS-1', 'Kos Hill Shore', '74327 Prince Circle Apt. 749\nNorth Esperanzafort, CT 73563-7685', 'Aut qui et aut qui qui in eum.', '800', '0.00', '-', '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('legacy_kos_2', 'legacy_user_2', 'LEG-KOS-2', 'Kos Carolanne Loaf', '32386 Sarah Center Apt. 376\nSpinkafurt, NJ 52938', 'Vero architecto consequatur odit voluptas qui ducimus.', '400000', '0.00', '-', '2026-04-15 10:10:37', '2026-04-15 10:10:37'),
('legacy_kos_3', 'legacy_user_2', 'LEG-KOS-3', 'The Raid', 'Jl.tawang mangu no6', 'kos terbaik di jember', '400000', '0.00', '-', '2026-05-11 07:38:10', '2026-05-11 07:38:10');

--
-- Legacy data converted for table `kos_rooms`
--
INSERT INTO `kos_rooms` (`id`, `kos_id`, `room_number`, `room_type`, `price_per_month`, `rental_type`, `status`, `max_occupant`, `description`, `created_at`, `updated_at`) VALUES
('legacy_room_1', 'legacy_kos_1', '267', 'Standard', '824713', 'monthly', 'occupied', '1', NULL, '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('legacy_room_2', 'legacy_kos_1', '302', 'Standard', '2190637', 'monthly', 'occupied', '1', NULL, '2026-04-15 10:09:44', '2026-05-05 11:08:33'),
('legacy_room_3', 'legacy_kos_1', '390', 'Standard', '1330200', 'monthly', 'occupied', '1', NULL, '2026-04-15 10:09:44', '2026-05-05 08:57:31'),
('legacy_room_4', 'legacy_kos_1', '127', 'Standard', '1683742', 'monthly', 'occupied', '1', NULL, '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('legacy_room_5', 'legacy_kos_1', '151', 'Standard', '1223397', 'monthly', 'occupied', '1', NULL, '2026-04-15 10:09:44', '2026-05-05 11:09:51'),
('legacy_room_6', 'legacy_kos_2', '113', 'Standard', '685772', 'monthly', 'occupied', '1', NULL, '2026-04-15 10:10:37', '2026-05-05 08:41:27'),
('legacy_room_7', 'legacy_kos_2', '443', 'Standard', '1674140', 'monthly', 'occupied', '1', NULL, '2026-04-15 10:10:37', '2026-05-05 08:50:34'),
('legacy_room_8', 'legacy_kos_2', '345', 'Standard', '1108938', 'monthly', 'occupied', '1', NULL, '2026-04-15 10:10:37', '2026-04-15 10:10:37'),
('legacy_room_9', 'legacy_kos_2', '173', 'Standard', '2111194', 'monthly', 'occupied', '1', NULL, '2026-04-15 10:10:37', '2026-04-15 10:10:37'),
('legacy_room_10', 'legacy_kos_2', '326', 'Standard', '1049717', 'monthly', 'occupied', '1', NULL, '2026-04-15 10:10:37', '2026-05-05 08:52:11'),
('legacy_room_11', 'legacy_kos_1', '1', 'Standard', '800', 'monthly', 'occupied', '1', NULL, '2026-04-15 11:00:07', '2026-05-05 10:13:55'),
('legacy_room_12', 'legacy_kos_1', '123', 'Standard', '400000', 'monthly', 'occupied', '1', NULL, '2026-04-26 06:51:23', '2026-05-05 09:42:39'),
('legacy_room_13', 'legacy_kos_1', '300', 'Standard', '20000', 'monthly', 'occupied', '1', NULL, '2026-05-05 09:00:18', '2026-05-05 09:01:26'),
('legacy_room_14', 'legacy_kos_1', '301', 'Standard', '300000', 'monthly', 'occupied', '1', NULL, '2026-05-05 09:00:36', '2026-05-05 09:08:39'),
('legacy_room_15', 'legacy_kos_1', '302-15', 'Standard', '400000', 'monthly', 'occupied', '1', NULL, '2026-05-05 09:00:49', '2026-05-05 09:12:35'),
('legacy_room_16', 'legacy_kos_1', '001', 'Standard', '800', 'monthly', 'occupied', '1', NULL, '2026-05-10 22:18:21', '2026-05-11 07:39:28'),
('legacy_room_17', 'legacy_kos_1', '002', 'Standard', '800', 'monthly', 'available', '1', NULL, '2026-05-10 22:18:36', '2026-05-10 22:18:36'),
('legacy_room_18', 'legacy_kos_2', '001', 'Standard', '400000', 'monthly', 'available', '1', NULL, '2026-05-10 22:19:29', '2026-05-10 22:19:29'),
('legacy_room_19', 'legacy_kos_1', '002-19', 'Standard', '400000', 'monthly', 'available', '1', NULL, '2026-05-10 22:19:38', '2026-05-10 22:19:38'),
('legacy_room_20', 'legacy_kos_2', '003', 'Standard', '400000', 'monthly', 'available', '1', NULL, '2026-05-10 22:21:06', '2026-05-10 22:21:06'),
('legacy_room_21', 'legacy_kos_3', '001', 'Standard', '400000', 'monthly', 'available', '1', NULL, '2026-05-11 07:38:37', '2026-05-11 07:38:37');

--
-- Legacy data converted for table `merchants`
--
INSERT INTO `merchants` (`id`, `user_id`, `business_name`, `merchant_type`, `phone`, `address`, `created_at`, `updated_at`) VALUES
('legacy_merchant_1', 'legacy_user_4', 'Braun and Sons', 'cafe', NULL, NULL, '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('legacy_merchant_2', 'legacy_user_15', 'Smitham Group', NULL, NULL, NULL, '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('legacy_merchant_3', 'legacy_user_4_merchant_3', 'Marvin-Sawayn', 'cafe', NULL, NULL, '2026-04-15 10:10:37', '2026-04-15 10:10:37'),
('legacy_merchant_4', 'legacy_user_15_merchant_4', 'Hettinger, Kutch and Reynolds', NULL, NULL, NULL, '2026-04-15 10:10:38', '2026-04-15 10:10:38'),
('legacy_merchant_5', 'legacy_user_29', 'Merchant1', 'cafe', NULL, NULL, '2026-05-10 05:29:35', '2026-05-10 05:29:35');

--
-- Legacy data converted for table `products`
--
INSERT INTO `products` (`id`, `merchant_id`, `nama_produk`, `harga`, `deskripsi`, `created_at`, `updated_at`) VALUES
('1', 'legacy_merchant_1', 'quae qui', '78751.00', 'Labore fugit occaecati assumenda adipisci doloribus veritatis sint.', '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('2', 'legacy_merchant_1', 'non soluta', '33285.00', 'Non aut impedit autem aperiam veritatis at consequatur.', '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('3', 'legacy_merchant_1', 'exercitationem qui', '68272.00', 'Consectetur blanditiis cupiditate rerum quisquam rerum illum amet.', '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('4', 'legacy_merchant_1', 'corrupti dicta', '83347.00', 'Dicta voluptate perferendis deleniti distinctio.', '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('5', 'legacy_merchant_2', 'consequatur repellat', '69393.00', 'Voluptatum animi rem dolor impedit.', '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('6', 'legacy_merchant_2', 'tempora facere', '81284.00', 'Praesentium vel aliquid cupiditate placeat placeat autem quibusdam.', '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('7', 'legacy_merchant_2', 'doloremque consequuntur', '59347.00', 'Sed vero quo animi qui ut.', '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('8', 'legacy_merchant_2', 'reprehenderit vel', '113597.00', 'Voluptatem et officia sunt amet.', '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('9', 'legacy_merchant_2', 'est distinctio', '82066.00', 'Hic repellat labore placeat voluptas doloremque aspernatur ducimus et.', '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('10', 'legacy_merchant_2', 'et eum', '102289.00', 'Eos aut ea nulla quo laboriosam alias.', '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('14', 'legacy_merchant_3', 'quo quisquam', '53747.00', 'Voluptate sequi voluptas totam laudantium aspernatur suscipit sunt.', '2026-04-15 10:10:38', '2026-04-15 10:10:38'),
('15', 'legacy_merchant_4', 'quos aut', '86261.00', 'Praesentium quo dignissimos facere nemo ut libero et qui.', '2026-04-15 10:10:38', '2026-04-15 10:10:38'),
('16', 'legacy_merchant_4', 'sit quisquam', '38493.00', 'In voluptas nisi et non alias.', '2026-04-15 10:10:38', '2026-04-15 10:10:38'),
('17', 'legacy_merchant_4', 'distinctio tempore', '39197.00', 'Tempore molestiae id a esse officia.', '2026-04-15 10:10:38', '2026-04-15 10:10:38'),
('18', 'legacy_merchant_4', 'corporis sapiente', '38226.00', 'Excepturi magnam autem sed optio ratione assumenda aut et.', '2026-04-15 10:10:38', '2026-04-15 10:10:38'),
('19', 'legacy_merchant_4', 'nesciunt deleniti', '118733.00', 'Facere dolores recusandae ab sequi ad ut.', '2026-04-15 10:10:38', '2026-04-15 10:10:38'),
('20', 'legacy_merchant_4', 'quod in', '60666.00', 'Adipisci facilis minus dolor quibusdam a voluptatem.', '2026-04-15 10:10:38', '2026-04-15 10:10:38');

--
-- Legacy data converted for table `orders`
--
INSERT INTO `orders` (`id`, `user_id`, `merchant_id`, `total_harga`, `status`, `created_at`, `updated_at`) VALUES
('1', 'legacy_user_3', 'legacy_merchant_1', '64549.00', 'done', '2026-04-15 10:09:44', '2026-05-10 22:15:57'),
('2', 'legacy_user_3', 'legacy_merchant_3', '72960.00', 'done', '2026-04-15 10:10:38', '2026-05-10 22:15:50'),
('3', 'legacy_user_27', 'legacy_merchant_2', '69393.00', 'accepted', '2026-05-10 05:32:03', '2026-05-10 22:00:35'),
('4', 'legacy_user_27', 'legacy_merchant_4', '39197.00', 'pending', '2026-05-10 22:16:39', '2026-05-10 22:16:39'),
('5', 'legacy_user_27', 'legacy_merchant_4', '118733.00', 'pending', '2026-05-10 22:16:48', '2026-05-10 22:16:48'),
('6', 'legacy_user_27', 'legacy_merchant_1', '78751.00', 'done', '2026-05-10 22:17:03', '2026-05-11 19:19:13'),
('7', 'legacy_user_3', 'legacy_merchant_4', '39197.00', 'accepted', '2026-05-11 19:17:30', '2026-05-11 19:18:08');

--
-- Legacy data converted for table `order_items`
--
INSERT INTO `order_items` (`id`, `order_id`, `product_id`, `qty`, `harga`, `created_at`, `updated_at`) VALUES
('1', '1', '1', '1', '78751.00', '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('2', '1', '2', '1', '33285.00', '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('5', '3', '5', '1', '69393.00', '2026-05-10 05:32:03', '2026-05-10 05:32:03'),
('6', '4', '17', '1', '39197.00', '2026-05-10 22:16:39', '2026-05-10 22:16:39'),
('7', '5', '19', '1', '118733.00', '2026-05-10 22:16:48', '2026-05-10 22:16:48'),
('8', '6', '1', '1', '78751.00', '2026-05-10 22:17:03', '2026-05-10 22:17:03'),
('9', '7', '17', '1', '39197.00', '2026-05-11 19:17:30', '2026-05-11 19:17:30');

--
-- Legacy data converted for table `room_registrations`
--
INSERT INTO `room_registrations` (`id`, `user_id`, `room_id`, `kos_id`, `status`, `start_date`, `end_date`, `notes`, `reviewed_by`, `reviewed_at`, `registered_at`, `updated_at`) VALUES
('legacy_registration_1', 'legacy_user_3', 'legacy_room_1', 'legacy_kos_1', 'approved', '2026-04-15', '2027-01-10', 'Migrated from transaksi_kos #1; total_harga=4006864.00; status=verified', NULL, '2026-04-26 06:54:51', '2026-04-15 10:09:44', '2026-04-26 06:54:51'),
('legacy_registration_2', 'legacy_user_3', 'legacy_room_6', 'legacy_kos_2', 'approved', '2026-04-15', '2026-07-14', 'Migrated from transaksi_kos #2; total_harga=2636359.00; status=paid', NULL, '2026-04-15 10:10:37', '2026-04-15 10:10:37', '2026-04-15 10:10:37'),
('legacy_registration_3', 'legacy_user_3', 'legacy_room_6', 'legacy_kos_2', 'pending', '2026-05-06', '2026-06-05', 'Migrated from transaksi_kos #3; total_harga=685772.00; status=pending', NULL, NULL, '2026-05-05 08:41:27', '2026-05-05 08:41:27'),
('legacy_registration_4', 'legacy_user_3', 'legacy_room_7', 'legacy_kos_2', 'pending', '2026-05-05', '2026-06-04', 'Migrated from transaksi_kos #4; total_harga=1674140.00; status=pending', NULL, NULL, '2026-05-05 08:50:34', '2026-05-05 08:50:34'),
('legacy_registration_5', 'legacy_user_3', 'legacy_room_10', 'legacy_kos_2', 'pending', '2026-05-06', '2026-07-05', 'Migrated from transaksi_kos #5; total_harga=2099434.00; status=pending', NULL, NULL, '2026-05-05 08:52:11', '2026-05-05 08:52:11'),
('legacy_registration_6', 'legacy_user_3', 'legacy_room_3', 'legacy_kos_1', 'pending', '2026-05-06', '2026-07-05', 'Migrated from transaksi_kos #6; total_harga=2660400.00; status=pending', NULL, NULL, '2026-05-05 08:57:31', '2026-05-05 08:57:31'),
('legacy_registration_7', 'legacy_user_3', 'legacy_room_13', 'legacy_kos_1', 'pending', '2026-05-06', '2026-07-05', 'Migrated from transaksi_kos #7; total_harga=40000.00; status=pending', NULL, NULL, '2026-05-05 09:01:26', '2026-05-05 09:01:26'),
('legacy_registration_8', 'legacy_user_3', 'legacy_room_14', 'legacy_kos_1', 'pending', '2026-05-13', '2026-06-12', 'Migrated from transaksi_kos #8; total_harga=300000.00; status=pending', NULL, NULL, '2026-05-05 09:08:39', '2026-05-05 09:08:39'),
('legacy_registration_9', 'legacy_user_3', 'legacy_room_15', 'legacy_kos_1', 'pending', '2026-05-06', '2026-07-05', 'Migrated from transaksi_kos #9; total_harga=800000.00; status=pending', NULL, NULL, '2026-05-05 09:12:35', '2026-05-05 09:12:35'),
('legacy_registration_10', 'legacy_user_3', 'legacy_room_12', 'legacy_kos_1', 'approved', '2026-05-06', '2026-06-05', 'Migrated from transaksi_kos #10; total_harga=400000.00; status=paid', NULL, '2026-05-05 10:34:48', '2026-05-05 09:42:39', '2026-05-05 10:34:48'),
('legacy_registration_11', 'legacy_user_3', 'legacy_room_11', 'legacy_kos_1', 'approved', '2026-05-06', '2026-06-05', 'Migrated from transaksi_kos #11; total_harga=800.00; status=paid', NULL, '2026-05-05 11:13:17', '2026-05-05 10:13:55', '2026-05-05 11:13:17'),
('legacy_registration_12', 'legacy_user_3', 'legacy_room_2', 'legacy_kos_1', 'pending', '2026-05-07', '2026-06-06', 'Migrated from transaksi_kos #12; total_harga=2190637.00; status=pending', NULL, NULL, '2026-05-05 11:08:33', '2026-05-05 11:08:33'),
('legacy_registration_13', 'legacy_user_3', 'legacy_room_5', 'legacy_kos_1', 'approved', '2026-05-07', '2026-06-06', 'Migrated from transaksi_kos #13; total_harga=1223397.00; status=paid', NULL, '2026-05-11 07:43:55', '2026-05-05 11:09:51', '2026-05-11 07:43:55'),
('legacy_registration_14', 'legacy_user_3', 'legacy_room_16', 'legacy_kos_1', 'pending', '2026-05-12', '2026-06-11', 'Migrated from transaksi_kos #14; total_harga=800.00; status=pending', NULL, NULL, '2026-05-11 07:39:28', '2026-05-11 07:39:28'),
('legacy_bill_registration_2', 'legacy_user_5', 'legacy_room_4', 'legacy_kos_1', 'approved', '2026-04-01', NULL, 'Generated from tagihan_bulanans #2', NULL, '2026-04-15 10:09:44', '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('legacy_bill_registration_3', 'legacy_user_6', 'legacy_room_1', 'legacy_kos_1', 'approved', '2026-04-01', NULL, 'Generated from tagihan_bulanans #3', NULL, '2026-04-15 10:09:44', '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('legacy_bill_registration_4', 'legacy_user_7', 'legacy_room_3', 'legacy_kos_1', 'approved', '2026-04-01', NULL, 'Generated from tagihan_bulanans #4', NULL, '2026-04-15 10:09:44', '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('legacy_bill_registration_5', 'legacy_user_8', 'legacy_room_2', 'legacy_kos_1', 'pending', '2026-04-01', NULL, 'Generated from tagihan_bulanans #5', NULL, NULL, '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('legacy_bill_registration_6', 'legacy_user_9', 'legacy_room_1', 'legacy_kos_1', 'pending', '2026-04-01', NULL, 'Generated from tagihan_bulanans #6', NULL, NULL, '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('legacy_bill_registration_7', 'legacy_user_10', 'legacy_room_3', 'legacy_kos_1', 'approved', '2026-04-01', NULL, 'Generated from tagihan_bulanans #7', NULL, '2026-04-15 10:09:44', '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('legacy_bill_registration_8', 'legacy_user_11', 'legacy_room_2', 'legacy_kos_1', 'approved', '2026-04-01', NULL, 'Generated from tagihan_bulanans #8', NULL, '2026-04-15 10:09:44', '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('legacy_bill_registration_9', 'legacy_user_12', 'legacy_room_2', 'legacy_kos_1', 'pending', '2026-04-01', NULL, 'Generated from tagihan_bulanans #9', NULL, NULL, '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('legacy_bill_registration_10', 'legacy_user_13', 'legacy_room_4', 'legacy_kos_1', 'approved', '2026-04-01', NULL, 'Generated from tagihan_bulanans #10', NULL, '2026-04-15 10:09:44', '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('legacy_bill_registration_11', 'legacy_user_14', 'legacy_room_5', 'legacy_kos_1', 'pending', '2026-04-01', NULL, 'Generated from tagihan_bulanans #11', NULL, NULL, '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('legacy_bill_registration_13', 'legacy_user_17', 'legacy_room_6', 'legacy_kos_2', 'approved', '2026-04-01', NULL, 'Generated from tagihan_bulanans #13', NULL, '2026-04-15 10:10:38', '2026-04-15 10:10:38', '2026-04-15 10:10:38'),
('legacy_bill_registration_14', 'legacy_user_18', 'legacy_room_6', 'legacy_kos_2', 'pending', '2026-04-01', NULL, 'Generated from tagihan_bulanans #14', NULL, NULL, '2026-04-15 10:10:38', '2026-04-15 10:10:38'),
('legacy_bill_registration_15', 'legacy_user_19', 'legacy_room_7', 'legacy_kos_2', 'pending', '2026-04-01', NULL, 'Generated from tagihan_bulanans #15', NULL, NULL, '2026-04-15 10:10:38', '2026-04-15 10:10:38'),
('legacy_bill_registration_16', 'legacy_user_20', 'legacy_room_7', 'legacy_kos_2', 'approved', '2026-04-01', NULL, 'Generated from tagihan_bulanans #16', NULL, '2026-04-15 10:10:38', '2026-04-15 10:10:38', '2026-04-15 10:10:38'),
('legacy_bill_registration_17', 'legacy_user_21', 'legacy_room_6', 'legacy_kos_2', 'approved', '2026-04-01', NULL, 'Generated from tagihan_bulanans #17', NULL, '2026-04-15 10:10:38', '2026-04-15 10:10:38', '2026-04-15 10:10:38'),
('legacy_bill_registration_18', 'legacy_user_22', 'legacy_room_10', 'legacy_kos_2', 'pending', '2026-04-01', NULL, 'Generated from tagihan_bulanans #18', NULL, NULL, '2026-04-15 10:10:38', '2026-04-15 10:10:38'),
('legacy_bill_registration_19', 'legacy_user_23', 'legacy_room_6', 'legacy_kos_2', 'approved', '2026-04-01', NULL, 'Generated from tagihan_bulanans #19', NULL, '2026-04-15 10:10:38', '2026-04-15 10:10:38', '2026-04-15 10:10:38'),
('legacy_bill_registration_20', 'legacy_user_24', 'legacy_room_10', 'legacy_kos_2', 'approved', '2026-04-01', NULL, 'Generated from tagihan_bulanans #20', NULL, '2026-04-15 10:10:38', '2026-04-15 10:10:38', '2026-04-15 10:10:38'),
('legacy_bill_registration_21', 'legacy_user_25', 'legacy_room_7', 'legacy_kos_2', 'pending', '2026-04-01', NULL, 'Generated from tagihan_bulanans #21', NULL, NULL, '2026-04-15 10:10:38', '2026-04-15 10:10:38'),
('legacy_bill_registration_22', 'legacy_user_26', 'legacy_room_10', 'legacy_kos_2', 'pending', '2026-04-01', NULL, 'Generated from tagihan_bulanans #22', NULL, NULL, '2026-04-15 10:10:38', '2026-04-15 10:10:38');

--
-- Legacy data converted for table `payment_history`
--
INSERT INTO `payment_history` (`id`, `registration_id`, `amount`, `period_month`, `payment_status`, `payment_method`, `proof_url`, `paid_at`, `created_at`) VALUES
('10001', 'legacy_registration_1', '1998359.00', '2026-04', 'paid', 'legacy_tagihan', NULL, '2026-04-15 11:03:04', '2026-04-15 10:09:44'),
('10002', 'legacy_bill_registration_2', '1968299.00', '2026-04', 'paid', 'legacy_tagihan', NULL, '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('10003', 'legacy_bill_registration_3', '749769.00', '2026-04', 'paid', 'legacy_tagihan', NULL, '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('10004', 'legacy_bill_registration_4', '1634183.00', '2026-04', 'paid', 'legacy_tagihan', NULL, '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('10005', 'legacy_bill_registration_5', '2973941.00', '2026-04', 'pending', 'legacy_tagihan', NULL, NULL, '2026-04-15 10:09:44'),
('10006', 'legacy_bill_registration_6', '685534.00', '2026-04', 'pending', 'legacy_tagihan', NULL, NULL, '2026-04-15 10:09:44'),
('10007', 'legacy_bill_registration_7', '2150069.00', '2026-04', 'paid', 'legacy_tagihan', NULL, '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('10008', 'legacy_bill_registration_8', '2732916.00', '2026-04', 'paid', 'legacy_tagihan', NULL, '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('10009', 'legacy_bill_registration_9', '2884406.00', '2026-04', 'pending', 'legacy_tagihan', NULL, NULL, '2026-04-15 10:09:44'),
('10010', 'legacy_bill_registration_10', '1630969.00', '2026-04', 'paid', 'legacy_tagihan', NULL, '2026-04-15 10:09:44', '2026-04-15 10:09:44'),
('10011', 'legacy_bill_registration_11', '2814198.00', '2026-04', 'pending', 'legacy_tagihan', NULL, NULL, '2026-04-15 10:09:44'),
('10012', 'legacy_registration_3', '2765278.00', '2026-04', 'paid', 'legacy_tagihan', NULL, '2026-04-15 11:02:39', '2026-04-15 10:10:37'),
('10013', 'legacy_bill_registration_13', '897055.00', '2026-04', 'paid', 'legacy_tagihan', NULL, '2026-04-15 10:10:38', '2026-04-15 10:10:38'),
('10014', 'legacy_bill_registration_14', '1410809.00', '2026-04', 'pending', 'legacy_tagihan', NULL, NULL, '2026-04-15 10:10:38'),
('10015', 'legacy_bill_registration_15', '888055.00', '2026-04', 'pending', 'legacy_tagihan', NULL, NULL, '2026-04-15 10:10:38'),
('10016', 'legacy_bill_registration_16', '2231904.00', '2026-04', 'paid', 'legacy_tagihan', NULL, '2026-04-15 10:10:38', '2026-04-15 10:10:38'),
('10017', 'legacy_bill_registration_17', '2920782.00', '2026-04', 'paid', 'legacy_tagihan', NULL, '2026-04-15 10:10:38', '2026-04-15 10:10:38'),
('10018', 'legacy_bill_registration_18', '554396.00', '2026-04', 'pending', 'legacy_tagihan', NULL, NULL, '2026-04-15 10:10:38'),
('10019', 'legacy_bill_registration_19', '2205141.00', '2026-04', 'paid', 'legacy_tagihan', NULL, '2026-04-15 10:10:38', '2026-04-15 10:10:38'),
('10020', 'legacy_bill_registration_20', '2297964.00', '2026-04', 'paid', 'legacy_tagihan', NULL, '2026-04-15 10:10:38', '2026-04-15 10:10:38'),
('10021', 'legacy_bill_registration_21', '1769358.00', '2026-04', 'pending', 'legacy_tagihan', NULL, NULL, '2026-04-15 10:10:38'),
('10022', 'legacy_bill_registration_22', '2578857.00', '2026-04', 'pending', 'legacy_tagihan', NULL, NULL, '2026-04-15 10:10:38');

--
-- Legacy data converted for table `app_notifications`
--
INSERT INTO `app_notifications` (`id`, `user_id`, `title`, `message`, `read_at`, `created_at`, `updated_at`) VALUES
('1', 'legacy_user_3', 'Odio expedita sapiente.', 'Perferendis aut et et fuga quod alias.', '2026-04-28 06:08:31', '2026-04-15 10:09:44', '2026-04-28 06:08:31'),
('2', 'legacy_user_3', 'Molestiae voluptatum inventore voluptatum.', 'Voluptatem laboriosam ipsa molestias et consequatur.', '2026-04-28 06:08:31', '2026-04-15 10:09:44', '2026-04-28 06:08:31'),
('3', 'legacy_user_3', 'Sint nemo.', 'Id nemo laborum in omnis odio quidem cum.', '2026-04-28 06:08:31', '2026-04-15 10:09:44', '2026-04-28 06:08:31'),
('4', 'legacy_user_3', 'Nostrum aliquam placeat pariatur.', 'Et repudiandae debitis beatae quisquam.', '2026-04-28 06:08:31', '2026-04-15 10:10:38', '2026-04-28 06:08:31'),
('5', 'legacy_user_3', 'Tenetur quas et aut ab.', 'Impedit et nisi eligendi illo quas consequatur hic non laborum.', '2026-04-28 06:08:31', '2026-04-15 10:10:38', '2026-04-28 06:08:31'),
('6', 'legacy_user_3', 'Debitis ullam saepe eum.', 'Fugit eos eius voluptatem occaecati maxime ut repudiandae beatae.', '2026-04-28 06:08:31', '2026-04-15 10:10:38', '2026-04-28 06:08:31'),
('7', 'legacy_user_3', 'Pembayaran tagihan berhasil', 'Tagihan bulanan Anda telah dibayar.', '2026-04-28 06:08:31', '2026-04-15 11:02:39', '2026-04-28 06:08:31'),
('8', 'legacy_user_3', 'Pembayaran tagihan berhasil', 'Tagihan bulanan Anda telah dibayar.', '2026-04-28 06:08:31', '2026-04-15 11:03:04', '2026-04-28 06:08:31'),
('9', 'legacy_user_3', 'Booking terverifikasi', 'Owner telah memverifikasi pembayaran booking Anda.', '2026-04-28 06:08:31', '2026-04-26 06:54:51', '2026-04-28 06:08:31'),
('10', 'legacy_user_3', '[FOOD] Test diskon 20%', 'Braun and Sons: Test diskon 20%', NULL, '2026-04-28 07:02:06', '2026-04-28 07:02:06'),
('11', 'legacy_user_5', '[FOOD] Test diskon 20%', 'Braun and Sons: Test diskon 20%', NULL, '2026-04-28 07:02:06', '2026-04-28 07:02:06'),
('12', 'legacy_user_6', '[FOOD] Test diskon 20%', 'Braun and Sons: Test diskon 20%', NULL, '2026-04-28 07:02:06', '2026-04-28 07:02:06'),
('13', 'legacy_user_7', '[FOOD] Test diskon 20%', 'Braun and Sons: Test diskon 20%', NULL, '2026-04-28 07:02:06', '2026-04-28 07:02:06'),
('14', 'legacy_user_8', '[FOOD] Test diskon 20%', 'Braun and Sons: Test diskon 20%', NULL, '2026-04-28 07:02:06', '2026-04-28 07:02:06'),
('15', 'legacy_user_9', '[FOOD] Test diskon 20%', 'Braun and Sons: Test diskon 20%', NULL, '2026-04-28 07:02:06', '2026-04-28 07:02:06'),
('16', 'legacy_user_10', '[FOOD] Test diskon 20%', 'Braun and Sons: Test diskon 20%', NULL, '2026-04-28 07:02:06', '2026-04-28 07:02:06'),
('17', 'legacy_user_11', '[FOOD] Test diskon 20%', 'Braun and Sons: Test diskon 20%', NULL, '2026-04-28 07:02:06', '2026-04-28 07:02:06'),
('18', 'legacy_user_12', '[FOOD] Test diskon 20%', 'Braun and Sons: Test diskon 20%', NULL, '2026-04-28 07:02:06', '2026-04-28 07:02:06'),
('19', 'legacy_user_13', '[FOOD] Test diskon 20%', 'Braun and Sons: Test diskon 20%', NULL, '2026-04-28 07:02:06', '2026-04-28 07:02:06'),
('20', 'legacy_user_14', '[FOOD] Test diskon 20%', 'Braun and Sons: Test diskon 20%', NULL, '2026-04-28 07:02:06', '2026-04-28 07:02:06'),
('21', 'legacy_user_17', '[FOOD] Test diskon 20%', 'Braun and Sons: Test diskon 20%', NULL, '2026-04-28 07:02:06', '2026-04-28 07:02:06'),
('22', 'legacy_user_18', '[FOOD] Test diskon 20%', 'Braun and Sons: Test diskon 20%', NULL, '2026-04-28 07:02:06', '2026-04-28 07:02:06'),
('23', 'legacy_user_19', '[FOOD] Test diskon 20%', 'Braun and Sons: Test diskon 20%', NULL, '2026-04-28 07:02:06', '2026-04-28 07:02:06'),
('24', 'legacy_user_20', '[FOOD] Test diskon 20%', 'Braun and Sons: Test diskon 20%', NULL, '2026-04-28 07:02:06', '2026-04-28 07:02:06'),
('25', 'legacy_user_21', '[FOOD] Test diskon 20%', 'Braun and Sons: Test diskon 20%', NULL, '2026-04-28 07:02:06', '2026-04-28 07:02:06'),
('26', 'legacy_user_22', '[FOOD] Test diskon 20%', 'Braun and Sons: Test diskon 20%', NULL, '2026-04-28 07:02:06', '2026-04-28 07:02:06'),
('27', 'legacy_user_23', '[FOOD] Test diskon 20%', 'Braun and Sons: Test diskon 20%', NULL, '2026-04-28 07:02:06', '2026-04-28 07:02:06'),
('28', 'legacy_user_24', '[FOOD] Test diskon 20%', 'Braun and Sons: Test diskon 20%', NULL, '2026-04-28 07:02:06', '2026-04-28 07:02:06'),
('29', 'legacy_user_25', '[FOOD] Test diskon 20%', 'Braun and Sons: Test diskon 20%', NULL, '2026-04-28 07:02:06', '2026-04-28 07:02:06'),
('30', 'legacy_user_26', '[FOOD] Test diskon 20%', 'Braun and Sons: Test diskon 20%', NULL, '2026-04-28 07:02:06', '2026-04-28 07:02:06'),
('31', 'legacy_user_3', 'Booking berhasil dibuat', 'Segera lakukan pembayaran untuk memproses booking kamar.', NULL, '2026-05-05 08:41:27', '2026-05-05 08:41:27'),
('32', 'legacy_user_3', 'Booking berhasil dibuat', 'Segera lakukan pembayaran untuk memproses booking kamar.', NULL, '2026-05-05 08:50:34', '2026-05-05 08:50:34'),
('33', 'legacy_user_3', 'Booking berhasil dibuat', 'Segera lakukan pembayaran untuk memproses booking kamar.', NULL, '2026-05-05 08:52:11', '2026-05-05 08:52:11'),
('34', 'legacy_user_3', 'Booking berhasil dibuat', 'Segera lakukan pembayaran untuk memproses booking kamar.', NULL, '2026-05-05 08:57:31', '2026-05-05 08:57:31'),
('35', 'legacy_user_3', 'Booking berhasil dibuat', 'Segera lakukan pembayaran untuk memproses booking kamar.', NULL, '2026-05-05 09:01:26', '2026-05-05 09:01:26'),
('36', 'legacy_user_3', 'Booking berhasil dibuat', 'Segera lakukan pembayaran untuk memproses booking kamar.', NULL, '2026-05-05 09:08:39', '2026-05-05 09:08:39'),
('37', 'legacy_user_3', 'Booking berhasil dibuat', 'Segera lakukan pembayaran untuk memproses booking kamar.', NULL, '2026-05-05 09:12:35', '2026-05-05 09:12:35'),
('38', 'legacy_user_3', 'Booking berhasil dibuat', 'Segera lakukan pembayaran untuk memproses booking kamar.', NULL, '2026-05-05 09:42:39', '2026-05-05 09:42:39'),
('39', 'legacy_user_3', 'Booking berhasil dibuat', 'Segera lakukan pembayaran untuk memproses booking kamar.', NULL, '2026-05-05 10:13:55', '2026-05-05 10:13:55'),
('40', 'legacy_user_3', 'Pembayaran berhasil', 'Pembayaran booking kos Anda telah diterima.', NULL, '2026-05-05 10:34:48', '2026-05-05 10:34:48'),
('41', 'legacy_user_3', 'Booking berhasil dibuat', 'Segera lakukan pembayaran untuk memproses booking kamar.', NULL, '2026-05-05 11:08:33', '2026-05-05 11:08:33'),
('42', 'legacy_user_3', 'Booking berhasil dibuat', 'Segera lakukan pembayaran untuk memproses booking kamar.', NULL, '2026-05-05 11:09:51', '2026-05-05 11:09:51'),
('43', 'legacy_user_3', 'Pembayaran berhasil', 'Pembayaran booking kos Anda telah diterima.', NULL, '2026-05-05 11:13:17', '2026-05-05 11:13:17'),
('44', 'legacy_user_27', 'Selamat datang di Ngekos', 'Akun Anda berhasil dibuat. Lengkapi profil untuk mulai memakai layanan concierge.', NULL, '2026-05-10 05:26:47', '2026-05-10 05:26:47'),
('45', 'legacy_user_28', 'Selamat datang di Ngekos', 'Akun Anda berhasil dibuat. Lengkapi profil untuk mulai memakai layanan concierge.', NULL, '2026-05-10 05:28:14', '2026-05-10 05:28:14'),
('46', 'legacy_user_29', 'Selamat datang di Ngekos', 'Akun Anda berhasil dibuat. Lengkapi profil untuk mulai memakai layanan concierge.', NULL, '2026-05-10 05:29:35', '2026-05-10 05:29:35'),
('47', 'legacy_user_28', 'Akun berhasil diverifikasi', 'Admin telah memverifikasi akun Anda. Semua fitur role sekarang dapat digunakan.', NULL, '2026-05-10 05:37:20', '2026-05-10 05:37:20'),
('48', 'legacy_user_29', 'Akun berhasil diverifikasi', 'Admin telah memverifikasi akun Anda. Semua fitur role sekarang dapat digunakan.', NULL, '2026-05-10 05:37:23', '2026-05-10 05:37:23'),
('49', 'legacy_user_27', 'Pembayaran berhasil', 'Pembayaran order Anda telah diterima.', NULL, '2026-05-10 22:00:35', '2026-05-10 22:00:35'),
('50', 'legacy_user_3', 'Booking berhasil dibuat', 'Segera lakukan pembayaran untuk memproses booking kamar.', NULL, '2026-05-11 07:39:28', '2026-05-11 07:39:28'),
('51', 'legacy_user_3', 'Pembayaran berhasil', 'Pembayaran booking kos Anda telah diterima.', NULL, '2026-05-11 07:43:55', '2026-05-11 07:43:55'),
('52', 'legacy_user_3', 'Pembayaran berhasil', 'Pembayaran order Anda telah diterima.', NULL, '2026-05-11 19:18:08', '2026-05-11 19:18:08');

--
-- Legacy data converted for table `migrations`
--
INSERT INTO `migrations` (`id`, `migration`, `batch`) VALUES
('1', '0001_01_01_000000_create_users_table', '1'),
('2', '0001_01_01_000001_create_cache_table', '1'),
('3', '0001_01_01_000002_create_jobs_table', '1'),
('4', '2026_04_15_164245_create_kos_table', '1'),
('5', '2026_04_15_164246_create_kamars_table', '1'),
('6', '2026_04_15_164246_create_transaksi_kos_table', '1'),
('7', '2026_04_15_164247_create_tagihan_bulanans_table', '1'),
('8', '2026_04_15_164248_create_merchants_table', '1'),
('9', '2026_04_15_164248_create_products_table', '1'),
('10', '2026_04_15_164249_create_order_items_table', '1'),
('11', '2026_04_15_164249_create_orders_table', '1'),
('12', '2026_04_15_164250_create_app_notifications_table', '1'),
('13', '2026_04_15_164250_create_payments_table', '1'),
('14', '2026_04_15_170100_add_foreign_keys_to_order_items_table', '1'),
('15', '2026_05_05_150000_add_midtrans_fields_to_payments_table', '2');

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
-- Indexes for table `app_notifications`
--
ALTER TABLE `app_notifications`
  ADD PRIMARY KEY (`id`),
  ADD KEY `app_notifications_user_id_foreign` (`user_id`);

--
-- Indexes for table `cache`
--
ALTER TABLE `cache`
  ADD PRIMARY KEY (`key`),
  ADD KEY `cache_expiration_index` (`expiration`);

--
-- Indexes for table `cache_locks`
--
ALTER TABLE `cache_locks`
  ADD PRIMARY KEY (`key`),
  ADD KEY `cache_locks_expiration_index` (`expiration`);

--
-- Indexes for table `failed_jobs`
--
ALTER TABLE `failed_jobs`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `failed_jobs_uuid_unique` (`uuid`);

--
-- Indexes for table `job_batches`
--
ALTER TABLE `job_batches`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `jobs`
--
ALTER TABLE `jobs`
  ADD PRIMARY KEY (`id`),
  ADD KEY `jobs_queue_index` (`queue`);

--
-- Indexes for table `migrations`
--
ALTER TABLE `migrations`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `orders`
--
ALTER TABLE `orders`
  ADD PRIMARY KEY (`id`),
  ADD KEY `orders_user_id_foreign` (`user_id`),
  ADD KEY `orders_merchant_id_foreign` (`merchant_id`);

--
-- Indexes for table `order_items`
--
ALTER TABLE `order_items`
  ADD PRIMARY KEY (`id`),
  ADD KEY `order_items_order_id_foreign` (`order_id`),
  ADD KEY `order_items_product_id_foreign` (`product_id`);

--
-- Indexes for table `password_reset_tokens`
--
ALTER TABLE `password_reset_tokens`
  ADD PRIMARY KEY (`email`);

--
-- Indexes for table `products`
--
ALTER TABLE `products`
  ADD PRIMARY KEY (`id`),
  ADD KEY `products_merchant_id_foreign` (`merchant_id`);

--
-- Indexes for table `sessions`
--
ALTER TABLE `sessions`
  ADD PRIMARY KEY (`id`),
  ADD KEY `sessions_user_id_index` (`user_id`),
  ADD KEY `sessions_last_activity_index` (`last_activity`);

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
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=12;

--
-- AUTO_INCREMENT for table `registration_documents`
--
ALTER TABLE `registration_documents`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;


--
-- AUTO_INCREMENT for table `app_notifications`
--
ALTER TABLE `app_notifications`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `failed_jobs`
--
ALTER TABLE `failed_jobs`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `jobs`
--
ALTER TABLE `jobs`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `migrations`
--
ALTER TABLE `migrations`
  MODIFY `id` int UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `orders`
--
ALTER TABLE `orders`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `order_items`
--
ALTER TABLE `order_items`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `products`
--
ALTER TABLE `products`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

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

--
-- Constraints for table `app_notifications`
--
ALTER TABLE `app_notifications`
  ADD CONSTRAINT `app_notifications_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `orders`
--
ALTER TABLE `orders`
  ADD CONSTRAINT `orders_merchant_id_foreign` FOREIGN KEY (`merchant_id`) REFERENCES `merchants` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `orders_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `order_items`
--
ALTER TABLE `order_items`
  ADD CONSTRAINT `order_items_order_id_foreign` FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `order_items_product_id_foreign` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `products`
--
ALTER TABLE `products`
  ADD CONSTRAINT `products_merchant_id_foreign` FOREIGN KEY (`merchant_id`) REFERENCES `merchants` (`id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;

