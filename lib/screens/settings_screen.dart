import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../core/config/api_config.dart';
import '../core/network/api_exception.dart';
import '../features/auth/models/user_profile.dart';
import '../features/auth/services/auth_service.dart';
import '../models/ai_mode.dart';
import '../models/assessment.dart';
import '../theme/app_colors.dart';
import '../widgets/page_frame.dart';
import '../widgets/page_title.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SettingsScreen
//
// Constructor keeps the legacy OpenRouter/Gemini fields 1-to-1 with AppShell
// so other call sites don't need to change; those sections are not rendered
// (grading is backend-only, credentials are server-managed). New fields
// (userProfile / onLogout / backendOnline / currentAssessment) are read from
// state AppShell already holds — no new business logic, no fake data.
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
    required this.onLogout,
    this.userProfile,
    this.backendOnline,
    this.currentAssessment,
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

  /// Real app-level sign-out (clears token AND swaps AppShell back to Login).
  final VoidCallback onLogout;

  final UserProfile? userProfile;
  final bool?        backendOnline;
  final Assessment?  currentAssessment;

  final String? backendAssessmentId;
  final ValueChanged<String>? onSetBackendAssessmentId;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ── Card 2: Test Connection — uses the existing signed-in session token,
  // never asks for email/password again. ────────────────────────────────────
  bool      _testLoading = false;
  String?   _testMessage;
  bool      _testIsError = false;
  DateTime? _lastCheckedAt;

  // ── Collapsible sections (both closed by default) ──────────────────────────
  bool _advancedInfoOpen = false;
  bool _devToolsOpen     = false;

  // ── Advanced Developer Tools: read-only session check (GET /auth/me) using
  // the current signed-in token. No raw login form here — see SECURITY NOTE
  // below on why "Test Login" was removed entirely rather than kept. ─────────
  bool    _devLoading = false;
  String? _devStatus;
  bool    _devIsError = false;

  // ── Card 2 action ────────────────────────────────────────────────────────

  Future<void> _testConnection() async {
    setState(() { _testLoading = true; _testMessage = null; _testIsError = false; });
    try {
      final profile = await AuthService.me();
      if (!mounted) return;
      setState(() {
        _testLoading   = false;
        _testMessage   = 'Connected — signed in as ${profile.displayName}';
        _testIsError   = false;
        _lastCheckedAt = DateTime.now();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _testLoading   = false;
        _testMessage   = e.message;
        _testIsError   = true;
        _lastCheckedAt = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testLoading   = false;
        _testMessage   = 'Could not reach the backend.';
        _testIsError   = true;
        _lastCheckedAt = DateTime.now();
      });
    }
  }

  // ── Advanced Developer Tools action ─────────────────────────────────────────
  //
  // Only GET /auth/me remains here: it reads the current signed-in session's
  // token without ever writing to TokenStorage, so it cannot corrupt the
  // active session. (Test Login was removed — see SECURITY NOTE at
  // _DevToolsSection below.)

  Future<void> _devTestGetProfile() async {
    setState(() { _devLoading = true; _devStatus = null; _devIsError = false; });
    try {
      final profile = await AuthService.me();
      if (!mounted) return;
      setState(() {
        _devLoading = false;
        _devStatus  = 'Profile: ${profile.email}'
            '${profile.fullName != null ? ' — ${profile.fullName}' : ''}'
            '${profile.role != null ? ' [${profile.role}]' : ''}';
        _devIsError = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _devLoading = false; _devStatus = e.message; _devIsError = true; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _devLoading = false; _devStatus = e.toString(); _devIsError = true; });
    }
  }

  void _copy(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied'), duration: const Duration(seconds: 2)),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PageTitle(
                  title: 'Settings',
                  subtitle: 'Manage your profile, connection, and grading environment.',
                ),
                const SizedBox(height: 20),

                // Card 1 + Card 2 — two columns on wide screens.
                LayoutBuilder(builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 760;
                  final account = _AccountCard(
                    user: widget.userProfile,
                    onSignOut: widget.onLogout,
                  );
                  final connection = _ConnectionCard(
                    backendOnline: widget.backendOnline,
                    assessment: widget.currentAssessment,
                    loading: _testLoading,
                    message: _testMessage,
                    isError: _testIsError,
                    lastCheckedAt: _lastCheckedAt,
                    onTest: _testLoading ? null : _testConnection,
                  );
                  if (narrow) {
                    return Column(children: [account, const SizedBox(height: 16), connection]);
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: account),
                      const SizedBox(width: 16),
                      Expanded(child: connection),
                    ],
                  );
                }),
                const SizedBox(height: 16),

                const _AiGradingCard(),
                const SizedBox(height: 16),

                const _SecurityCard(),
                const SizedBox(height: 16),

                _AdvancedInfoSection(
                  open: _advancedInfoOpen,
                  onToggle: () => setState(() => _advancedInfoOpen = !_advancedInfoOpen),
                  assessmentId: widget.backendAssessmentId,
                  onCopy: _copy,
                ),
                const SizedBox(height: 12),

                // Debug-only: raw session inspection tool. Hidden from release/
                // profile builds so it can never be reached by an end user.
                if (kDebugMode) ...[
                  _DevToolsSection(
                    open: _devToolsOpen,
                    onToggle: () => setState(() => _devToolsOpen = !_devToolsOpen),
                    loading: _devLoading,
                    status: _devStatus,
                    isError: _devIsError,
                    onGetProfile: _devLoading ? null : _devTestGetProfile,
                    // Reuses the real app-level sign-out (clears token AND
                    // resets AppShell back to Login) instead of calling
                    // AuthService.logout()/TokenStorage directly — that used
                    // to clear the token without updating AppShell, leaving
                    // TopBar/Sidebar showing a "signed in" user with no valid
                    // token underneath.
                    onSignOut: widget.onLogout,
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Card 1 — Account & Profile
// ═══════════════════════════════════════════════════════════════════════════════

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.user, required this.onSignOut});

  final UserProfile? user;
  final VoidCallback onSignOut;

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      title: 'ACCOUNT & PROFILE',
      child: user == null
          ? const _LoadingRow(text: 'Loading account…')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primaryContainer,
                      child: Text(
                        _initials(user!.displayName),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user!.displayName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user!.email,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _KeyValueRow(label: 'Role', value: user!.role ?? 'Teacher'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Status', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                    const Spacer(),
                    _Pill(
                      text: 'Signed in',
                      bg: const Color(0xFFF0FDF4),
                      fg: AppColors.success,
                      icon: Icons.check_circle_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error.withAlpha(140)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: onSignOut,
                    icon: const Icon(Icons.logout_rounded, size: 17),
                    label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Card 2 — System Connection
// ═══════════════════════════════════════════════════════════════════════════════

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.backendOnline,
    required this.assessment,
    required this.loading,
    required this.message,
    required this.isError,
    required this.lastCheckedAt,
    required this.onTest,
  });

  final bool?             backendOnline;
  final Assessment?       assessment;
  final bool               loading;
  final String?            message;
  final bool               isError;
  final DateTime?          lastCheckedAt;
  final VoidCallback?      onTest;

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 5) return 'just now';
    if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    final assessmentName = assessment != null
        ? '${assessment!.courseCode} — ${assessment!.assessmentTitle}'
        : 'No assessment selected';

    return _SettingsCard(
      title: 'SYSTEM CONNECTION',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusLine(label: 'Backend API', status: backendOnline),
          const SizedBox(height: 10),
          // AI grading is routed entirely through the Backend — there is no
          // separate AI-provider health signal on the client, so this
          // mirrors the same Backend connectivity rather than inventing one.
          _StatusLine(label: 'AI Engine (via Backend)', status: backendOnline),
          const SizedBox(height: 14),
          const Divider(color: AppColors.outlineVariant, height: 1),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.assignment_rounded, size: 15, color: AppColors.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  assessmentName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.text, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onTest,
              icon: loading
                  ? const SizedBox(
                      width: 15, height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  : const Icon(Icons.wifi_tethering_rounded, size: 17),
              label: Text(
                loading ? 'Testing…' : 'Test Connection',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: isError ? AppColors.error.withAlpha(24) : AppColors.success.withAlpha(24),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isError ? AppColors.error.withAlpha(90) : AppColors.success.withAlpha(90),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                    size: 15,
                    color: isError ? AppColors.error : AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message!,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isError ? AppColors.error : AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (lastCheckedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Last checked: ${_relativeTime(lastCheckedAt!)}',
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.label, required this.status});

  final String label;
  final bool?  status;

  @override
  Widget build(BuildContext context) {
    final String text;
    final Color  fg;
    final Color  bg;
    final IconData icon;
    if (status == null) {
      text = 'Checking…'; fg = AppColors.muted; bg = AppColors.surfaceHighest; icon = Icons.hourglass_top_rounded;
    } else if (status == true) {
      text = 'Connected'; fg = AppColors.success; bg = const Color(0xFFF0FDF4); icon = Icons.check_circle_rounded;
    } else {
      text = 'Disconnected'; fg = AppColors.error; bg = const Color(0xFFFEF2F2); icon = Icons.cancel_rounded;
    }
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.text, fontWeight: FontWeight.w600)),
        const Spacer(),
        _Pill(text: text, bg: bg, fg: fg, icon: icon),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Card 3 — AI Grading (read-only)
// ═══════════════════════════════════════════════════════════════════════════════

class _AiGradingCard extends StatelessWidget {
  const _AiGradingCard();

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      title: 'AI GRADING',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _KeyValueRow(label: 'Grading mode', value: 'Backend AI'),
          const SizedBox(height: 10),
          _KeyValueRow(label: 'Provider credentials', value: 'Server managed'),
          const SizedBox(height: 10),
          _KeyValueRow(label: 'Teacher API key', value: 'Not required'),
          const SizedBox(height: 10),
          // No runtime-reported model exists on the client — never guess it.
          _KeyValueRow(label: 'Current model', value: 'Managed by backend'),
          const SizedBox(height: 10),
          _KeyValueRow(
            label: 'Grading request timeout',
            value: '${ApiConfig.gradingReceiveTimeout.inSeconds}s (this device)',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withAlpha(60)),
            ),
            child: const Text(
              'All grading is processed through the configured backend. '
              'AI provider credentials are never stored in this client.',
              style: TextStyle(color: AppColors.text, fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Card 4 — Security & Privacy
// ═══════════════════════════════════════════════════════════════════════════════

class _SecurityCard extends StatelessWidget {
  const _SecurityCard();

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      title: 'SECURITY & PRIVACY',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _InfoRow(
            icon: Icons.lock_rounded,
            title: 'Session token',
            text: 'Stored in the platform secure store.',
          ),
          SizedBox(height: 12),
          _InfoRow(
            icon: Icons.shield_rounded,
            title: 'Student submissions',
            text: 'Sent only to the configured backend.',
          ),
          SizedBox(height: 12),
          _InfoRow(
            icon: Icons.vpn_key_rounded,
            title: 'AI credentials',
            text: 'Managed by the backend server.',
          ),
          SizedBox(height: 12),
          _InfoRow(
            icon: Icons.block_rounded,
            title: 'Direct provider access',
            text: 'Disabled from this client.',
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Advanced system information (collapsed by default)
// ═══════════════════════════════════════════════════════════════════════════════

class _AdvancedInfoSection extends StatelessWidget {
  const _AdvancedInfoSection({
    required this.open,
    required this.onToggle,
    required this.assessmentId,
    required this.onCopy,
  });

  final bool                           open;
  final VoidCallback                   onToggle;
  final String?                        assessmentId;
  final void Function(String, String)  onCopy;

  @override
  Widget build(BuildContext context) {
    return _CollapsibleCard(
      title: 'Advanced system information',
      icon: Icons.terminal_rounded,
      open: open,
      onToggle: onToggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CopyableRow(label: 'API base URL', value: ApiConfig.baseUrl, onCopy: onCopy),
          const SizedBox(height: 10),
          const _KeyValueRow(label: 'Grade single endpoint', value: 'POST /api/submissions/{id}/grade'),
          const SizedBox(height: 10),
          const _KeyValueRow(label: 'Grade all endpoint', value: 'POST /api/assessments/{id}/grading-jobs'),
          const SizedBox(height: 10),
          const _KeyValueRow(label: 'Export endpoint', value: 'GET /api/assessments/{id}/export/excel'),
          const SizedBox(height: 10),
          _CopyableRow(
            label: 'Current assessment ID',
            value: (assessmentId?.isNotEmpty == true) ? assessmentId! : 'None',
            onCopy: (assessmentId?.isNotEmpty == true) ? onCopy : null,
          ),
          const SizedBox(height: 10),
          const _KeyValueRow(
            label: 'Token storage type',
            value: 'Platform secure store (flutter_secure_storage)',
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Advanced Developer Tools (collapsed by default, debug builds only)
//
// SECURITY NOTE: this used to also offer a raw "Test Login" (email/password)
// button. AuthService.login() unconditionally overwrites the single stored
// session token via TokenStorage.saveToken() — it has no notion of "this is
// just a test". Using it here while a real teacher session was active would
// silently replace that session's token with whichever account was entered,
// while AppShell/TopBar kept showing the ORIGINAL signed-in user (its
// in-memory UserProfile is never refreshed by this screen) — i.e. the UI
// could show "User A" while every subsequent API call actually authenticates
// as "User B" (or, after a Clear-Token-style action, no one). Rather than
// build a parallel non-persisting login path (which would duplicate
// AuthService's request logic in the UI layer) or touch the production
// login() method, Test Login was removed outright. GET /auth/me is safe to
// keep: it only reads the current session, it never writes to TokenStorage.
// ═══════════════════════════════════════════════════════════════════════════════

class _DevToolsSection extends StatelessWidget {
  const _DevToolsSection({
    required this.open,
    required this.onToggle,
    required this.loading,
    required this.status,
    required this.isError,
    required this.onGetProfile,
    required this.onSignOut,
  });

  final bool           open;
  final VoidCallback   onToggle;
  final bool           loading;
  final String?        status;
  final bool           isError;
  final VoidCallback?  onGetProfile;
  /// Real app-level sign-out — clears the token AND resets AppShell back to
  /// Login. Deliberately NOT a raw AuthService.logout() call, which would
  /// clear the token without updating AppShell's in-memory session state.
  final VoidCallback   onSignOut;

  @override
  Widget build(BuildContext context) {
    return _CollapsibleCard(
      title: 'Advanced Developer Tools',
      icon: Icons.build_circle_rounded,
      open: open,
      onToggle: onToggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Debug-only session inspection. Uses the current signed-in token — '
            'it never enters credentials or writes a new token.',
            style: TextStyle(color: AppColors.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10, runSpacing: 10,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text,
                  side: const BorderSide(color: AppColors.outlineVariant),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: onGetProfile,
                icon: loading
                    ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.person_rounded, size: 17),
                label: const Text('GET /auth/me', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error.withAlpha(160)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: onSignOut,
                icon: const Icon(Icons.logout_rounded, size: 17),
                label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (status != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: isError ? AppColors.error.withAlpha(24) : AppColors.primary.withAlpha(24),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isError ? AppColors.error.withAlpha(90) : AppColors.primary.withAlpha(90),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                    size: 15,
                    color: isError ? AppColors.error : AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      status!,
                      style: TextStyle(fontSize: 12.5, color: isError ? AppColors.error : AppColors.primary),
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
}

// ═══════════════════════════════════════════════════════════════════════════════
// Shared building blocks
// ═══════════════════════════════════════════════════════════════════════════════

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(color: const Color(0xFF4F46E5).withAlpha(6), blurRadius: 12, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _CollapsibleCard extends StatelessWidget {
  const _CollapsibleCard({
    required this.title,
    required this.icon,
    required this.open,
    required this.onToggle,
    required this.child,
  });

  final String        title;
  final IconData       icon;
  final bool           open;
  final VoidCallback   onToggle;
  final Widget         child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Icon(icon, size: 17, color: AppColors.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.text),
                    ),
                  ),
                  Icon(
                    open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: child,
            ),
        ],
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13, color: AppColors.text, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _CopyableRow extends StatelessWidget {
  const _CopyableRow({required this.label, required this.value, required this.onCopy});

  final String label;
  final String value;
  final void Function(String, String)? onCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: AppColors.text, fontWeight: FontWeight.w600),
          ),
        ),
        if (onCopy != null) ...[
          const SizedBox(width: 6),
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => onCopy!(label, value),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.copy_rounded, size: 14, color: AppColors.muted),
            ),
          ),
        ],
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.bg, required this.fg, required this.icon});

  final String   text;
  final Color    bg;
  final Color    fg;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String   title;
  final String   text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(color: AppColors.surfaceHighest, borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, size: 15, color: AppColors.muted),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
              const SizedBox(height: 1),
              Text(text, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.muted),
        ),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
      ],
    );
  }
}
