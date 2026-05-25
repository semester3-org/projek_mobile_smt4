import 'dart:convert';

import 'package:flutter/material.dart';

import '../../data/repositories/merchant_repository.dart';

class MerchantPalette {
  MerchantPalette._();

  static const Color primary = Color(0xFF00508F);
  static const Color primaryLight = Color(0xFF0B63B6);
  static const Color softBlue = Color(0xFFEAF3FF);
  static const Color background = Color(0xFFF6F8FC);
  static const Color surface = Colors.white;
  static const Color text = Color(0xFF20242A);
  static const Color muted = Color(0xFF667085);
  static const Color border = Color(0xFFE0E6EF);
  static const Color success = Color(0xFF18B66A);
  static const Color danger = Color(0xFFD82121);
  static const Color warning = Color(0xFFE66000);

  static BoxShadow shadow({double opacity = 0.08}) {
    return BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: opacity),
      blurRadius: 22,
      offset: const Offset(0, 12),
    );
  }
}

String formatMerchantCurrency(num amount) {
  return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      )}';
}

class MerchantTopBar extends StatelessWidget {
  const MerchantTopBar({
    super.key,
    required this.title,
    this.showAvatar = true,
    this.showBack = false,
    this.actionLabel,
    this.actionIcon,
    this.onBack,
    this.onAction,
  });

  final String title;
  final bool showAvatar;
  final bool showBack;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onBack;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFECEFF5))),
      ),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              color: MerchantPalette.primary,
              onPressed: onBack ?? () => Navigator.maybePop(context),
            )
          else if (showAvatar)
            const _MerchantAvatar(),
          if (showBack || showAvatar) const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: MerchantPalette.primary,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (actionLabel != null)
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: MerchantPalette.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              child: Text(actionLabel!),
            )
          else
            _MerchantTopBarIconButton(
              icon: actionIcon ?? Icons.notifications_none_rounded,
              onPressed: onAction,
            ),
        ],
      ),
    );
  }
}

class _MerchantTopBarIconButton extends StatelessWidget {
  const _MerchantTopBarIconButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isNotificationIcon = icon == Icons.notifications_none_rounded;
    if (!isNotificationIcon) {
      return IconButton(
        onPressed: onPressed,
        color: MerchantPalette.primary,
        icon: Icon(icon),
      );
    }

    return FutureBuilder<bool>(
      future: MerchantRepository.hasUnreadNotifications(),
      builder: (context, snapshot) {
        final hasUnread = snapshot.data == true;
        return IconButton(
          onPressed: onPressed,
          color: MerchantPalette.primary,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon),
              if (hasUnread)
                Positioned(
                  right: -1,
                  top: -1,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: MerchantPalette.danger,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class MerchantPage extends StatelessWidget {
  const MerchantPage({
    super.key,
    required this.children,
    this.topBar,
    this.padding = const EdgeInsets.fromLTRB(24, 20, 24, 24),
    this.floatingActionButton,
    this.bottomBar,
  });

  final Widget? topBar;
  final List<Widget> children;
  final EdgeInsets padding;
  final Widget? floatingActionButton;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MerchantPalette.background,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomBar,
      body: SafeArea(
        child: Column(
          children: [
            if (topBar != null) topBar!,
            Expanded(
              child: SingleChildScrollView(
                padding: padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MerchantCard extends StatelessWidget {
  const MerchantCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.color = Colors.white,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: MerchantPalette.border.withValues(alpha: 0.7),
        ),
        boxShadow: [MerchantPalette.shadow(opacity: 0.06)],
      ),
      child: child,
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class MerchantSectionHeader extends StatelessWidget {
  const MerchantSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.trailing,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: MerchantPalette.text,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (trailing != null) trailing!,
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel!,
              style: const TextStyle(
                color: MerchantPalette.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class MerchantStatusPill extends StatelessWidget {
  const MerchantStatusPill({
    super.key,
    required this.label,
    required this.color,
    this.background,
  });

  final String label;
  final Color color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.13),
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

class MerchantMetricCard extends StatelessWidget {
  const MerchantMetricCard({
    super.key,
    required this.title,
    required this.value,
    this.icon,
    this.trailing,
    this.subtitle,
  });

  final String title;
  final String value;
  final IconData? icon;
  final Widget? trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return MerchantCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: MerchantPalette.primary, size: 18),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: subtitle == null
                        ? MerchantPalette.primary
                        : MerchantPalette.muted,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: MerchantPalette.text,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: const TextStyle(
                color: MerchantPalette.primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MerchantPromoBanner extends StatelessWidget {
  const MerchantPromoBanner({
    super.key,
    required this.title,
    this.buttonLabel = 'Buat Promo',
    this.onPressed,
  });

  final String title;
  final String buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [MerchantPalette.primary, MerchantPalette.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [MerchantPalette.shadow(opacity: 0.14)],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -22,
            bottom: -30,
            child: Icon(
              Icons.campaign_rounded,
              size: 96,
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 235),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    height: 1.14,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: MerchantPalette.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Text(
                  buttonLabel,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MerchantSearchField extends StatelessWidget {
  const MerchantSearchField({
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MerchantPalette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MerchantPalette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: MerchantPalette.primary, width: 1.4),
        ),
      ),
    );
  }
}

class MerchantFilterChips extends StatelessWidget {
  const MerchantFilterChips({
    super.key,
    required this.labels,
    this.selectedIndex = 0,
    this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onSelected == null ? null : () => onSelected!(i),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: i == selectedIndex
                      ? MerchantPalette.primary
                      : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: i == selectedIndex
                        ? MerchantPalette.primary
                        : const Color(0xFFC9D3E1),
                  ),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    color: i == selectedIndex
                        ? Colors.white
                        : MerchantPalette.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (i < labels.length - 1) const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }
}

class MerchantImage extends StatelessWidget {
  const MerchantImage({
    super.key,
    required this.url,
    required this.icon,
    this.width,
    this.height,
    this.borderRadius,
    this.fit = BoxFit.cover,
  });

  final String url;
  final IconData icon;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    ImageProvider? memoryProvider;
    if (url.startsWith('data:image')) {
      final comma = url.indexOf(',');
      if (comma > -1) {
        try {
          memoryProvider = MemoryImage(base64Decode(url.substring(comma + 1)));
        } catch (_) {
          memoryProvider = null;
        }
      }
    }

    final fallback = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1F8),
        borderRadius: borderRadius,
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: MerchantPalette.primary, size: 42),
    );

    final image = memoryProvider != null
        ? Image(
            image: memoryProvider,
            width: width,
            height: height,
            fit: fit,
          )
        : Image.network(
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

class MerchantBottomSpacer extends StatelessWidget {
  const MerchantBottomSpacer({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 28);
  }
}

class _MerchantAvatar extends StatelessWidget {
  const _MerchantAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFC7F0F2), Color(0xFF9FC5DD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [MerchantPalette.shadow(opacity: 0.07)],
      ),
      child: const Icon(
        Icons.storefront_rounded,
        size: 19,
        color: MerchantPalette.primary,
      ),
    );
  }
}
