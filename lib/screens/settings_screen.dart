import 'package:flutter/material.dart';
import '../models/ai_mode.dart';
import '../theme/app_colors.dart';
import '../widgets/page_frame.dart';
import '../widgets/page_title.dart';
import '../features/auth/models/login_request.dart';
import '../features/auth/models/user_profile.dart';
import '../features/auth/services/auth_service.dart';
import '../core/network/api_exception.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.apiKey,
    required this.modelId,
    required this.geminiApiKey,
    required this.geminiModelId,
    required this.aiMode,
    required this.onSaveApiKey,
    required this.onClearApiKey,
    required this.onSaveModelId,
    required this.onSaveGeminiApiKey,
    required this.onClearGeminiApiKey,
    required this.onSaveGeminiModelId,
    required this.onChangeAiMode,
    this.backendAssessmentId,
    this.onSetBackendAssessmentId,
  });

  // OpenRouter
  final String apiKey;
  final String modelId;
  final ValueChanged<String> onSaveApiKey;
  final VoidCallback onClearApiKey;
  final ValueChanged<String> onSaveModelId;

  // Gemini
  final String geminiApiKey;
  final String geminiModelId;
  final ValueChanged<String> onSaveGeminiApiKey;
  final VoidCallback onClearGeminiApiKey;
  final ValueChanged<String> onSaveGeminiModelId;

  final AiMode aiMode;
  final ValueChanged<AiMode> onChangeAiMode;

  // Backend
  final String? backendAssessmentId;
  final ValueChanged<String>? onSetBackendAssessmentId;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _orKeyController = TextEditingController();
  final _orModelController = TextEditingController();
  final _geminiKeyController = TextEditingController();
  final _geminiModelController = TextEditingController();

  // Backend connection test
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _backendLoading = false;
  String? _backendStatus;
  bool _backendIsError = false;
  UserProfile? _loggedInUser;
  bool _passwordVisible = false;

  bool _orObscure = true;
  bool _geminiObscure = true;

  @override
  void initState() {
    super.initState();
    _orKeyController.text = widget.apiKey;
    _orModelController.text = widget.modelId;
    _geminiKeyController.text = widget.geminiApiKey;
    _geminiModelController.text = widget.geminiModelId;
  }

  @override
  void dispose() {
    _orKeyController.dispose();
    _orModelController.dispose();
    _geminiKeyController.dispose();
    _geminiModelController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _backendAssessmentIdController.dispose();
    super.dispose();
  }

  // ── OpenRouter callbacks ───────────────────────────────────────────────────

  void _saveOrKey() {
    final key = _orKeyController.text.trim();
    widget.onSaveApiKey(key);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(key.isEmpty
            ? 'OpenRouter API key cleared.'
            : 'OpenRouter API key saved for this session.'),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  void _clearOrKey() {
    _orKeyController.clear();
    widget.onClearApiKey();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('OpenRouter API key cleared.'),
        duration: Duration(seconds: 2),
      ));
    }
  }

  void _saveOrModel() {
    final id = _orModelController.text.trim();
    widget.onSaveModelId(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(id.isEmpty ? 'Model ID cleared.' : 'OpenRouter model saved: $id'),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  // ── Gemini callbacks ───────────────────────────────────────────────────────

  void _saveGeminiKey() {
    final key = _geminiKeyController.text.trim();
    widget.onSaveGeminiApiKey(key);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(key.isEmpty
            ? 'Gemini API key cleared.'
            : 'Gemini API key saved for this session.'),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  void _clearGeminiKey() {
    _geminiKeyController.clear();
    widget.onClearGeminiApiKey();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Gemini API key cleared.'),
        duration: Duration(seconds: 2),
      ));
    }
  }

  void _saveGeminiModel() {
    final id = _geminiModelController.text.trim();
    widget.onSaveGeminiModelId(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(id.isEmpty ? 'Model ID cleared.' : 'Gemini model saved: $id'),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
            _buildAiModeSection(),
            const SizedBox(height: 24),
            if (widget.aiMode == AiMode.backend) ...[
              _buildBackendAssessmentIdSection(),
              const SizedBox(height: 24),
            ],
            _buildOrKeySection(),
            const SizedBox(height: 24),
            _buildOrModelSection(),
            const SizedBox(height: 24),
            _buildGeminiSection(),
            const SizedBox(height: 24),
            _buildSecuritySection(),
            const SizedBox(height: 24),
            _buildBackendSection(),
          ],
        ),
      ),
    );
  }

  // ── AI Mode ────────────────────────────────────────────────────────────────

  Widget _buildAiModeSection() {
    return _SettingsCard(
      title: 'AI PROVIDER',
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
                label: Text('OpenRouter'),
                icon: Icon(Icons.hub_rounded),
              ),
              ButtonSegment(
                value: AiMode.gemini,
                label: Text('Gemini'),
                icon: Icon(Icons.auto_awesome_rounded),
              ),
              ButtonSegment(
                value: AiMode.backend,
                label: Text('Backend'),
                icon: Icon(Icons.cloud_rounded),
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
            label: 'OpenRouter',
            description:
                'Routes through OpenRouter to your chosen model. '
                'Requires a valid OpenRouter API key (sk-or-v1-...) and model ID. '
                'Grades based on the loaded assessment rubric. Supports Vietnamese and English.',
            active: widget.aiMode == AiMode.openRouter,
          ),
          const SizedBox(height: 8),
          _ModeInfoRow(
            icon: Icons.auto_awesome_rounded,
            label: 'Gemini',
            description:
                'Calls Google Gemini directly. Free tier available with a Google AI Studio key (AIza...). '
                'Same rubric-based grading. Supports Vietnamese and English submissions.',
            active: widget.aiMode == AiMode.gemini,
          ),
          const SizedBox(height: 8),
          _ModeInfoRow(
            icon: Icons.cloud_rounded,
            label: 'Backend API',
            description:
                'Connects to the ASP.NET backend API. '
                'All grading is done server-side. Requires a running backend and a valid assessment ID. '
                'Login first via the Backend Connection Test below.',
            active: widget.aiMode == AiMode.backend,
          ),
        ],
      ),
    );
  }

  // ── OpenRouter ─────────────────────────────────────────────────────────────

  Widget _buildOrKeySection() {
    return _SettingsCard(
      title: 'OPENROUTER API KEY',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _orKeyController,
            obscureText: _orObscure,
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
                  _orObscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: AppColors.muted,
                ),
                onPressed: () => setState(() => _orObscure = !_orObscure),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Stored in memory only for this session. Never written to disk.',
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
                onPressed: _saveOrKey,
                icon: const Icon(Icons.save_rounded),
                label: const Text(
                  'Save Key',
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
                onPressed: _clearOrKey,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text(
                  'Clear Key',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrModelSection() {
    return _SettingsCard(
      title: 'OPENROUTER MODEL',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _orModelController,
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
                onTap: () => _orModelController.text = 'openrouter/free',
              ),
              _ModelChip(
                label: 'Llama 3.1 8B (free)',
                modelId: 'meta-llama/llama-3.1-8b-instruct:free',
                onTap: () => _orModelController.text =
                    'meta-llama/llama-3.1-8b-instruct:free',
              ),
              _ModelChip(
                label: 'GPT-4o Mini (paid)',
                modelId: 'openai/gpt-4o-mini',
                onTap: () => _orModelController.text = 'openai/gpt-4o-mini',
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
            onPressed: _saveOrModel,
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

  // ── Gemini ─────────────────────────────────────────────────────────────────

  Widget _buildGeminiSection() {
    return _SettingsCard(
      title: 'GEMINI (GOOGLE AI)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Key field
          const Text(
            'API KEY',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _geminiKeyController,
            obscureText: _geminiObscure,
            style: const TextStyle(color: AppColors.text, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: 'AIza...',
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
                  _geminiObscure
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: AppColors.muted,
                ),
                onPressed: () =>
                    setState(() => _geminiObscure = !_geminiObscure),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Get a free key at aistudio.google.com. Stored in memory only.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
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
                onPressed: _saveGeminiKey,
                icon: const Icon(Icons.save_rounded),
                label: const Text(
                  'Save Key',
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
                onPressed: _clearGeminiKey,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text(
                  'Clear Key',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Model field
          const Text(
            'MODEL',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _geminiModelController,
            style: const TextStyle(color: AppColors.text, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: 'gemini-2.0-flash-lite',
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
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _ModelChip(
                label: 'Flash Lite (free, fast)',
                modelId: 'gemini-2.0-flash-lite',
                onTap: () =>
                    _geminiModelController.text = 'gemini-2.0-flash-lite',
              ),
              _ModelChip(
                label: 'Flash 2.0 (free)',
                modelId: 'gemini-2.0-flash',
                onTap: () =>
                    _geminiModelController.text = 'gemini-2.0-flash',
              ),
              _ModelChip(
                label: 'Flash 1.5 (free)',
                modelId: 'gemini-1.5-flash',
                onTap: () =>
                    _geminiModelController.text = 'gemini-1.5-flash',
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
            onPressed: _saveGeminiModel,
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

  // ── Backend connection test ────────────────────────────────────────────────

  Future<void> _testLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _backendStatus = 'Enter email and password first.';
        _backendIsError = true;
      });
      return;
    }
    setState(() {
      _backendLoading = true;
      _backendStatus = null;
      _backendIsError = false;
      _loggedInUser = null;
    });
    try {
      final profile = await AuthService.login(
        LoginRequest(email: email, password: password),
      );
      setState(() {
        _backendLoading = false;
        _loggedInUser = profile;
        _backendStatus = 'Logged in as ${profile.displayName}';
        _backendIsError = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _backendLoading = false;
        _backendStatus = e.message;
        _backendIsError = true;
      });
    } catch (e) {
      setState(() {
        _backendLoading = false;
        _backendStatus = e.toString();
        _backendIsError = true;
      });
    }
  }

  Future<void> _testGetProfile() async {
    setState(() {
      _backendLoading = true;
      _backendStatus = null;
      _backendIsError = false;
    });
    try {
      final profile = await AuthService.me();
      setState(() {
        _backendLoading = false;
        _loggedInUser = profile;
        _backendStatus = 'Profile: ${profile.email}'
            '${profile.fullName != null ? ' — ${profile.fullName}' : ''}'
            '${profile.role != null ? ' [${profile.role}]' : ''}';
        _backendIsError = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _backendLoading = false;
        _backendStatus = e.message;
        _backendIsError = true;
      });
    } catch (e) {
      setState(() {
        _backendLoading = false;
        _backendStatus = e.toString();
        _backendIsError = true;
      });
    }
  }

  Future<void> _testLogout() async {
    await AuthService.logout();
    setState(() {
      _loggedInUser = null;
      _backendStatus = 'Logged out. Token cleared.';
      _backendIsError = false;
    });
  }

  Widget _buildBackendSection() {
    return _SettingsCard(
      title: 'BACKEND CONNECTION TEST',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Test the connection to the ASP.NET backend. '
            'Backend must be running at the configured base URL.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            style: const TextStyle(color: AppColors.text),
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'Email',
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
          const SizedBox(height: 10),
          TextField(
            controller: _passwordController,
            obscureText: !_passwordVisible,
            style: const TextStyle(color: AppColors.text),
            decoration: InputDecoration(
              hintText: 'Password',
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
                  _passwordVisible
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: AppColors.muted,
                ),
                onPressed: () =>
                    setState(() => _passwordVisible = !_passwordVisible),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  foregroundColor: AppColors.text,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _backendLoading ? null : _testLogin,
                icon: _backendLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login_rounded),
                label: const Text('Test Login',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text,
                  side: const BorderSide(color: AppColors.outlineVariant),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _backendLoading ? null : _testGetProfile,
                icon: const Icon(Icons.person_rounded),
                label: const Text('GET /auth/me',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              if (_loggedInUser != null)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error.withAlpha(160)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _testLogout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Logout',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
            ],
          ),
          if (_backendStatus != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _backendIsError
                    ? AppColors.error.withAlpha(30)
                    : AppColors.primary.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _backendIsError
                      ? AppColors.error.withAlpha(100)
                      : AppColors.primary.withAlpha(100),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _backendIsError
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 16,
                    color: _backendIsError ? AppColors.error : AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _backendStatus!,
                      style: TextStyle(
                        color: _backendIsError
                            ? AppColors.error
                            : AppColors.primary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Backend assessment ID ──────────────────────────────────────────────────

  final _backendAssessmentIdController = TextEditingController();

  void _saveBackendAssessmentId() {
    final id = _backendAssessmentIdController.text.trim();
    widget.onSetBackendAssessmentId?.call(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(id.isEmpty
            ? 'Backend assessment ID cleared.'
            : 'Backend assessment ID set: $id'),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Widget _buildBackendAssessmentIdSection() {
    if (_backendAssessmentIdController.text.isEmpty &&
        widget.backendAssessmentId != null) {
      _backendAssessmentIdController.text = widget.backendAssessmentId!;
    }

    return _SettingsCard(
      title: 'BACKEND ASSESSMENT ID',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter the GUID of an existing assessment on the ASP.NET backend. '
            'All submission uploads, grading, review, and export will use this assessment.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _backendAssessmentIdController,
            style: const TextStyle(color: AppColors.text, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: 'e.g. 3fa85f64-5717-4562-b3fc-2c963f66afa6',
              hintStyle: const TextStyle(color: AppColors.muted, fontSize: 12),
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
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryContainer,
              foregroundColor: AppColors.text,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _saveBackendAssessmentId,
            icon: const Icon(Icons.save_rounded),
            label: const Text('Save Assessment ID',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ── Security notes ─────────────────────────────────────────────────────────

  Widget _buildSecuritySection() {
    return _SettingsCard(
      title: 'SECURITY NOTES',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(
            icon: Icons.lock_rounded,
            text: 'All API keys are held in memory only — never written to disk or committed to version control.',
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.shield_rounded,
            text:
                'Student submissions are sent to OpenRouter (openrouter.ai) when OpenRouter mode is active, '
                'or to Google Gemini API (generativelanguage.googleapis.com) when Gemini mode is active.',
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.auto_awesome_rounded,
            text:
                'Gemini free tier: up to 15 requests/minute, 1500 requests/day with gemini-2.0-flash-lite.',
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────

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
