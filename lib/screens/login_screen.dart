import 'package:flutter/material.dart';

import '../core/network/api_exception.dart';
import '../features/auth/models/login_request.dart';
import '../features/auth/models/user_profile.dart';
import '../features/auth/services/auth_service.dart';
import '../theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLoginSuccess});

  final ValueChanged<UserProfile> onLoginSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _ConnStatus { checking, connected, disconnected }

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _showPw  = false;
  bool _loading = false;
  String _error = '';
  _ConnStatus _conn = _ConnStatus.checking;

  @override
  void initState() {
    super.initState();
    _pingBackend();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pingBackend() async {
    try {
      await AuthService.me();
      if (mounted) setState(() => _conn = _ConnStatus.connected);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _conn = e.isUnauthorized
            ? _ConnStatus.connected
            : _ConnStatus.disconnected);
      }
    } catch (_) {
      if (mounted) setState(() => _conn = _ConnStatus.disconnected);
    }
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pw    = _passwordCtrl.text;
    if (email.isEmpty || pw.isEmpty) {
      setState(() => _error = 'Please enter your email and password.');
      return;
    }
    setState(() { _loading = true; _error = ''; });
    try {
      final profile = await AuthService.login(LoginRequest(email: email, password: pw));
      if (!mounted) return;
      widget.onLoginSuccess(profile);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error   = e.isUnauthorized ? 'Invalid email or password.' : e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error   = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 440,
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 52),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.outline),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withAlpha(20),
                  blurRadius: 48,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Logo row ──────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.school_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PMG GradeAI',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          'AI-assisted grading for teachers',
                          style: TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                // ── Heading ───────────────────────────────────────────────
                const Text(
                  'Welcome back',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Sign in to your account to continue',
                  style: TextStyle(fontSize: 14, color: AppColors.muted),
                ),
                const SizedBox(height: 32),
                // ── Email ─────────────────────────────────────────────────
                const _FieldLabel('Email'),
                const SizedBox(height: 6),
                _Field(
                  controller: _emailCtrl,
                  hint:        'teacher@university.edu',
                  type:        TextInputType.emailAddress,
                  onSubmit:    _submit,
                ),
                const SizedBox(height: 18),
                // ── Password ──────────────────────────────────────────────
                const _FieldLabel('Password'),
                const SizedBox(height: 6),
                _Field(
                  controller: _passwordCtrl,
                  hint:        '••••••••',
                  obscure:     !_showPw,
                  onSubmit:    _submit,
                  suffix: IconButton(
                    icon: Icon(
                      _showPw
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: AppColors.muted,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _showPw = !_showPw),
                  ),
                ),
                // ── Error banner ──────────────────────────────────────────
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.error,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                // ── Sign-in button ────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.primaryContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 28),
                // ── Backend connection status ──────────────────────────────
                Center(child: _ConnStatusRow(status: _conn)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Field label ───────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      ),
    );
  }
}

// ── Text field ────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.onSubmit,
    this.type    = TextInputType.text,
    this.obscure = false,
    this.suffix,
  });

  final TextEditingController controller;
  final String        hint;
  final TextInputType type;
  final bool          obscure;
  final Widget?       suffix;
  final VoidCallback  onSubmit;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.outline),
    );
    return TextField(
      controller:    controller,
      keyboardType:  type,
      obscureText:   obscure,
      onSubmitted:   (_) => onSubmit(),
      style: const TextStyle(color: AppColors.text, fontSize: 14),
      decoration: InputDecoration(
        hintText:       hint,
        hintStyle:      const TextStyle(color: AppColors.muted),
        filled:         true,
        fillColor:      AppColors.surfaceContainer,
        suffixIcon:     suffix,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border:         border,
        enabledBorder:  border,
        focusedBorder:  OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}

// ── Backend connection status row ─────────────────────────────────────────────

class _ConnStatusRow extends StatelessWidget {
  const _ConnStatusRow({required this.status});
  final _ConnStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      _ConnStatus.checking     => ('Checking connection…', AppColors.muted,    Icons.sync_rounded),
      _ConnStatus.connected    => ('Backend Connected',    AppColors.success,  Icons.check_circle_outline_rounded),
      _ConnStatus.disconnected => ('Backend Disconnected', AppColors.error,    Icons.error_outline_rounded),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}
