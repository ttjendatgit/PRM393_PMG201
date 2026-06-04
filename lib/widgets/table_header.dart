import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class TableHeader extends StatelessWidget {
  const TableHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
      ),
    );
  }
}
