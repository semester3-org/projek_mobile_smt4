import 'package:flutter/material.dart';

import 'user_theme.dart';

String formatUserCurrency(num amount) {
  return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]}.',
  )}';
}

String formatShortDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
}

class UserSearchField extends StatelessWidget {
  const UserSearchField({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.blueGrey.shade100),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.blueGrey.shade100),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: UserTheme.primary, width: 1.4),
        ),
      ),
    );
  }
}

class UserFilterChip extends StatelessWidget {
  const UserFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: UserTheme.primary,
        backgroundColor: Colors.white,
        side: BorderSide(
          color: selected ? UserTheme.primary : const Color(0xFFD7E3F4),
        ),
        labelStyle: TextStyle(
          color: selected ? Colors.white : UserTheme.primaryDark,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}

class RatingBadge extends StatelessWidget {
  const RatingBadge({
    super.key,
    required this.rating,
    this.reviewCount,
  });

  final double rating;
  final int? reviewCount;

  @override
  Widget build(BuildContext context) {
    final reviews = reviewCount == null ? '' : ' (${reviewCount!}+)';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [UserTheme.softShadow(opacity: 0.08)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 18),
          const SizedBox(width: 3),
          Text(
            '${rating.toStringAsFixed(1)}$reviews',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class UserTag extends StatelessWidget {
  const UserTag({
    super.key,
    required this.label,
    this.color = UserTheme.primary,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class UserImage extends StatelessWidget {
  const UserImage({
    super.key,
    required this.url,
    required this.icon,
    this.borderRadius,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
  });

  final String url;
  final IconData icon;
  final BorderRadius? borderRadius;
  final double? height;
  final double? width;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final fallback = SizedBox(
      width: width,
      height: height,
      child: _ImageFallback(icon: icon),
    );
    final image = Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => fallback,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return fallback;
      },
    );

    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEAF1F8),
      alignment: Alignment.center,
      child: Icon(icon, size: 46, color: UserTheme.primary),
    );
  }
}

class UserSectionHeader extends StatelessWidget {
  const UserSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: UserTheme.text,
                ),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel!,
              style: const TextStyle(
                color: UserTheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class UserBottomSpacer extends StatelessWidget {
  const UserBottomSpacer({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 24);
  }
}
