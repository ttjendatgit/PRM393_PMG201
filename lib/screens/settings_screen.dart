import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/page_frame.dart';
import '../widgets/page_title.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  bool _obscureKey = true;
  bool _saved = false;

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  void _saveKey() {
    // TODO: persist API key via shared_preferences or similar
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageTitle(
            title: 'Settings',
            subtitle:
                'Configure your AI provider credentials and application preferences.',
          ),
          const SizedBox(height: 32),

          // ── API Key Card ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.key_rounded, color: AppColors.primary),
                    SizedBox(width: 12),
                    Text(
                      'AI API Key',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter your Gemini or OpenAI API key to enable real AI grading. '
                  'The key is stored locally and never sent to any server.',
                  style: TextStyle(color: AppColors.muted, height: 1.5),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _apiKeyController,
                  obscureText: _obscureKey,
                  style: const TextStyle(color: AppColors.text),
                  decoration: InputDecoration(
                    hintText: 'Paste your API key here...',
                    hintStyle: const TextStyle(color: AppColors.outline),
                    filled: true,
                    fillColor: AppColors.surfaceHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureKey
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: AppColors.muted,
                      ),
                      onPressed: () =>
                          setState(() => _obscureKey = !_obscureKey),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryContainer,
                        foregroundColor: AppColors.text,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _saveKey,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text(
                        'Save API Key',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (_saved)
                      const Row(
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: AppColors.primary, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Saved!',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Info Card ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: AppColors.muted, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Phase 1 runs in mock-AI mode. Providing a real API key will '
                    'unlock live Gemini / OpenAI grading in Phase 2.',
                    style: TextStyle(color: AppColors.muted, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
