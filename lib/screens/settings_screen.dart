import 'package:flutter/material.dart';
import '../models/ai_mode.dart';
import '../theme/app_colors.dart';
import '../widgets/page_frame.dart';
import '../widgets/page_title.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.apiKey,
    required this.modelId,
    required this.aiMode,
    required this.onSaveApiKey,
    required this.onClearApiKey,
    required this.onSaveModelId,
    required this.onChangeAiMode,
  });

  final String apiKey;
  final String modelId;
  final AiMode aiMode;
  final ValueChanged<String> onSaveApiKey;
  final VoidCallback onClearApiKey;
  final ValueChanged<String> onSaveModelId;
  final ValueChanged<AiMode> onChangeAiMode;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _modelIdController = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _apiKeyController.text = widget.apiKey;
    _modelIdController.text = widget.modelId;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _modelIdController.dispose();
    super.dispose();
  }

  void _saveApiKey() {
    final key = _apiKeyController.text.trim();
    widget.onSaveApiKey(key);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(key.isEmpty
                  ? 'OpenRouter API key cleared.'
                  : 'OpenRouter API key saved for this session.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _clearApiKey() {
    _apiKeyController.clear();
    widget.onClearApiKey();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API key cleared.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _saveModelId() {
    final id = _modelIdController.text.trim();
    widget.onSaveModelId(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(id.isEmpty ? 'Model ID cleared.' : 'Model ID saved: $id'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PageTitle(
              title: 'Settings',
              subtitle:
                  'Configure your AI provider, API key, model, and grading mode for this session.',
            ),
            const SizedBox(height: 32),
            _buildApiKeySection(),
            const SizedBox(height: 24),
            _buildModelSection(),
            const SizedBox(height: 24),
            _buildAiModeSection(),
            const SizedBox(height: 24),
            _buildSecuritySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildApiKeySection() {
    return _SettingsCard(
      title: 'OPENROUTER API KEY',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _apiKeyController,
            obscureText: _obscure,
            style: const TextStyle(color: AppColors.text, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: 'sk-or-v1-...',
              hintStyle: const TextStyle(color: AppColors.muted),
              filled: true,
              fillColor: AppColors.surfaceHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: AppColors.muted,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Stored in memory only for this session. Never written to disk or committed to version control.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  foregroundColor: AppColors.text,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _saveApiKey,
                icon: const Icon(Icons.save_rounded),
                label: const Text(
                  'Save API Key',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error.withAlpha(160)),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _clearApiKey,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text(
                  'Clear API Key',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModelSection() {
    return _SettingsCard(
      title: 'MODEL ID',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _modelIdController,
            style: const TextStyle(color: AppColors.text, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: 'openrouter/free',
              hintStyle: const TextStyle(color: AppColors.muted),
              filled: true,
              fillColor: AppColors.surfaceHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Any model available on OpenRouter. Browse openrouter.ai/models for IDs.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _ModelChip(
                label: 'OpenRouter Free (default)',
                modelId: 'openrouter/free',
                onTap: () {
                  _modelIdController.text = 'openrouter/free';
                },
              ),
              _ModelChip(
                label: 'Llama 3.1 8B (free)',
                modelId: 'meta-llama/llama-3.1-8b-instruct:free',
                onTap: () {
                  _modelIdController.text =
                      'meta-llama/llama-3.1-8b-instruct:free';
                },
              ),
              _ModelChip(
                label: 'GPT-4o Mini (paid)',
                modelId: 'openai/gpt-4o-mini',
                onTap: () {
                  _modelIdController.text = 'openai/gpt-4o-mini';
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryContainer,
              foregroundColor: AppColors.text,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _saveModelId,
            icon: const Icon(Icons.save_rounded),
            label: const Text(
              'Save Model',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiModeSection() {
    return _SettingsCard(
      title: 'AI MODE',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<AiMode>(
            style: SegmentedButton.styleFrom(
              backgroundColor: AppColors.surfaceHigh,
              foregroundColor: AppColors.muted,
              selectedForegroundColor: AppColors.text,
              selectedBackgroundColor: AppColors.primaryContainer,
              side: const BorderSide(color: AppColors.outlineVariant),
            ),
            segments: const [
              ButtonSegment(
                value: AiMode.mock,
                label: Text('Mock AI'),
                icon: Icon(Icons.science_rounded),
              ),
              ButtonSegment(
                value: AiMode.openRouter,
                label: Text('OpenRouter AI'),
                icon: Icon(Icons.hub_rounded),
              ),
            ],
            selected: {widget.aiMode},
            onSelectionChanged: (Set<AiMode> selected) {
              widget.onChangeAiMode(selected.first);
            },
          ),
          const SizedBox(height: 14),
          _ModeInfoRow(
            icon: Icons.science_rounded,
            label: 'Mock AI',
            description:
                'No API key required. Returns sample scores for testing the grading workflow.',
            active: widget.aiMode == AiMode.mock,
          ),
          const SizedBox(height: 8),
          _ModeInfoRow(
            icon: Icons.hub_rounded,
            label: 'OpenRouter AI',
            description:
                'Routes through OpenRouter to your chosen model. Requires a valid API key and model ID. '
                'Grades based on the loaded assessment rubric. Supports Vietnamese and English submissions.',
            active: widget.aiMode == AiMode.openRouter,
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySection() {
    return _SettingsCard(
      title: 'SECURITY NOTES',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(
            icon: Icons.lock_rounded,
            text: 'API key and model ID are held in memory only — never written to disk.',
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.code_off_rounded,
            text: 'API key is never committed to version control.',
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.shield_rounded,
            text:
                'Student submissions are sent only to OpenRouter (openrouter.ai) '
                'when OpenRouter AI mode is active.',
          ),
        ],
      ),
    );
  }
}

class _ModelChip extends StatelessWidget {
  const _ModelChip({
    required this.label,
    required this.modelId,
    required this.onTap,
  });

  final String label;
  final String modelId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              modelId,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 640),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ModeInfoRow extends StatelessWidget {
  const _ModeInfoRow({
    required this.icon,
    required this.label,
    required this.description,
    required this.active,
  });

  final IconData icon;
  final String label;
  final String description;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: active ? AppColors.primary : AppColors.muted),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                    color: active ? AppColors.primary : AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: description,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.muted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
