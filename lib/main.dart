import 'dart:io';

import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'core/network/api_exception.dart';
import 'core/storage/settings_storage.dart';
import 'features/rubric/services/rubric_api_service.dart';
import 'core/storage/token_storage.dart';
import 'features/auth/models/user_profile.dart';
import 'features/auth/services/auth_service.dart';
import 'features/export/services/export_api_service.dart';
import 'features/grading/services/grading_api_service.dart';
import 'features/review/services/review_api_service.dart';
import 'features/submission/services/submission_api_service.dart';
import 'models/ai_mode.dart';
import 'models/assessment.dart';
import 'models/grading_result.dart';
import 'models/grading_status.dart';
import 'models/rubric.dart';
import 'models/submission.dart';
import 'screens/assessment_setup_screen.dart';
import 'screens/criteria_screen.dart';
import 'screens/export_screen.dart';
import 'screens/grading_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/settings_screen.dart';
import 'services/ai/gemini_grading_service.dart';
import 'services/ai/openrouter_grading_service.dart';
import 'services/file/document_text_extractor_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'widgets/side_nav.dart';
import 'widgets/top_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PMGGradeAIApp());
}

class PMGGradeAIApp extends StatelessWidget {
  const PMGGradeAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PMG GradeAI',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _AuthGate(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// AUTH GATE — checks token on startup, routes to Login or AppShell
// ═══════════════════════════════════════════════════════════════════════════════

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  UserProfile? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final hasToken = await TokenStorage.hasToken();
    if (!hasToken) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final profile = await AuthService.me();
      if (mounted) setState(() { _user = profile; _loading = false; });
    } on ApiException catch (e) {
      // 401 = token expired/invalid → clear it and show login.
      // Other API errors → don't clear token (backend might be temporarily down).
      if (e.isUnauthorized) await TokenStorage.clearToken();
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      // Network error — don't clear token; show login so user can retry.
      if (mounted) setState(() => _loading = false);
    }
  }

  void _handleLogin(UserProfile profile) => setState(() => _user = profile);

  Future<void> _handleLogout() async {
    await AuthService.logout();
    if (mounted) setState(() => _user = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _SplashScreen();
    if (_user == null) return LoginScreen(onLoginSuccess: _handleLogin);
    return AppShell(user: _user!, onLogout: _handleLogout);
  }
}

