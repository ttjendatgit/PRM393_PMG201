import 'package:flutter/material.dart';

import '../core/network/api_exception.dart';
import '../features/auth/models/login_request.dart';
import '../features/auth/models/user_profile.dart';
import '../features/auth/services/auth_service.dart';
import '../models/ai_mode.dart';
import '../theme/app_colors.dart';
import '../widgets/page_frame.dart';
import '../widgets/page_title.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SettingsScreen
//
// Constructor props are kept 1-to-1 with AppShell so that the call-site in
// main.dart does not need to change.  All OpenRouter / Gemini frontend-key
// sections have been removed: grading is backend-only and the AI provider
// credentials are managed server-side.
// ─────────────────────────────────────────────────────────────────────────────

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

  // Kept for AppShell call-site compatibility (unused in this screen).
  final String apiKey;
  final String modelId;
  final ValueChanged<String> onSaveApiKey;
  final VoidCallback onClearApiKey;
  final ValueChanged<String> onSaveModelId;

  final String geminiApiKey;
  final String geminiModelId;
  final ValueChanged<String> onSaveGeminiApiKey;
  final VoidCallback onClearGeminiApiKey;
  final ValueChanged<String> onSaveGeminiModelId;

  final AiMode aiMode;
  final ValueChanged<AiMode> onChangeAiMode;

  final String? backendAssessmentId;
  final ValueChanged<String>? onSetBackendAssessmentId;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Backend connection test
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _passwordVisible = false;
  bool _backendLoading = false;
  String? _backendStatus;
  bool _backendIsError = false;
  UserProfile? _loggedInUser;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Backend test callbacks ─────────────────────────────────────────────────

  Future<void> _testLogin() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() { _backendStatus = 'Enter email and password first.'; _backendIsError = true; });
      return;
    }
    setState(() { _backendLoading = true; _backendStatus = null; _backendIsError = false; _loggedInUser = null; });
    try {
      final profile = await AuthService.login(LoginRequest(email: email, password: password));
      setState(() {
        _backendLoading = false;
        _loggedInUser   = profile;
        _backendStatus  = 'Logged in as ${profile.displayName}';
        _backendIsError = false;
      });
    } on ApiException catch (e) {
      setState(() { _backendLoading = false; _backendStatus = e.message; _backendIsError = true; });
    } catch (e) {
      setState(() { _backendLoading = false; _backendStatus = e.toString(); _backendIsError = true; });
    }
  }

  Future<void> _testGetProfile() async {
    setState(() { _backendLoading = true; _backendStatus = null; _backendIsError = false; });
    try {
      final profile = await AuthService.me();
      setState(() {
        _backendLoading = false;
        _loggedInUser   = profile;
        _backendStatus  = 'Profile: ${profile.email}'
            '${profile.fullName != null ? ' — ${profile.fullName}' : ''}'
            '${profile.role != null ? ' [${profile.role}]' : ''}';
        _backendIsError = false;
      });
    } on ApiException catch (e) {
      setState(() { _backendLoading = false; _backendStatus = e.message; _backendIsError = true; });
    } catch (e) {
      setState(() { _backendLoading = false; _backendStatus = e.toString(); _backendIsError = true; });
    }
  }

  Future<void> _testLogout() async {
    await AuthService.logout();
    setState(() { _loggedInUser = null; _backendStatus = 'Logged out. Token cleared.'; _backendIsError = false; });
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
              subtitle: 'Backend AI Engine is active. All grading is handled server-side.',
            ),
            const SizedBox(height: 32),
            _buildAiEngineSection(),
            const SizedBox(height: 24),
            _buildBackendSection(),
            const SizedBox(height: 24),
            _buildSecuritySection(),
          ],
        ),
      ),
    );
  }

  // ── AI Engine (backend-locked) ─────────────────────────────────────────────

  Widget _buildAiEngineSection() {
    return _SettingsCard(
      title: 'AI ENGINE',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withAlpha(80)),
            ),
            child: const Row(
              children: [
                Icon(Icons.cloud_rounded, color: AppColors.primary, size: 22),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Backend AI Engine — Active',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'All grading is performed server-side. '
                        'No API key is required from the teacher. '
                        'The backend manages the AI model and provider credentials.',
                        style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _InfoRow(icon: Icons.upload_rounded,           text: 'Grade single:   POST /api/submissions/{id}/grade'),
          const SizedBox(height: 6),
          _InfoRow(icon: Icons.batch_prediction_rounded, text: 'Grade all:      POST /api/assessments/{id}/grading-jobs'),
          const SizedBox(height: 6),
          _InfoRow(icon: Icons.download_rounded,         text: 'Export Excel:   GET  /api/assessments/{id}/export/excel'),
        ],
      ),
    );
  }

  // ── Backend connection test ────────────────────────────────────────────────

  Widget _buildBackendSection() {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.outlineVariant),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primary),
    );
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: AppColors.surfaceHigh,
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: focusedBorder,
      hintStyle: const TextStyle(color: AppColors.muted),
    );

    return _SettingsCard(
      title: 'BACKEND CONNECTION TEST',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Verify the connection to the ASP.NET backend. '
            'Backend must be running at the configured base URL.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: AppColors.text),
            decoration: inputDecoration.copyWith(hintText: 'Email'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _passwordCtrl,
            obscureText: !_passwordVisible,
            style: const TextStyle(color: AppColors.text),
            decoration: inputDecoration.copyWith(
              hintText: 'Password',
              suffixIcon: IconButton(
                icon: Icon(
                  _passwordVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  color: AppColors.muted,
                ),
                onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10, runSpacing: 10,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  foregroundColor: AppColors.text,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _backendLoading ? null : _testLogin,
                icon: _backendLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.login_rounded),
                label: const Text('Test Login', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text,
                  side: const BorderSide(color: AppColors.outlineVariant),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _backendLoading ? null : _testGetProfile,
                icon: const Icon(Icons.person_rounded),
                label: const Text('GET /auth/me', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              if (_loggedInUser != null)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error.withAlpha(160)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _testLogout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w800)),
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
                    _backendIsError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                    size: 16,
                    color: _backendIsError ? AppColors.error : AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _backendStatus!,
                      style: TextStyle(
                        color: _backendIsError ? AppColors.error : AppColors.primary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (widget.backendAssessmentId?.isNotEmpty == true) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withAlpha(60)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.assignment_rounded, size: 15, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Active assessment: ${widget.backendAssessmentId}',
                      style: const TextStyle(color: AppColors.primary, fontSize: 12),
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

  // ── Security notes ─────────────────────────────────────────────────────────

  Widget _buildSecuritySection() {
    return _SettingsCard(
      title: 'SECURITY NOTES',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(
            icon: Icons.lock_rounded,
            text: 'JWT session token is stored in the platform secure store (Windows Credential Manager).',
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.shield_rounded,
            text: 'Student submissions are sent only to the configured backend server. '
                'No student data is sent to third-party AI providers directly from this client.',
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.info_outline_rounded,
            text: 'The backend owns all AI provider credentials. '
                'Teachers do not need to configure any API keys in this application.',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared card widget
// ─────────────────────────────────────────────────────────────────────────────

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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String   text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.muted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        ),
      ],
    );
  }
}
