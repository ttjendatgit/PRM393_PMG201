import 'package:flutter/material.dart';

import '../features/auth/models/user_profile.dart';
import '../theme/app_colors.dart';

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.title,
    this.backendOnline,
    this.user,
  });

  final String       title;
  final bool?        backendOnline;
  final UserProfile? user;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        children: [
          // ── Search bar ─────────────────────────────────────────────────
          Container(
            height: 38,
            width:  320,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color:        AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(20),
              border:       Border.all(color: AppColors.outline),
            ),
            child: const Row(
              children: [
                Icon(Icons.search_rounded, color: AppColors.muted, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Search assessments, submissions…',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // ── Backend status badge ────────────────────────────────────────
          _BackendBadge(online: backendOnline),
          const SizedBox(width: 24),
          // ── User avatar + name ──────────────────────────────────────────
          if (user != null) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryContainer,
              child: Text(
                _initials(user!.displayName),
                style: const TextStyle(
                  color:      AppColors.primary,
                  fontSize:   12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              user!.displayName,
              style: const TextStyle(
                color:      AppColors.text,
                fontSize:   13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BackendBadge extends StatelessWidget {
  const _BackendBadge({required this.online});
  final bool? online;

  @override
  Widget build(BuildContext context) {
    final Color  dotColor;
    final String label;
    final Color  textColor;

    if (online == null) {
      dotColor  = AppColors.muted;
      label     = 'Checking…';
      textColor = AppColors.muted;
    } else if (online!) {
      dotColor  = AppColors.success;
      label     = 'Connected';
      textColor = AppColors.success;
    } else {
      dotColor  = AppColors.error;
      label     = 'Disconnected';
      textColor = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:        online == true
            ? const Color(0xFFF0FDF4)
            : online == false
                ? const Color(0xFFFEF2F2)
                : AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(
          color: online == true
              ? const Color(0xFFBBF7D0)
              : online == false
                  ? const Color(0xFFFECACA)
                  : AppColors.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7, height: 7,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