// ── Splash (shown while bootstrapping) ────────────────────────────────────────

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.school_rounded, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 24),
            const Text(
              'PMG GradeAI',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: 28, height: 28,
              child: CircularProgressIndicator(
                color: AppColors.primary, strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// APP SHELL
// ═══════════════════════════════════════════════════════════════════════════════

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.user, required this.onLogout});

  final UserProfile  user;
  final VoidCallback onLogout;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int  selectedIndex          = 0;
  int? selectedSubmissionIndex;

  List<Submission>           submissions = [];
  List<GradingResult>        results     = [];
  Map<String, GradingStatus> _statuses   = {};

  Assessment? currentAssessment;

  // ── AI configuration (standalone mode) ─────────────────────────────────────
  String _apiKey        = '';
  String _modelId       = 'openrouter/free';
  String _geminiApiKey  = '';
  String _geminiModelId = 'gemini-2.0-flash-lite';
  // Start with backend mode so first render shows correct labels before
  // the async _loadSavedAiMode() completes and overrides this.
  AiMode _aiMode        = AiMode.backend;

  Map<String, String> _gradingErrors = {};

  bool   isGrading = false;
  String message   = 'Ready. Import submission files to begin.';

  // ── Backend mode state ─────────────────────────────────────────────────────
  String?         _backendAssessmentId;
  String?         _loadingSubmissionId;
  final Set<String> _fetchedFullSubmissionIds = {};

  // ── File upload readiness (fetched from backend after assessment selection) ─
  bool _questionUploaded = false;
  bool _guideUploaded    = false;

  // ── Backend connectivity ───────────────────────────────────────────────────
  bool? _backendOnline;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    debugPrint('[AppShell] initState — initial _aiMode=$_aiMode');
    _loadSavedAiMode();
    _checkBackendStatus();
  }

  Future<void> _loadSavedAiMode() async {
    final saved = await SettingsStorage.loadAiMode();
    debugPrint('[AppShell] _loadSavedAiMode → $saved');
    if (mounted) setState(() => _aiMode = saved);
  }

  Future<void> _checkBackendStatus() async {
    try {
      await AuthService.me();
      if (mounted) setState(() => _backendOnline = true);
    } catch (_) {
      if (mounted) setState(() => _backendOnline = false);
    }
  }

  // ── Assessment ────────────────────────────────────────────────────────────

  void _applyAssessment(Assessment assessment) {
    debugPrint('[Assessment] Applied: id=${assessment.assessmentId} '
        '"${assessment.courseCode} — ${assessment.assessmentTitle}"');
    setState(() {
      currentAssessment       = assessment;
      _backendAssessmentId    = assessment.assessmentId;
      // Reset file-upload flags until we verify from the backend
      _questionUploaded       = false;
      _guideUploaded          = false;
      submissions             = [];
      results                 = [];
      _statuses               = {};
      _gradingErrors          = {};
      selectedSubmissionIndex = null;
      _loadingSubmissionId    = null;
      _fetchedFullSubmissionIds.clear();
      message =
          'Assessment loaded: ${assessment.courseCode} — ${assessment.assessmentTitle}';
    });
    // Fetch real file-upload metadata from backend so Home Readiness is accurate
    _fetchFileMetadata(assessment.assessmentId);
    // Use _refreshBackendResults (not _loadBackendSubmissions) so that both
    // submissions AND their existing grading results are loaded in one pass.
    // This ensures Grading Detail can show results immediately after app
    // restart / assessment re-select — without requiring the teacher to open
    // each file individually.
    if (_aiMode == AiMode.backend) _refreshBackendResults();
  }

  /// Checks GET /api/assessments/{id}/question and /guide independently
  /// so a missing guide does not mask an uploaded question (and vice versa).
  Future<void> _fetchFileMetadata(String assessmentId) async {
    debugPrint('[FileMetadata] Checking question/guide for: $assessmentId');
    bool qOk = false;
    bool gOk = false;

    try {
      final qData = await RubricApiService.getQuestion(assessmentId);
      qOk = qData != null;
    } catch (_) {
      // 404 = file not uploaded yet; any other error = treat as not uploaded
    }

    try {
      final gData = await RubricApiService.getGuide(assessmentId);
      gOk = gData != null;
    } catch (_) {}

    debugPrint('[FileMetadata] question=$qOk, guide=$gOk');
    if (!mounted) return;
    setState(() {
      _questionUploaded = qOk;
      _guideUploaded    = gOk;
    });
  }

  void _setBackendAssessmentId(String assessmentId) {
    setState(() {
      _backendAssessmentId = assessmentId;
      message = 'Backend assessment ID set: $assessmentId';
    });
  }

  // ── Result helpers — always key by submissionId ────────────────────────────

  /// Creates a copy of [r] with [subId] forced into the submissionId field.
  /// Used when the backend response omits submissionId.
  // _copyWithSubId is kept for backward compatibility; new code should use
  // GradingResult.copyWith() directly.
  GradingResult _copyWithSubId(String subId, GradingResult r) =>
      r.copyWith(submissionId: subId);

  /// Upserts [raw] into [results] keyed by [submissionId].
  /// Patches submissionId if absent, and restores fileName/studentId/studentName
  /// from the local submissions list (the detail endpoint omits those fields).
  /// MUST be called from within a setState block.
  void _upsertResult(String submissionId, GradingResult raw) {
    var r = raw.submissionId.isNotEmpty ? raw : raw.copyWith(submissionId: submissionId);

    // Restore fields the detail endpoint does not return.
    if (r.fileName.isEmpty || r.studentId.isEmpty || r.studentName.isEmpty) {
      final sub = submissions.cast<Submission?>().firstWhere(
        (s) => s?.id == submissionId,
        orElse: () => null,
      );
      if (sub != null) {
        r = r.copyWith(
          fileName:    r.fileName.isEmpty    ? sub.fileName    : null,
          studentId:   r.studentId.isEmpty   ? sub.studentId   : null,
          studentName: r.studentName.isEmpty ? sub.studentName : null,
        );
      }
    }

    _debugGradingResult(r);
    final idx = results.indexWhere((x) => x.submissionId == submissionId);
    if (idx >= 0) {
      final copy = List<GradingResult>.from(results);
      copy[idx] = r;
      results = copy;
    } else {
      results = [...results, r];
    }
  }

  // ── Navigate to next submission ────────────────────────────────────────────

  void _selectNextSubmission() {
    if (selectedSubmissionIndex == null) return;
    final next = selectedSubmissionIndex! + 1;
    if (next < submissions.length) {
      setState(() => selectedSubmissionIndex = next);
      if (_aiMode == AiMode.backend) {
        _fetchFullSubmissionIfNeeded(next);
        // Force refresh so we always see the latest state for the new submission.
        _fetchGradingResultForSubmission(next, forceRefresh: true);
      }
    }
  }

  Future<void> _fetchGradingResultForSubmission(
    int index, {
    bool forceRefresh = false,
  }) async {
    if (index < 0 || index >= submissions.length) return;
    final sub = submissions[index];
    if (sub.id.isEmpty) return;

    // Skip only if we already have a result AND the caller did NOT request a refresh.
    if (!forceRefresh && results.any((r) => r.submissionId == sub.id)) return;

    debugPrint('[FetchResult] GET /api/submissions/${sub.id}/grading-result '
        'forceRefresh=$forceRefresh');
    try {
      final result = await GradingApiService.getGradingResult(sub.id);
      if (!mounted) return;
      if (result == null) return;
      debugPrint('[FetchResult] resultId=${result.id} subId=${result.submissionId} '
          'status=${result.reviewStatus} score=${result.finalScore}');
      setState(() {
        _upsertResult(sub.id, result);
        _statuses = {..._statuses, sub.id: _mapReviewStatus(result.reviewStatus)};
      });
    } catch (_) {}
  }

  Future<void> _fetchFullSubmissionIfNeeded(int index) async {
    if (index < 0 || index >= submissions.length) return;
    final sub = submissions[index];
    if (sub.id.isEmpty) return;
    if (_fetchedFullSubmissionIds.contains(sub.id)) return;
    _fetchedFullSubmissionIds.add(sub.id);
    setState(() => _loadingSubmissionId = sub.id);
    try {
      final full = await SubmissionApiService.getSubmission(sub.id);
      if (!mounted) return;
      setState(() {
        _loadingSubmissionId = null;
        final copy = List<Submission>.from(submissions);
        copy[index] = full;
        submissions = copy;
      });
    } catch (_) {
      if (!mounted) return;
      _fetchedFullSubmissionIds.remove(sub.id);
      setState(() => _loadingSubmissionId = null);
    }
  }

  // ── Review save (standalone) ───────────────────────────────────────────────

  void _saveReview(GradingResult updated) {
    setState(() {
      final idx = results.indexWhere((r) => r.fileName == updated.fileName);
      if (idx >= 0) {
        final copy = List<GradingResult>.from(results);
        copy[idx] = updated;
        results = copy;
      }
      _statuses = {..._statuses, updated.fileName: GradingStatus.reviewed};
      message = 'Reviewed scores saved.';
    });
  }

  // ── AI configuration ──────────────────────────────────────────────────────

  void _updateApiKey(String v)        => setState(() => _apiKey = v);
  void _clearApiKey()                 => setState(() => _apiKey = '');
  void _updateModelId(String v)       => setState(() => _modelId = v);
  void _updateGeminiApiKey(String v)  => setState(() => _geminiApiKey = v);
  void _clearGeminiApiKey()           => setState(() => _geminiApiKey = '');
  void _updateGeminiModelId(String v) => setState(() => _geminiModelId = v);
  void _updateAiMode(AiMode mode) {
    setState(() => _aiMode = mode);
    SettingsStorage.saveAiMode(mode);
  }

  // ── Grade single submission (standalone) ───────────────────────────────────

  Future<void> gradeCurrent() async {
    if (_aiMode == AiMode.backend) {
      await _gradeSingleBackend();
      return;
    }
    final submission = selectedSubmission;
    if (submission == null) {
      setState(() => message = 'No submission selected.');
      return;
    }
    if (_aiMode == AiMode.openRouter) {
      if (_apiKey.trim().isEmpty) { setState(() => message = 'Please enter OpenRouter API key in Settings.'); return; }
      if (_modelId.trim().isEmpty) { setState(() => message = 'Please enter a Model ID in Settings.'); return; }
      if (currentAssessment == null) { setState(() => message = 'Please load or create an assessment first (Assessment Setup).'); return; }
    }
    if (_aiMode == AiMode.gemini) {
      if (_geminiApiKey.trim().isEmpty) { setState(() => message = 'Please enter Gemini API key in Settings.'); return; }
      if (_geminiModelId.trim().isEmpty) { setState(() => message = 'Please enter a Gemini Model ID in Settings.'); return; }
      if (currentAssessment == null) { setState(() => message = 'Please load or create an assessment first (Assessment Setup).'); return; }
    }
    if (submission.hasError || submission.content.trim().isEmpty) {
      final errMsg = submission.hasError
          ? 'Cannot grade: ${submission.extractionError}'
          : 'Cannot grade: file content is empty.';
      setState(() {
        message   = 'Error: $errMsg';
        _statuses = {..._statuses, submission.fileName: GradingStatus.error};
        _gradingErrors = {..._gradingErrors, submission.fileName: errMsg};
      });
      return;
    }
    setState(() {
      isGrading = true;
      _statuses = {..._statuses, submission.fileName: GradingStatus.pending};
      message   = 'Grading ${submission.fileName}...';
    });
    try {
      GradingResult result;
      if (_aiMode == AiMode.mock) {
        await Future.delayed(const Duration(milliseconds: 650));
        result = _mockGrade(submission);
      } else if (_aiMode == AiMode.gemini) {
        result = await GeminiGradingService.gradeSubmission(
          apiKey: _geminiApiKey, modelId: _geminiModelId,
          assessment: currentAssessment!, submission: submission,
        );
      } else {
        result = await OpenRouterGradingService.gradeSubmission(
          apiKey: _apiKey, modelId: _modelId,
          assessment: currentAssessment!, submission: submission,
        );
      }
      setState(() {
        isGrading = false;
        final idx = results.indexWhere((r) => r.fileName == submission.fileName);
        if (idx >= 0) {
          final copy = List<GradingResult>.from(results);
          copy[idx] = result;
          results = copy;
        } else {
          results = [...results, result];
        }
        _statuses      = {..._statuses, result.fileName: GradingStatus.graded};
        _gradingErrors = Map.from(_gradingErrors)..remove(submission.fileName);
        message = 'Graded: ${result.studentName.isNotEmpty ? result.studentName : submission.fileName}';
      });
    } catch (e) {
      final full = e.toString();
      debugPrint('Grading error for "${submission.fileName}": $full');
      var display = full.startsWith('Exception: ') ? full.substring(11) : full;
      final nl = display.indexOf('\n');
      if (nl >= 0) display = display.substring(0, nl);
      if (display.length > 160) display = '${display.substring(0, 160)}…';
      setState(() {
        isGrading      = false;
        _statuses      = {..._statuses, submission.fileName: GradingStatus.error};
        _gradingErrors = {..._gradingErrors, submission.fileName: display};
        message        = 'Error: $display';
      });
    }
  }

  // ── File import ───────────────────────────────────────────────────────────

  Future<void> pickTxtFiles() async {
    if (_aiMode == AiMode.backend) {
      await _uploadToBackend();
      return;
    }
    final result = await fp.FilePicker.pickFiles(
      allowMultiple: true,
      type: fp.FileType.custom,
      allowedExtensions: DocumentTextExtractorService.supportedExtensions,
    );
    if (result == null) {
      setState(() => message = 'File selection cancelled.');
      return;
    }
    final picked = <Submission>[];
    for (final file in result.files) {
      final path = file.path;
      if (path == null) continue;
      final extracted = await DocumentTextExtractorService.extractTextFromFile(path);
      String? extractionError;
      if (!extracted.success) {
        extractionError = extracted.errorMessage;
      } else if (extracted.isEmpty) {
        final ext = file.name.split('.').last.toLowerCase();
        extractionError = ext == 'pdf'
            ? 'This PDF may be scanned or image-based. Please convert it to text or upload a text-based file.'
            : (extracted.warningMessage ?? 'No text could be extracted from this file.');
      }
      picked.add(Submission(
        fileName: file.name,
        filePath: path,
        content:  extracted.extractedText,
        sizeInBytes: file.size,
        extractionError: extractionError,
      ));
    }
    final errorCount = picked.where((s) => s.hasError).length;
    final validCount = picked.length - errorCount;
    setState(() {
      submissions = picked;
      results     = [];
      _gradingErrors = {};
      _statuses = {
        for (final s in picked)
          s.fileName: s.hasError ? GradingStatus.error : GradingStatus.pending,
      };
      selectedSubmissionIndex = picked.isNotEmpty ? 0 : null;
      message = errorCount > 0
          ? 'Imported ${picked.length} file(s): $validCount valid, $errorCount with extraction error(s).'
          : 'Imported ${picked.length} submission file(s).';
    });
  }

  // ── Grading (standalone) ──────────────────────────────────────────────────

  Future<void> gradeAll() async {
    debugPrint('[gradeAll] mode=$_aiMode assessmentId=$_backendAssessmentId');
    if (_aiMode == AiMode.backend) {
      await _gradeAllBackend();
      return;
    }
    if (submissions.isEmpty) {
      setState(() => message = 'Please import submission files first.');
      return;
    }
    if (_aiMode == AiMode.openRouter) {
      if (_apiKey.trim().isEmpty) { setState(() => message = 'Please enter OpenRouter API key in Settings.'); return; }
      if (_modelId.trim().isEmpty) { setState(() => message = 'Please enter a Model ID in Settings.'); return; }
      if (currentAssessment == null) { setState(() => message = 'Please load or create an assessment first (Assessment Setup).'); return; }
    }
    if (_aiMode == AiMode.gemini) {
      if (_geminiApiKey.trim().isEmpty) { setState(() => message = 'Please enter Gemini API key in Settings.'); return; }
      if (_geminiModelId.trim().isEmpty) { setState(() => message = 'Please enter a Gemini Model ID in Settings.'); return; }
      if (currentAssessment == null) { setState(() => message = 'Please load or create an assessment first (Assessment Setup).'); return; }
    }
    final toGrade = submissions.where((s) {
      final st = _statuses[s.fileName];
      return st != GradingStatus.reviewed && st != GradingStatus.exported;
    }).toList();
    if (toGrade.isEmpty) {
      setState(() => message = 'All submissions are already reviewed or exported. Re-import files to grade again.');
      return;
    }
    setState(() {
      isGrading = true;
      message   = 'Starting grading for ${toGrade.length} file(s)...';
    });
    int gradedCount = 0, errorCount = 0;
    for (int i = 0; i < toGrade.length; i++) {
      final submission = toGrade[i];
      setState(() => message = 'Grading ${i + 1}/${toGrade.length}: ${submission.fileName}');
      if (submission.hasError || submission.content.trim().isEmpty) {
        final errMsg = submission.hasError
            ? 'Cannot grade: ${submission.extractionError}'
            : 'Cannot grade: file content is empty.';
        errorCount++;
        setState(() {
          _statuses      = {..._statuses, submission.fileName: GradingStatus.error};
          _gradingErrors = {..._gradingErrors, submission.fileName: errMsg};
        });
        continue;
      }
      try {
        GradingResult result;
        if (_aiMode == AiMode.mock) {
          await Future.delayed(const Duration(milliseconds: 650));
          result = _mockGrade(submission);
        } else if (_aiMode == AiMode.gemini) {
          result = await GeminiGradingService.gradeSubmission(
            apiKey: _geminiApiKey, modelId: _geminiModelId,
            assessment: currentAssessment!, submission: submission,
          );
        } else {
          result = await OpenRouterGradingService.gradeSubmission(
            apiKey: _apiKey, modelId: _modelId,
            assessment: currentAssessment!, submission: submission,
          );
        }
        gradedCount++;
        setState(() {
          final idx = results.indexWhere((r) => r.fileName == result.fileName);
          if (idx >= 0) {
            final copy = List<GradingResult>.from(results);
            copy[idx] = result;
            results = copy;
          } else {
            results = [...results, result];
          }
          _statuses      = {..._statuses, result.fileName: GradingStatus.graded};
          _gradingErrors = Map.from(_gradingErrors)..remove(submission.fileName);
        });
      } catch (e) {
        errorCount++;
        final full = e.toString();
        debugPrint('Grading error for "${submission.fileName}": $full');
        var display = full.startsWith('Exception: ') ? full.substring(11) : full;
        final nl = display.indexOf('\n');
        if (nl >= 0) display = display.substring(0, nl);
        if (display.length > 160) display = '${display.substring(0, 160)}…';
        setState(() {
          _statuses      = {..._statuses, submission.fileName: GradingStatus.error};
          _gradingErrors = {..._gradingErrors, submission.fileName: display};
        });
      }
    }
    setState(() {
      isGrading = false;
      message   = errorCount > 0
          ? 'Grading complete: $gradedCount graded, $errorCount error(s). Click a failed file to retry.'
          : switch (_aiMode) {
              AiMode.mock        => 'Mock grading complete. $gradedCount result(s) ready.',
              AiMode.openRouter  => 'OpenRouter grading complete. $gradedCount result(s) ready.',
              AiMode.gemini      => 'Gemini grading complete. $gradedCount result(s) ready.',
              AiMode.backend     => 'Backend grading complete.',
            };
      if (results.isNotEmpty) selectedIndex = 3;
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BACKEND MODE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _uploadToBackend() async {
    if (_backendAssessmentId == null) {
      setState(() => message = 'Please select an assessment in Assessment Setup first.');
      return;
    }
    final result = await fp.FilePicker.pickFiles(
      allowMultiple: true,
      type: fp.FileType.custom,
      allowedExtensions: ['txt', 'md', 'docx'],
    );
    if (result == null) {
      setState(() => message = 'File selection cancelled.');
      return;
    }
    final filePaths = result.files
        .map((f) => f.path)
        .where((path) => path != null)
        .cast<String>()
        .toList();
    if (filePaths.isEmpty) {
      setState(() => message = 'No valid files selected.');
      return;
    }
    debugPrint('[Upload] assessmentId=$_backendAssessmentId, '
        'files=${filePaths.length}: ${filePaths.map((p) => p.split(RegExp(r'[/\\]')).last).join(', ')}');
    setState(() { isGrading = true; message = 'Uploading ${filePaths.length} file(s) to backend...'; });
    try {
      final uploadResult = await SubmissionApiService.uploadSubmissions(
        _backendAssessmentId!, filePaths,
      );
      final backendSubs = await SubmissionApiService.getSubmissions(_backendAssessmentId!);
      setState(() {
        submissions = backendSubs;
        results     = [];
        _gradingErrors = {};
        _statuses = {
          for (final s in backendSubs) s.id: _mapBackendStatus(s.gradingStatus),
        };
        selectedSubmissionIndex = backendSubs.isNotEmpty ? 0 : null;
        isGrading = false;
        message   = 'Uploaded ${uploadResult.uploaded} file(s), ${uploadResult.failed} failed. '
            '${backendSubs.length} submission(s) on server.';
      });
    } catch (e) {
      setState(() { isGrading = false; message = 'Upload error: $e'; });
    }
  }

  Future<void> _gradeAllBackend() async {
    if (_backendAssessmentId == null) {
      setState(() => message = 'Please select an assessment in Assessment Setup first.');
      return;
    }
    debugPrint('[GradeAll] POST /api/assessments/$_backendAssessmentId/grading-jobs');
    setState(() { isGrading = true; message = 'Starting backend grading job...'; });
    try {
      final jobResult = await GradingApiService.createGradingJob(_backendAssessmentId!);
      setState(() { message = jobResult.message; });
      bool done = false;
      int pollAttempts = 0;
      const maxPollAttempts = 150;
      const finalStatuses  = {'COMPLETED', 'COMPLETED_WITH_ERRORS', 'ERROR'};
      while (!done && pollAttempts < maxPollAttempts) {
        await Future.delayed(const Duration(seconds: 2));
        pollAttempts++;
        try {
          final status = await GradingApiService.getGradingStatus(_backendAssessmentId!);
          setState(() {
            message = 'Grading: ${status.graded + status.error}/${status.totalSubmissions} '
                '(${status.graded} graded, ${status.error} errors) — Job: ${status.latestJobStatus ?? '...'}';
          });
          if (status.latestJobStatus != null && finalStatuses.contains(status.latestJobStatus)) {
            done = true;
          }
        } catch (e) {
          debugPrint('Grading status poll error (attempt $pollAttempts): $e');
        }
      }
      if (!done) {
        setState(() {
          isGrading = false;
          message   = 'Grading timed out after ${pollAttempts * 2}s. '
              'The job may still be running on the server. '
              'Refresh results manually when ready.';
        });
        return;
      }
      await _refreshBackendResults();
    } catch (e) {
      setState(() { isGrading = false; message = 'Backend grading error: $e'; });
    }
  }

  Future<void> _gradeSingleBackend() async {
    final submission = selectedSubmission;
    if (submission == null) {
      setState(() => message = 'No submission selected.');
      return;
    }
    debugPrint('[GradeSingle] POST /api/submissions/${submission.id}/grade  file="${submission.fileName}"');
    setState(() { isGrading = true; message = 'Grading ${submission.fileName} via backend...'; });
    try {
      await GradingApiService.gradeSubmission(submission.id);

      // Retry GET up to 4 times with 2 s delay — the backend may still be
      // persisting the result when the POST returns.
      GradingResult? raw;
      for (int attempt = 0; attempt < 4 && raw == null; attempt++) {
        if (attempt > 0) await Future.delayed(const Duration(seconds: 2));
        debugPrint('[GradeSingle] GET attempt ${attempt + 1}: '
            '/api/submissions/${submission.id}/grading-result');
        try { raw = await GradingApiService.getGradingResult(submission.id); }
        catch (_) {}
      }

      if (!mounted) return;
      if (raw != null) {
        final r = raw;
        debugPrint('[GradeSingle] resultId=${r.id} subId=${r.submissionId} '
            'reviewStatus=${r.reviewStatus} status=${r.status} '
            'score=${r.finalScore} items=${r.questionResults?.length ?? 0} '
            '${r.errorMessage.isNotEmpty ? "errorMsg=${r.errorMessage}" : ""}');
        setState(() {
          _upsertResult(submission.id, r);
          _statuses      = {..._statuses, submission.id: _getResultStatus(r)};
          _gradingErrors = Map.from(_gradingErrors)..remove(submission.id);
          message = r.status == 'ERROR'
              ? 'AI grading failed: ${r.errorMessage.isNotEmpty ? r.errorMessage : "unknown error"}. Use Manual Grading Mode.'
              : 'Graded: ${r.studentName.isNotEmpty ? r.studentName : submission.fileName}';
        });
      } else {
        setState(() {
          message = 'Grading started but result not yet available. '
              'Select this submission again to refresh.';
        });
      }
    } catch (e) {
      if (mounted) setState(() { message = 'Backend grading error: $e'; });
    } finally {
      if (mounted && isGrading) setState(() => isGrading = false);
    }
  }

  /// Maps a fetched [GradingResult] to the correct [GradingStatus] for display,
  /// preferring submission-level ERROR over review status.
  GradingStatus _getResultStatus(GradingResult r) {
    if (r.status == 'ERROR') return GradingStatus.error;
    return _mapReviewStatus(r.reviewStatus);
  }

  Future<void> _refreshBackendResults() async {
    if (_backendAssessmentId == null) return;
    try {
      final subs       = await SubmissionApiService.getSubmissions(_backendAssessmentId!);
      final newResults = <GradingResult>[];
      final newStatuses = <String, GradingStatus>{};
      for (final sub in subs) {
        newStatuses[sub.id] = _mapBackendStatus(sub.gradingStatus);
        // Fetch the grading result for every submission that has progressed past
        // initial upload.  Using != 'UPLOADED' catches GRADED, REVIEWED, FINALIZED,
        // and GRADING-in-progress so we never silently skip reviewed/finalized rows.
        if (sub.gradingStatus != 'UPLOADED') {
          try {
            final raw = await GradingApiService.getGradingResult(sub.id);
            if (raw != null) {
              final gr = raw.submissionId.isNotEmpty ? raw : _copyWithSubId(sub.id, raw);
              debugPrint('[RefreshResults] sub=${sub.id.length > 8 ? sub.id.substring(0, 8) : sub.id} '
                  'resultId=${gr.id} status=${gr.reviewStatus} score=${gr.finalScore}');
              newResults.add(gr);
              newStatuses[sub.id] = _getResultStatus(gr);
            }
          } catch (_) {
            // 404 or no result yet — keep the submission-level status
          }
        }
      }
      debugPrint('[RefreshResults] ${subs.length} subs → ${newResults.length} results loaded');
      setState(() {
        submissions = subs;
        results     = newResults;
        _statuses   = newStatuses;
        isGrading   = false;
        message     = 'Loaded ${subs.length} submission(s), ${newResults.length} graded.';
      });
    } catch (e) {
      setState(() { isGrading = false; message = 'Error refreshing results: $e'; });
    }
  }

  // ── Backend review ────────────────────────────────────────────────────────

  Future<void> _submitBackendReview({
    required String gradingResultId,
    required String submissionId,
    required String teacherOverallComment,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final saved = await ReviewApiService.submitReview(
        gradingResultId,
        {'teacherOverallComment': teacherOverallComment, 'items': items},
      );
      // Reload from backend to get server-computed scores.
      GradingResult fresh = saved;
      final effectiveSubId =
          saved.submissionId.isNotEmpty ? saved.submissionId : submissionId;
      if (effectiveSubId.isNotEmpty) {
        try {
          final reloaded = await GradingApiService.getGradingResult(effectiveSubId);
          if (reloaded != null) fresh = reloaded;
        } catch (_) {}
      }
      setState(() {
        _upsertResult(effectiveSubId, fresh);
        if (effectiveSubId.isNotEmpty) {
          _statuses = {..._statuses, effectiveSubId: GradingStatus.reviewed};
        }
        message = 'Review saved. Score updated.';
      });
    } catch (e) {
      setState(() => message = 'Review error: $e');
    }
  }

  Future<void> _finalizeBackendResult(String gradingResultId) async {
    try {
      final finalized = await ReviewApiService.finalizeResult(gradingResultId);
      GradingResult fresh = finalized.result;
      final subId = fresh.submissionId.isNotEmpty
          ? fresh.submissionId
          // Fallback: look up the submissionId from local results list.
          : results.firstWhere(
              (r) => r.id == gradingResultId,
              orElse: () => fresh,
            ).submissionId;
      if (subId.isNotEmpty) {
        try {
          final reloaded = await GradingApiService.getGradingResult(subId);
          if (reloaded != null) fresh = reloaded;
        } catch (_) {}
      }
      setState(() {
        if (subId.isNotEmpty) {
          _upsertResult(subId, fresh);
          _statuses = {..._statuses, subId: GradingStatus.finalized};
        }
        message = finalized.message;
      });
    } catch (e) {
      setState(() => message = 'Finalize error: $e');
    }
  }

  // ── Backend export ────────────────────────────────────────────────────────

  Future<void> _exportBackendExcel() async {
    if (_backendAssessmentId == null) {
      setState(() => message = 'Please select an assessment in Assessment Setup first.');
      return;
    }
    setState(() => message = 'Downloading Excel from backend...');
    try {
      final filePath = await ExportApiService.downloadAndOpenExcel(_backendAssessmentId!);
      setState(() {
        message = 'Excel downloaded & opened: $filePath';
        final exportedStatuses = Map<String, GradingStatus>.from(_statuses);
        for (final r in results) {
          exportedStatuses[r.submissionId] = GradingStatus.exported;
        }
        _statuses = exportedStatuses;
      });
    } catch (e) {
      setState(() => message = 'Export error: $e');
    }
  }

  // ── Mock grading ──────────────────────────────────────────────────────────

  GradingResult _mockGrade(Submission submission) {
    final nameInfo      = _extractStudentInfo(submission.fileName);
    final criteriaScores = _buildMockCriteriaScores();
    final finalScore    = criteriaScores.values.fold(0.0, (a, b) => a + b);
    final feedback      = _buildMockFeedback();
    final a = currentAssessment;
    final totalRaw = a != null && a.totalConvertedScore > 0
        ? double.parse((finalScore / a.totalConvertedScore * a.totalRawScore).toStringAsFixed(0))
        : finalScore * 10.0;
    return GradingResult(
      fileName:        submission.fileName,
      studentId:       nameInfo.$1,
      studentName:     nameInfo.$2,
      totalRawScore:   totalRaw,
      finalScore:      finalScore,
      criteriaScores:  criteriaScores,
      feedback:        feedback,
    );
  }

  Map<String, double> _buildMockCriteriaScores() {
    final a = currentAssessment;
    if (a != null && a.questions.isNotEmpty && a.assessmentId == 'pmg201c-pe2-sample') {
      return {
        a.questions[0].title: 1.4, a.questions[1].title: 1.8,
        a.questions[2].title: 2.4, a.questions[3].title: 2.9,
      };
    }
    if (a != null && a.questions.isNotEmpty) {
      return {
        for (final q in a.questions)
          q.title: double.parse((q.convertedMaxScore * 0.75).toStringAsFixed(1)),
      };
    }
    return const {
      'Project Charter': 1.4, 'Cost / Budget': 1.8,
      'Risk Register': 2.4, 'RACI Matrix': 2.9,
    };
  }

  String _buildMockFeedback() {
    final a = currentAssessment;
    if (a != null && a.assessmentId == 'pmg201c-pe2-sample') {
      return 'The submission shows a solid understanding of PMG201c project planning. '
          'The RACI matrix and risk register are clear. '
          'To improve, the student should explain budget assumptions and cost breakdowns in more detail.';
    }
    if (a != null) {
      return 'Mock AI assessment for ${a.courseCode} — ${a.assessmentTitle}. '
          'The submission demonstrates adequate understanding. '
          'Connect the real AI API for detailed feedback.';
    }
    return 'The submission shows a solid understanding of project planning. '
        'The RACI matrix and risk register are clear. '
        'To improve, the student should explain budget assumptions in more detail.';
  }

  (String, String) _extractStudentInfo(String fileName) {
    final lastDot = fileName.lastIndexOf('.');
    final clean   = lastDot > 0 ? fileName.substring(0, lastDot) : fileName;
    final parts   = clean.split('_');
    if (parts.length >= 2 && parts.first.toUpperCase().startsWith('SE')) {
      return (parts.first, parts.sublist(1).join(' '));
    }
    return ('N/A', clean);
  }

  // ── Excel export (standalone) ─────────────────────────────────────────────

  Future<void> exportExcel() async {
    if (_aiMode == AiMode.backend) {
      await _exportBackendExcel();
      return;
    }
    if (results.isEmpty) {
      setState(() => message = 'No grading results to export.');
      return;
    }
    final excel  = xls.Excel.createExcel();
    final hasQR  = results.first.questionResults != null;
    final now    = DateTime.now();
    final stamp  = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final fileName = 'PMG201c_grading_results_$stamp.xlsx';
    final headerStyle = xls.CellStyle(
      bold: true,
      backgroundColorHex: xls.ExcelColor.fromHexString('FF1F4E79'),
      fontColorHex: xls.ExcelColor.white,
      horizontalAlign: xls.HorizontalAlign.Center,
      verticalAlign: xls.VerticalAlign.Center,
    );
    final numericStyle = xls.CellStyle(
      numberFormat: xls.NumFormat.standard_2,
      horizontalAlign: xls.HorizontalAlign.Center,
    );
    final wrapStyle = xls.CellStyle(
      textWrapping: xls.TextWrapping.WrapText,
      verticalAlign: xls.VerticalAlign.Top,
    );
    void applyHeaderAndWidths(
      xls.Sheet sheet, int totalCols, int aiCommentCol, int reviewerNoteCol,
    ) {
      for (int c = 0; c < totalCols; c++) {
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).cellStyle = headerStyle;
        double w;
        if (c == 0) { w = 8; }
        else if (c == 1) { w = 16; }
        else if (c == 2) { w = 22; }
        else if (c == 3) { w = 28; }
        else if (c == aiCommentCol) { w = 45; }
        else if (c == reviewerNoteCol) { w = 45; }
        else if (c >= aiCommentCol - 2 && c < aiCommentCol) { w = 16; }
        else { w = 14; }
        sheet.setColumnWidth(c, w);
      }
    }
    if (hasQR) {
      final qTemplate    = results.first.questionResults!;
      final totalRawMax  = qTemplate.fold<double>(0, (s, q) => s + q.maxRawScore);
      final totalConvMax = qTemplate.fold<double>(0, (s, q) => s + q.maxConvertedScore);
      final qCount       = qTemplate.length;
      final aiCommentCol    = 4 + qCount * 2 + 2;
      final reviewerNoteCol = aiCommentCol + 1;
      final totalCols       = reviewerNoteCol + 1;
      final sheet = excel['Grading Results'];
      sheet.appendRow([
        xls.TextCellValue('STT'), xls.TextCellValue('Student ID'),
        xls.TextCellValue('Student Name'), xls.TextCellValue('File Name'),
        ...qTemplate.expand((qr) => [
          xls.TextCellValue('${qr.questionId.toUpperCase()} Raw (/${qr.maxRawScore.toInt()})'),
          xls.TextCellValue('${qr.questionId.toUpperCase()} Conv (/${qr.maxConvertedScore})'),
        ]),
        xls.TextCellValue('Total Raw (/${totalRawMax.toInt()})'),
        xls.TextCellValue('Total Converted (/$totalConvMax)'),
        xls.TextCellValue('AI Comment'), xls.TextCellValue('Reviewer Note'),
      ]);
      applyHeaderAndWidths(sheet, totalCols, aiCommentCol, reviewerNoteCol);
      for (int i = 0; i < results.length; i++) {
        final item = results[i];
        final qrs  = item.questionResults ?? [];
        sheet.appendRow([
          xls.IntCellValue(i + 1), xls.TextCellValue(item.studentId),
          xls.TextCellValue(item.studentName), xls.TextCellValue(item.fileName),
          ...qrs.expand((qr) => [xls.DoubleCellValue(qr.rawScore), xls.DoubleCellValue(qr.convertedScore)]),
          xls.DoubleCellValue(item.totalRawScore), xls.DoubleCellValue(item.finalScore),
          xls.TextCellValue(item.feedback), xls.TextCellValue(item.reviewerNote),
        ]);
        final rowIdx = i + 1;
        for (int c = 4; c < aiCommentCol; c++) {
          sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIdx)).cellStyle = numericStyle;
        }
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: aiCommentCol, rowIndex: rowIdx)).cellStyle = wrapStyle;
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: reviewerNoteCol, rowIndex: rowIdx)).cellStyle = wrapStyle;
      }
    } else {
      final criteriaKeys    = results.first.criteriaScores.keys.toList();
      final qCount          = criteriaKeys.length;
      final aiCommentCol    = 4 + qCount + 2;
      final reviewerNoteCol = aiCommentCol + 1;
      final totalCols       = reviewerNoteCol + 1;
      final sheet = excel['Summary'];
      sheet.appendRow([
        xls.TextCellValue('STT'), xls.TextCellValue('Student ID'),
        xls.TextCellValue('Student Name'), xls.TextCellValue('File Name'),
        ...criteriaKeys.map(xls.TextCellValue.new),
        xls.TextCellValue('Total Raw'), xls.TextCellValue('Total Converted'),
        xls.TextCellValue('AI Comment'), xls.TextCellValue('Reviewer Note'),
      ]);
      applyHeaderAndWidths(sheet, totalCols, aiCommentCol, reviewerNoteCol);
      for (int i = 0; i < results.length; i++) {
        final item = results[i];
        sheet.appendRow([
          xls.IntCellValue(i + 1), xls.TextCellValue(item.studentId),
          xls.TextCellValue(item.studentName), xls.TextCellValue(item.fileName),
          ...criteriaKeys.map((k) => xls.DoubleCellValue(item.criteriaScores[k] ?? 0.0)),
          xls.DoubleCellValue(item.totalRawScore), xls.DoubleCellValue(item.finalScore),
          xls.TextCellValue(item.feedback), xls.TextCellValue(item.reviewerNote),
        ]);
        final rowIdx = i + 1;
        for (int c = 4; c < aiCommentCol; c++) {
          sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIdx)).cellStyle = numericStyle;
        }
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: aiCommentCol, rowIndex: rowIdx)).cellStyle = wrapStyle;
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: reviewerNoteCol, rowIndex: rowIdx)).cellStyle = wrapStyle;
      }
    }
    final downloads = await getDownloadsDirectory();
    final documents = await getApplicationDocumentsDirectory();
    final saveDir   = downloads ?? documents;
    final filePath  = p.join(saveDir.path, fileName);
    final bytes     = excel.save();
    if (bytes == null) {
      setState(() => message = 'Cannot generate Excel file.');
      return;
    }
    File(filePath)..createSync(recursive: true)..writeAsBytesSync(bytes);
    final exportedStatuses = Map<String, GradingStatus>.from(_statuses);
    for (final r in results) {
      exportedStatuses[r.fileName] = GradingStatus.exported;
    }
    setState(() {
      _statuses = exportedStatuses;
      message   = 'Excel exported: $filePath';
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _debugGradingResult(GradingResult r) {
    debugPrint('[GradingResult] id=${r.id} submissionId=${r.submissionId} fileName=${r.fileName}');
    debugPrint('[GradingResult] totalRaw=${r.totalRawScore} totalConv=${r.finalScore} '
        'reviewStatus=${r.reviewStatus} status=${r.status}');
    final items = r.questionResults;
    final cnt = items?.length ?? 0;
    debugPrint('[GradingResult] items=$cnt');
    if (items != null && items.isNotEmpty) {
      final maxRawSum  = items.fold(0.0, (s, i) => s + i.maxRawScore);
      final maxConvSum = items.fold(0.0, (s, i) => s + i.maxConvertedScore);
      debugPrint('[GradingResult] maxRawSum=$maxRawSum maxConvSum=$maxConvSum');
    }
  }

  GradingStatus _mapBackendStatus(String s) => switch (s) {
    'UPLOADED' => GradingStatus.pending,
    'GRADING'  => GradingStatus.grading,
    'GRADED'   => GradingStatus.graded,
    'ERROR'    => GradingStatus.error,
    _          => GradingStatus.pending,
  };

  GradingStatus _mapReviewStatus(String s) => switch (s) {
    'AI_GRADED' => GradingStatus.graded,
    'REVIEWED'  => GradingStatus.reviewed,
    'FINALIZED' => GradingStatus.finalized,
    _           => GradingStatus.graded,
  };

  // ── Getters ───────────────────────────────────────────────────────────────

  GradingResult? get selectedResult {
    if (_aiMode == AiMode.backend) {
      if (selectedSubmissionIndex == null) return null;
      if (selectedSubmissionIndex! >= submissions.length) return null;
      final subId = submissions[selectedSubmissionIndex!].id;
      for (final r in results) { if (r.submissionId == subId) return r; }
      return null;
    }
    if (selectedSubmissionIndex == null) return null;
    if (selectedSubmissionIndex! >= submissions.length) return null;
    final fileName = submissions[selectedSubmissionIndex!].fileName;
    for (final result in results) { if (result.fileName == fileName) return result; }
    return null;
  }

  Submission? get selectedSubmission {
    if (selectedSubmissionIndex == null) return null;
    if (selectedSubmissionIndex! >= submissions.length) return null;
    return submissions[selectedSubmissionIndex!];
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        submissions:       submissions,
        results:           results,
        statuses:          _statuses,
        message:           message,
        isGrading:         isGrading,
        aiMode:            _aiMode,
        currentAssessment: currentAssessment,
        userProfile:       widget.user,
        backendOnline:     _backendOnline,
        questionUploaded:  _questionUploaded,
        guideUploaded:     _guideUploaded,
        onPickFiles:       pickTxtFiles,
        onGradeAll:        gradeAll,
        onSelectSubmission: (index) {
          final subId = index < submissions.length ? submissions[index].id : '?';
          debugPrint('[RowOpen] index=$index submissionId=$subId → navigate to Grading');
          setState(() {
            selectedSubmissionIndex = index;
            selectedIndex           = 3;
          });
          if (_aiMode == AiMode.backend) {
            _fetchFullSubmissionIfNeeded(index);
            // forceRefresh so opening a row always reflects the latest backend state.
            _fetchGradingResultForSubmission(index, forceRefresh: true);
          }
        },
        onNavigate: (index) => setState(() => selectedIndex = index),
      ),
      AssessmentSetupScreen(
        currentAssessment: currentAssessment,
        onApplyAssessment: _applyAssessment,
      ),
      CriteriaPage(assessment: currentAssessment),
      GradingPage(
        submission:    selectedSubmission,
        result:        selectedResult,
        onGradeAll:    gradeAll,
        onGradeCurrent: gradeCurrent,
        onSaveReview:  _aiMode == AiMode.backend ? _saveBackendReview : _saveReview,
        onFinalize:    _aiMode == AiMode.backend ? (id) => _finalizeBackendResult(id) : null,
        onNextSubmission: (selectedSubmissionIndex ?? -1) < submissions.length - 1
            ? _selectNextSubmission
            : null,
        isContentLoading: _loadingSubmissionId != null &&
            _loadingSubmissionId == selectedSubmission?.id,
        aiMode:        _aiMode,
        assessment:    currentAssessment,
        isGrading:     isGrading,
        status:        _aiMode == AiMode.backend
            ? (_statuses[selectedSubmission?.id])
            : (_statuses[selectedSubmission?.fileName]),
        gradingError:  _aiMode == AiMode.backend
            ? (_gradingErrors[selectedSubmission?.id])
            : (_gradingErrors[selectedSubmission?.fileName]),
      ),
      ExportPage(
        results:              results,
        onExportExcel:        exportExcel,
        aiMode:               _aiMode,
        backendAssessmentId:  _backendAssessmentId,
      ),
      SettingsScreen(
        apiKey:               _apiKey,
        modelId:              _modelId,
        geminiApiKey:         _geminiApiKey,
        geminiModelId:        _geminiModelId,
        aiMode:               _aiMode,
        backendAssessmentId:  _backendAssessmentId,
        onSaveApiKey:         _updateApiKey,
        onClearApiKey:        _clearApiKey,
        onSaveModelId:        _updateModelId,
        onSaveGeminiApiKey:   _updateGeminiApiKey,
        onClearGeminiApiKey:  _clearGeminiApiKey,
        onSaveGeminiModelId:  _updateGeminiModelId,
        onChangeAiMode:       _updateAiMode,
        onSetBackendAssessmentId: _setBackendAssessmentId,
      ),
    ];

    final titles = [
      'Workspace', 'Assessment Setup', 'Criteria Matrix',
      'AI Grading Detail', 'Export Data', 'Settings',
    ];

    return Scaffold(
      body: Row(
        children: [
          SideNav(
            selectedIndex: selectedIndex,
            onSelect:      (index) => setState(() => selectedIndex = index),
            user:          widget.user,
            onLogout:      widget.onLogout,
          ),
          Expanded(
            child: Column(
              children: [
                TopBar(
                  title:         titles[selectedIndex],
                  backendOnline: _backendOnline,
                  user:          widget.user,
                ),
                Expanded(child: pages[selectedIndex]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Backend review handler ────────────────────────────────────────────────

  void _saveBackendReview(GradingResult updated) {
    if (updated.id.isEmpty) {
      // No existing grading result — use POST /manual-result.
      _submitManualResult(updated);
      return;
    }
    // Existing grading result — use PUT /review.
    final items = updated.questionResults?.asMap().entries.map((e) {
      return {
        'gradingResultItemId': e.value.id,
        'reviewedRawScore':    e.value.rawScore,
        // teacherComment is stored in the dedicated field after our fix;
        // fall back to comment for legacy QRs created before the update.
        'teacherComment': e.value.teacherComment.isNotEmpty
            ? e.value.teacherComment
            : e.value.comment,
      };
    }).toList() ?? [];
    if (items.any((item) => (item['gradingResultItemId'] as String).isEmpty)) {
      debugPrint('[Review] Warning: one or more gradingResultItemId values are '
          'empty — per-item scores may not be persisted on the backend.');
    }
    _submitBackendReview(
      gradingResultId:       updated.id,
      submissionId:          updated.submissionId,
      teacherOverallComment: updated.teacherOverallComment,
      items:                 items,
    );
  }

  /// Handles the POST /api/submissions/{submissionId}/manual-result path.
  /// Called when the teacher saves Manual Grading Mode and no AI result
  /// exists yet (updated.id is empty).
  Future<void> _submitManualResult(GradingResult updated) async {
    final submissionId = updated.submissionId;
    if (submissionId.isEmpty) {
      setState(() => message = 'Manual result error: submissionId is missing.');
      return;
    }

    // Build items using rubricItemId + questionNo from the assessment rubric.
    final rubric = currentAssessment?.questions ?? <QuestionRubric>[];
    final items = <Map<String, dynamic>>[];
    final qrs = updated.questionResults ?? [];
    for (int i = 0; i < qrs.length; i++) {
      final qr         = qrs[i];
      // rubricItemId: the backend UUID stored in questionId (set in _saveManualReview)
      final rubricItemId = qr.questionId;
      // questionNo: 1-based index matching the rubric order
      final questionNo   = i + 1;
      // Override with rubric if available
      final rubricItem   = i < rubric.length ? rubric[i] : null;
      items.add({
        'rubricItemId':     rubricItem?.questionId ?? rubricItemId,
        'questionNo':       questionNo,
        'reviewedRawScore': qr.rawScore,
        'teacherComment':   qr.teacherComment,
      });
    }

    final request = <String, dynamic>{
      'items': items,
      if (updated.teacherOverallComment.isNotEmpty)
        'teacherOverallComment': updated.teacherOverallComment,
    };

    debugPrint('[ManualResult] POST /api/submissions/$submissionId/manual-result '
        'itemCount=${items.length} teacherOverallComment="${updated.teacherOverallComment}"');

    try {
      final saved = await GradingApiService.createManualResult(submissionId, request);

      debugPrint('[ManualResult] returned resultId=${saved.id} '
          'reviewStatus=${saved.reviewStatus}');

      // Reload from backend to get server-computed scores.
      GradingResult fresh = saved;
      final effectiveSubId =
          saved.submissionId.isNotEmpty ? saved.submissionId : submissionId;
      if (effectiveSubId.isNotEmpty) {
        try {
          final reloaded = await GradingApiService.getGradingResult(effectiveSubId);
          if (reloaded != null) fresh = reloaded;
        } catch (_) {}
      }

      setState(() {
        _upsertResult(effectiveSubId, fresh);
        _statuses = {..._statuses, effectiveSubId: GradingStatus.reviewed};
        message   = 'Manual grades saved. Score updated.';
      });

      // Refresh both submissions list and review-results so Home + Export reflect
      // the newly created grading result.
      if (_backendAssessmentId != null) {
        await _refreshBackendResults();
      }
    } catch (e) {
      if (mounted) setState(() => message = 'Manual result error: $e');
    }
  }
}
