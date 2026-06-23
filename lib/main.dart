import 'dart:io';

import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'core/storage/settings_storage.dart';
import 'features/export/services/export_api_service.dart';
import 'features/grading/services/grading_api_service.dart';
import 'features/review/services/review_api_service.dart';
import 'features/submission/services/submission_api_service.dart';
import 'models/ai_mode.dart';
import 'models/assessment.dart';
import 'models/grading_result.dart';
import 'models/grading_status.dart';
import 'models/submission.dart';
import 'screens/assessment_setup_screen.dart';
import 'screens/criteria_screen.dart';
import 'screens/export_screen.dart';
import 'screens/grading_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'services/ai/gemini_grading_service.dart';
import 'services/ai/openrouter_grading_service.dart';
import 'services/file/document_text_extractor_service.dart';
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
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selectedIndex = 0;
  int? selectedSubmissionIndex;

  List<Submission> submissions = [];
  List<GradingResult> results = [];
  Map<String, GradingStatus> _statuses = {};

  Assessment? currentAssessment;

  // ── AI configuration (standalone mode) ─────────────────────────────────────
  String _apiKey = '';
  String _modelId = 'openrouter/free';
  String _geminiApiKey = '';
  String _geminiModelId = 'gemini-2.0-flash-lite';
  AiMode _aiMode = AiMode.mock;

  Map<String, String> _gradingErrors = {};

  bool isGrading = false;
  String message = 'Ready. Import submission files to begin.';

  // ── Backend mode state ─────────────────────────────────────────────────────
  String? _backendAssessmentId;
  String? _loadingSubmissionId;
  final Set<String> _fetchedFullSubmissionIds = {};

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadSavedAiMode();
  }

  Future<void> _loadSavedAiMode() async {
    final saved = await SettingsStorage.loadAiMode();
    if (mounted) setState(() => _aiMode = saved);
  }

  // ── Assessment ────────────────────────────────────────────────────────────

  void _applyAssessment(Assessment assessment) {
    setState(() {
      currentAssessment = assessment;
      // Auto-sync so upload/grade/export use the selected assessment ID.
      _backendAssessmentId = assessment.assessmentId;
      submissions = [];
      results = [];
      _statuses = {};
      _gradingErrors = {};
      selectedSubmissionIndex = null;
      _loadingSubmissionId = null;
      _fetchedFullSubmissionIds.clear();
      message =
          'Assessment loaded: ${assessment.courseCode} — ${assessment.assessmentTitle}';
    });
    // Auto-load any existing submissions so the workspace is never empty
    // when switching to an assessment that was worked on previously.
    if (_aiMode == AiMode.backend) _loadBackendSubmissions();
  }

  /// Loads all existing submissions for the current assessment from the backend.
  /// Called on assessment selection so prior-session data is immediately visible.
  Future<void> _loadBackendSubmissions() async {
    if (_backendAssessmentId == null) return;
    try {
      final subs = await SubmissionApiService.getSubmissions(_backendAssessmentId!);
      if (!mounted || subs.isEmpty) return;
      setState(() {
        submissions = subs;
        _statuses = {
          for (final s in subs) s.id: _mapBackendStatus(s.gradingStatus),
        };
        message = '${subs.length} submission(s) loaded for this assessment.';
      });
    } catch (_) {
      // Silently ignore — assessment may have no submissions yet.
    }
  }

  // ── SET BACKEND ASSESSMENT ID ──────────────────────────────────────────────

  void _setBackendAssessmentId(String assessmentId) {
    setState(() {
      _backendAssessmentId = assessmentId;
      message = 'Backend assessment ID set: $assessmentId';
    });
  }

  // ── Navigate to next submission ────────────────────────────────────────────

  void _selectNextSubmission() {
    if (selectedSubmissionIndex == null) return;
    final next = selectedSubmissionIndex! + 1;
    if (next < submissions.length) {
      setState(() => selectedSubmissionIndex = next);
      if (_aiMode == AiMode.backend) {
        _fetchFullSubmissionIfNeeded(next);
        _fetchGradingResultForSubmission(next);
      }
    }
  }

  /// Fetches the backend grading result for the submission at [index] and
  /// updates local [results] state so Grading Detail can display it.
  ///
  /// Skips silently when:
  /// - a result for this submission is already in [results]
  /// - the submission has no backend id
  /// - the backend returns null (not yet graded)
  Future<void> _fetchGradingResultForSubmission(int index) async {
    if (index < 0 || index >= submissions.length) return;
    final sub = submissions[index];
    if (sub.id.isEmpty) return;

    // Skip if we already have a result for this submission in local state.
    if (results.any((r) => r.submissionId == sub.id)) return;

    try {
      final result = await GradingApiService.getGradingResult(sub.id);
      if (!mounted) return;
      if (result == null) return; // not yet graded — leave status as-is

      setState(() {
        final idx = results.indexWhere((r) => r.submissionId == sub.id);
        if (idx >= 0) {
          final copy = List<GradingResult>.from(results);
          copy[idx] = result;
          results = copy;
        } else {
          results = [...results, result];
        }
        // Sync the status badge on the submission card.
        _statuses = {
          ..._statuses,
          sub.id: _mapReviewStatus(result.reviewStatus),
        };
      });
    } catch (_) {
      // Silently ignore — submission may not be graded yet, or transient error.
    }
  }

  // ── Fetch full submission text on demand (backend list may return truncated extractedText) ─

  Future<void> _fetchFullSubmissionIfNeeded(int index) async {
    if (index < 0 || index >= submissions.length) return;
    final sub = submissions[index];
    if (sub.id.isEmpty) return;
    // Skip if we already fetched the full content for this submission.
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
      // Allow a retry on next selection.
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

  void _updateApiKey(String value) => setState(() => _apiKey = value);
  void _clearApiKey() => setState(() => _apiKey = '');
  void _updateModelId(String value) => setState(() => _modelId = value);
  void _updateGeminiApiKey(String value) => setState(() => _geminiApiKey = value);
  void _clearGeminiApiKey() => setState(() => _geminiApiKey = '');
  void _updateGeminiModelId(String value) => setState(() => _geminiModelId = value);
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
      if (_apiKey.trim().isEmpty) {
        setState(() => message = 'Please enter OpenRouter API key in Settings.');
        return;
      }
      if (_modelId.trim().isEmpty) {
        setState(() => message = 'Please enter a Model ID in Settings.');
        return;
      }
      if (currentAssessment == null) {
        setState(() => message = 'Please load or create an assessment first (Assessment Setup).');
        return;
      }
    }

    if (_aiMode == AiMode.gemini) {
      if (_geminiApiKey.trim().isEmpty) {
        setState(() => message = 'Please enter Gemini API key in Settings.');
        return;
      }
      if (_geminiModelId.trim().isEmpty) {
        setState(() => message = 'Please enter a Gemini Model ID in Settings.');
        return;
      }
      if (currentAssessment == null) {
        setState(() => message = 'Please load or create an assessment first (Assessment Setup).');
        return;
      }
    }

    if (submission.hasError || submission.content.trim().isEmpty) {
      final errMsg = submission.hasError
          ? 'Cannot grade: ${submission.extractionError}'
          : 'Cannot grade: file content is empty.';
      setState(() {
        message = 'Error: $errMsg';
        _statuses = {..._statuses, submission.fileName: GradingStatus.error};
        _gradingErrors = {..._gradingErrors, submission.fileName: errMsg};
      });
      return;
    }

    setState(() {
      isGrading = true;
      _statuses = {..._statuses, submission.fileName: GradingStatus.pending};
      message = 'Grading ${submission.fileName}...';
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
        _statuses = {..._statuses, result.fileName: GradingStatus.graded};
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
        isGrading = false;
        _statuses = {..._statuses, submission.fileName: GradingStatus.error};
        _gradingErrors = {..._gradingErrors, submission.fileName: display};
        message = 'Error: $display';
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
        content: extracted.extractedText,
        sizeInBytes: file.size,
        extractionError: extractionError,
      ));
    }

    final errorCount = picked.where((s) => s.hasError).length;
    final validCount = picked.length - errorCount;

    setState(() {
      submissions = picked;
      results = [];
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
    if (_aiMode == AiMode.backend) {
      await _gradeAllBackend();
      return;
    }

    if (submissions.isEmpty) {
      setState(() => message = 'Please import submission files first.');
      return;
    }

    if (_aiMode == AiMode.openRouter) {
      if (_apiKey.trim().isEmpty) {
        setState(() => message = 'Please enter OpenRouter API key in Settings.');
        return;
      }
      if (_modelId.trim().isEmpty) {
        setState(() => message = 'Please enter a Model ID in Settings.');
        return;
      }
      if (currentAssessment == null) {
        setState(() => message = 'Please load or create an assessment first (Assessment Setup).');
        return;
      }
    }

    if (_aiMode == AiMode.gemini) {
      if (_geminiApiKey.trim().isEmpty) {
        setState(() => message = 'Please enter Gemini API key in Settings.');
        return;
      }
      if (_geminiModelId.trim().isEmpty) {
        setState(() => message = 'Please enter a Gemini Model ID in Settings.');
        return;
      }
      if (currentAssessment == null) {
        setState(() => message = 'Please load or create an assessment first (Assessment Setup).');
        return;
      }
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
      message = 'Starting grading for ${toGrade.length} file(s)...';
    });

    int gradedCount = 0;
    int errorCount = 0;

    for (int i = 0; i < toGrade.length; i++) {
      final submission = toGrade[i];
      setState(() => message = 'Grading ${i + 1}/${toGrade.length}: ${submission.fileName}');

      if (submission.hasError || submission.content.trim().isEmpty) {
        final errMsg = submission.hasError
            ? 'Cannot grade: ${submission.extractionError}'
            : 'Cannot grade: file content is empty.';
        errorCount++;
        setState(() {
          _statuses = {..._statuses, submission.fileName: GradingStatus.error};
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
          _statuses = {..._statuses, result.fileName: GradingStatus.graded};
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
          _statuses = {..._statuses, submission.fileName: GradingStatus.error};
          _gradingErrors = {..._gradingErrors, submission.fileName: display};
        });
      }
    }

    setState(() {
      isGrading = false;
      message = errorCount > 0
          ? 'Grading complete: $gradedCount graded, $errorCount error(s). Click a failed file to retry.'
          : switch (_aiMode) {
              AiMode.mock => 'Mock grading complete. $gradedCount result(s) ready.',
              AiMode.openRouter => 'OpenRouter grading complete. $gradedCount result(s) ready.',
              AiMode.gemini => 'Gemini grading complete. $gradedCount result(s) ready.',
              AiMode.backend => 'Backend grading complete.',
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
        .where((p) => p != null)
        .cast<String>()
        .toList();

    if (filePaths.isEmpty) {
      setState(() => message = 'No valid files selected.');
      return;
    }

    setState(() {
      isGrading = true;
      message = 'Uploading ${filePaths.length} file(s) to backend...';
    });

    try {
      final uploadResult = await SubmissionApiService.uploadSubmissions(
        _backendAssessmentId!, filePaths,
      );

      // Fetch the full list from backend
      final backendSubs = await SubmissionApiService.getSubmissions(_backendAssessmentId!);

      setState(() {
        submissions = backendSubs;
        results = [];
        _gradingErrors = {};
        _statuses = {
          for (final s in backendSubs)
            s.id: _mapBackendStatus(s.gradingStatus),
        };
        selectedSubmissionIndex = backendSubs.isNotEmpty ? 0 : null;
        isGrading = false;
        message = 'Uploaded ${uploadResult.uploaded} file(s), ${uploadResult.failed} failed. '
            '${backendSubs.length} submission(s) on server.';
      });
    } catch (e) {
      setState(() {
        isGrading = false;
        message = 'Upload error: $e';
      });
    }
  }

  Future<void> _gradeAllBackend() async {
    if (_backendAssessmentId == null) {
      setState(() => message = 'Please select an assessment in Assessment Setup first.');
      return;
    }

    setState(() {
      isGrading = true;
      message = 'Starting backend grading job...';
    });

    try {
      final jobResult = await GradingApiService.createGradingJob(_backendAssessmentId!);

      setState(() {
        message = jobResult.message;
      });

      // Poll until done — max 150 attempts × 2 s = 5 minutes.
      bool done = false;
      int pollAttempts = 0;
      const maxPollAttempts = 150;
      const finalStatuses = {'COMPLETED', 'COMPLETED_WITH_ERRORS', 'ERROR'};

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
          message = 'Grading timed out after ${pollAttempts * 2}s. '
              'The job may still be running on the server. '
              'Refresh results manually when ready.';
        });
        return;
      }

      // Fetch all results
      await _refreshBackendResults();
    } catch (e) {
      setState(() {
        isGrading = false;
        message = 'Backend grading error: $e';
      });
    }
  }

  Future<void> _gradeSingleBackend() async {
    final submission = selectedSubmission;
    if (submission == null) {
      setState(() => message = 'No submission selected.');
      return;
    }

    setState(() {
      isGrading = true;
      message = 'Grading ${submission.fileName} via backend...';
    });

    try {
      // Trigger grading via POST.
      await GradingApiService.gradeSubmission(submission.id);

      // Fetch the full grading result via GET — guarantees submissionId and
      // all rubric item fields are populated (POST response may omit them).
      final result = await GradingApiService.getGradingResult(submission.id);

      if (!mounted) return;

      setState(() {
        isGrading = false;
        if (result != null) {
          final idx = results.indexWhere((r) => r.submissionId == submission.id);
          if (idx >= 0) {
            final copy = List<GradingResult>.from(results);
            copy[idx] = result;
            results = copy;
          } else {
            results = [...results, result];
          }
          _statuses = {..._statuses, submission.id: GradingStatus.graded};
          _gradingErrors = Map.from(_gradingErrors)..remove(submission.id);
          message =
              'Graded: ${result.studentName.isNotEmpty ? result.studentName : submission.fileName}';
        } else {
          message = 'Grading completed. Tap refresh to reload results.';
        }
      });
    } catch (e) {
      setState(() {
        isGrading = false;
        message = 'Backend grading error: $e';
      });
    }
  }

  Future<void> _refreshBackendResults() async {
    if (_backendAssessmentId == null) return;

    try {
      final subs = await SubmissionApiService.getSubmissions(_backendAssessmentId!);
      final newResults = <GradingResult>[];
      final newStatuses = <String, GradingStatus>{};

      for (final sub in subs) {
        newStatuses[sub.id] = _mapBackendStatus(sub.gradingStatus);

        if (sub.gradingStatus == 'GRADED') {
          try {
            final gr = await GradingApiService.getGradingResult(sub.id);
            if (gr != null) {
              newResults.add(gr);
              newStatuses[sub.id] = _mapReviewStatus(gr.reviewStatus);
            }
          } catch (_) {}
        }
      }

      setState(() {
        submissions = subs;
        results = newResults;
        _statuses = newStatuses;
        isGrading = false;
        message = 'Loaded ${subs.length} submission(s), ${newResults.length} graded.';
      });
    } catch (e) {
      setState(() {
        isGrading = false;
        message = 'Error refreshing results: $e';
      });
    }
  }

  // ── Backend review ────────────────────────────────────────────────────────

  Future<void> _submitBackendReview({
    required String gradingResultId,
    required String teacherOverallComment,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final saved = await ReviewApiService.submitReview(
        gradingResultId,
        {
          'teacherOverallComment': teacherOverallComment,
          'items': items,
        },
      );

      // Reload the grading result from backend to reflect server-computed scores.
      GradingResult fresh = saved;
      if (saved.submissionId.isNotEmpty) {
        try {
          final reloaded =
              await GradingApiService.getGradingResult(saved.submissionId);
          if (reloaded != null) fresh = reloaded;
        } catch (_) {}
      }

      setState(() {
        final idx = results.indexWhere((r) => r.id == fresh.id);
        if (idx >= 0) {
          final copy = List<GradingResult>.from(results);
          copy[idx] = fresh;
          results = copy;
        }
        _statuses = {
          ..._statuses,
          fresh.submissionId: GradingStatus.reviewed,
        };
        message = 'Review saved. Score updated.';
      });
    } catch (e) {
      setState(() => message = 'Review error: $e');
    }
  }

  Future<void> _finalizeBackendResult(String gradingResultId) async {
    try {
      final finalized = await ReviewApiService.finalizeResult(gradingResultId);

      // Reload after finalize to get server-confirmed final scores.
      GradingResult fresh = finalized.result;
      if (finalized.result.submissionId.isNotEmpty) {
        try {
          final reloaded = await GradingApiService.getGradingResult(
              finalized.result.submissionId);
          if (reloaded != null) fresh = reloaded;
        } catch (_) {}
      }

      setState(() {
        final idx = results.indexWhere((r) => r.id == fresh.id);
        if (idx >= 0) {
          final copy = List<GradingResult>.from(results);
          copy[idx] = fresh;
          results = copy;
        }
        _statuses = {
          ..._statuses,
          fresh.submissionId: GradingStatus.finalized,
        };
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
    final nameInfo = _extractStudentInfo(submission.fileName);
    final criteriaScores = _buildMockCriteriaScores();
    final finalScore = criteriaScores.values.fold(0.0, (a, b) => a + b);
    final feedback = _buildMockFeedback();
    final a = currentAssessment;
    final totalRaw = a != null && a.totalConvertedScore > 0
        ? double.parse((finalScore / a.totalConvertedScore * a.totalRawScore).toStringAsFixed(0))
        : finalScore * 10.0;

    return GradingResult(
      fileName: submission.fileName,
      studentId: nameInfo.$1,
      studentName: nameInfo.$2,
      totalRawScore: totalRaw,
      finalScore: finalScore,
      criteriaScores: criteriaScores,
      feedback: feedback,
    );
  }

  Map<String, double> _buildMockCriteriaScores() {
    final a = currentAssessment;
    if (a != null && a.questions.isNotEmpty && a.assessmentId == 'pmg201c-pe2-sample') {
      return {
        a.questions[0].title: 1.4,
        a.questions[1].title: 1.8,
        a.questions[2].title: 2.4,
        a.questions[3].title: 2.9,
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
    final clean = lastDot > 0 ? fileName.substring(0, lastDot) : fileName;
    final parts = clean.split('_');
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

    final excel = xls.Excel.createExcel();
    final hasQR = results.first.questionResults != null;

    final now = DateTime.now();
    final stamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
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
      final qTemplate = results.first.questionResults!;
      final totalRawMax = qTemplate.fold<double>(0, (s, q) => s + q.maxRawScore);
      final totalConvMax = qTemplate.fold<double>(0, (s, q) => s + q.maxConvertedScore);
      final qCount = qTemplate.length;
      final aiCommentCol = 4 + qCount * 2 + 2;
      final reviewerNoteCol = aiCommentCol + 1;
      final totalCols = reviewerNoteCol + 1;
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
        final qrs = item.questionResults ?? [];
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
      final criteriaKeys = results.first.criteriaScores.keys.toList();
      final qCount = criteriaKeys.length;
      final aiCommentCol = 4 + qCount + 2;
      final reviewerNoteCol = aiCommentCol + 1;
      final totalCols = reviewerNoteCol + 1;
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
    final saveDir = downloads ?? documents;
    final filePath = p.join(saveDir.path, fileName);
    final bytes = excel.save();
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
      message = 'Excel exported: $filePath';
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  GradingStatus _mapBackendStatus(String s) => switch (s) {
    'UPLOADED' => GradingStatus.pending,
    'GRADING' => GradingStatus.grading,
    'GRADED' => GradingStatus.graded,
    'ERROR' => GradingStatus.error,
    _ => GradingStatus.pending,
  };

  GradingStatus _mapReviewStatus(String s) => switch (s) {
    'AI_GRADED' => GradingStatus.graded,
    'REVIEWED' => GradingStatus.reviewed,
    'FINALIZED' => GradingStatus.finalized,
    _ => GradingStatus.graded,
  };

  // ── Getters ───────────────────────────────────────────────────────────────

  GradingResult? get selectedResult {
    if (_aiMode == AiMode.backend) {
      if (selectedSubmissionIndex == null) return null;
      if (selectedSubmissionIndex! >= submissions.length) return null;
      final subId = submissions[selectedSubmissionIndex!].id;
      for (final r in results) {
        if (r.submissionId == subId) return r;
      }
      return null;
    }

    if (selectedSubmissionIndex == null) return null;
    if (selectedSubmissionIndex! >= submissions.length) return null;
    final fileName = submissions[selectedSubmissionIndex!].fileName;
    for (final result in results) {
      if (result.fileName == fileName) return result;
    }
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
        submissions: submissions,
        results: results,
        statuses: _statuses,
        message: message,
        isGrading: isGrading,
        aiMode: _aiMode,
        onPickFiles: pickTxtFiles,
        onGradeAll: gradeAll,
        onSelectSubmission: (index) {
          setState(() {
            selectedSubmissionIndex = index;
            selectedIndex = 3;
          });
          if (_aiMode == AiMode.backend) {
            _fetchFullSubmissionIfNeeded(index);
            _fetchGradingResultForSubmission(index);
          }
        },
      ),
      AssessmentSetupScreen(
        currentAssessment: currentAssessment,
        onApplyAssessment: _applyAssessment,
      ),
      CriteriaPage(assessment: currentAssessment),
      GradingPage(
        submission: selectedSubmission,
        result: selectedResult,
        onGradeAll: gradeAll,
        onGradeCurrent: gradeCurrent,
        onSaveReview: _aiMode == AiMode.backend ? _saveBackendReview : _saveReview,
        onFinalize: _aiMode == AiMode.backend ? (id) => _finalizeBackendResult(id) : null,
        onNextSubmission: (selectedSubmissionIndex ?? -1) < submissions.length - 1
            ? _selectNextSubmission
            : null,
        isContentLoading: _loadingSubmissionId != null &&
            _loadingSubmissionId == selectedSubmission?.id,
        aiMode: _aiMode,
        assessment: currentAssessment,
        isGrading: isGrading,
        status: _aiMode == AiMode.backend
            ? (_statuses[selectedSubmission?.id])
            : (_statuses[selectedSubmission?.fileName]),
        gradingError: _aiMode == AiMode.backend
            ? (_gradingErrors[selectedSubmission?.id])
            : (_gradingErrors[selectedSubmission?.fileName]),
      ),
      ExportPage(
        results: results,
        onExportExcel: exportExcel,
        aiMode: _aiMode,
        backendAssessmentId: _backendAssessmentId,
      ),
      SettingsScreen(
        apiKey: _apiKey,
        modelId: _modelId,
        geminiApiKey: _geminiApiKey,
        geminiModelId: _geminiModelId,
        aiMode: _aiMode,
        backendAssessmentId: _backendAssessmentId,
        onSaveApiKey: _updateApiKey,
        onClearApiKey: _clearApiKey,
        onSaveModelId: _updateModelId,
        onSaveGeminiApiKey: _updateGeminiApiKey,
        onClearGeminiApiKey: _clearGeminiApiKey,
        onSaveGeminiModelId: _updateGeminiModelId,
        onChangeAiMode: _updateAiMode,
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
            onSelect: (index) => setState(() => selectedIndex = index),
          ),
          Expanded(
            child: Column(
              children: [
                TopBar(title: titles[selectedIndex]),
                Expanded(child: pages[selectedIndex]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Backend review handler (wired to GradingPage.onSaveReview) ────────────

  void _saveBackendReview(GradingResult updated) {
    // P0-D: Guard — gradingResultId must be non-empty
    if (updated.id.isEmpty) {
      setState(() => message =
          'Review error: gradingResultId is missing. Cannot save review.');
      return;
    }

    final items = updated.questionResults?.asMap().entries.map((e) {
      return {
        'gradingResultItemId': e.value.id,
        'reviewedRawScore': e.value.rawScore,
        'teacherComment': e.value.comment,
      };
    }).toList() ?? [];

    // P0-D: Warn when item IDs are empty (review may only save overall comment)
    if (items.any((item) => (item['gradingResultItemId'] as String).isEmpty)) {
      debugPrint('[Review] Warning: one or more gradingResultItemId values are '
          'empty — per-item scores may not be persisted on the backend.');
    }

    _submitBackendReview(
      gradingResultId: updated.id,
      teacherOverallComment: updated.teacherOverallComment,
      items: items,
    );
  }
}
