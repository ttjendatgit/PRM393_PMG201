/// Multi-format document text extractor.
///
/// Supported formats: .txt, .md, .docx, .pdf (text-based), .csv, .xlsx
/// NOT supported: scanned/image PDFs, OCR.
library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:excel/excel.dart' as xl;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart' as xmllib;

// ── Result model ──────────────────────────────────────────────────────────────

class DocumentExtractionResult {
  final String fileName;
  final String filePath;
  final String extension;
  final String extractedText;
  final bool success;
  final String? warningMessage;
  final String? errorMessage;

  const DocumentExtractionResult({
    required this.fileName,
    required this.filePath,
    required this.extension,
    required this.extractedText,
    required this.success,
    this.warningMessage,
    this.errorMessage,
  });

  bool get hasWarning => warningMessage != null && warningMessage!.isNotEmpty;
  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;
  bool get isEmpty => extractedText.trim().isEmpty;

  factory DocumentExtractionResult.error({
    required String fileName,
    required String filePath,
    required String extension,
    required String errorMessage,
  }) {
    return DocumentExtractionResult(
      fileName: fileName,
      filePath: filePath,
      extension: extension,
      extractedText: '',
      success: false,
      errorMessage: errorMessage,
    );
  }
}

// ── Service ───────────────────────────────────────────────────────────────────

class DocumentTextExtractorService {
  /// Supported file extensions for assessment files.
  static const List<String> supportedExtensions = [
    'txt',
    'md',
    'docx',
    'pdf',
    'csv',
    'xlsx',
  ];

  /// Extract readable text from [path].
  ///
  /// Always returns a [DocumentExtractionResult].  Check [result.success],
  /// [result.warningMessage], and [result.errorMessage] before using the text.
  static Future<DocumentExtractionResult> extractTextFromFile(
    String path,
  ) async {
    final file = File(path);
    final fileName = file.uri.pathSegments.last;
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';

    try {
      switch (ext) {
        case 'txt':
        case 'md':
          return await _extractPlainText(file, fileName, ext);

        case 'docx':
          return await _extractDocx(file, fileName, ext);

        case 'pdf':
          return await _extractPdf(file, fileName, ext);

        case 'csv':
          return await _extractCsv(file, fileName, ext);

        case 'xlsx':
          return await _extractXlsx(file, fileName, ext);

        default:
          return DocumentExtractionResult.error(
            fileName: fileName,
            filePath: path,
            extension: ext,
            errorMessage:
                'Unsupported file format ".${ext.isEmpty ? 'unknown' : ext}". '
                'Supported formats: ${supportedExtensions.join(', ')}.\n'
                'Please paste the text manually into the field below.',
          );
      }
    } catch (e) {
      return DocumentExtractionResult.error(
        fileName: fileName,
        filePath: path,
        extension: ext,
        errorMessage: 'Failed to extract text from "$fileName": $e\n'
            'Please paste the text manually into the field below.',
      );
    }
  }

  // ── .txt / .md ──────────────────────────────────────────────────────────────

  static Future<DocumentExtractionResult> _extractPlainText(
    File file,
    String fileName,
    String ext,
  ) async {
    String text;
    try {
      text = await file.readAsString(encoding: utf8);
    } catch (_) {
      // Fallback to latin-1 if UTF-8 decoding fails
      try {
        text = await file.readAsString(encoding: latin1);
      } catch (e) {
        return DocumentExtractionResult.error(
          fileName: fileName,
          filePath: file.path,
          extension: ext,
          errorMessage: 'Could not decode "$fileName" as text: $e',
        );
      }
    }

    return DocumentExtractionResult(
      fileName: fileName,
      filePath: file.path,
      extension: ext,
      extractedText: text,
      success: true,
    );
  }

  // ── .docx ───────────────────────────────────────────────────────────────────

  static Future<DocumentExtractionResult> _extractDocx(
    File file,
    String fileName,
    String ext,
  ) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // word/document.xml contains the main body
    final docEntry = archive.files.where(
      (f) => f.name == 'word/document.xml',
    ).firstOrNull;

    if (docEntry == null) {
      return DocumentExtractionResult.error(
        fileName: fileName,
        filePath: file.path,
        extension: ext,
        errorMessage:
            '"$fileName" does not appear to be a valid .docx file '
            '(word/document.xml not found).',
      );
    }

    final xmlString = utf8.decode(docEntry.content as List<int>);
    final document = xmllib.XmlDocument.parse(xmlString);

    final buffer = StringBuffer();

    // Namespaces used by Word XML
    const wNs = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';

    // Iterate body children: paragraphs (<w:p>) and table rows (<w:tr>)
    final body = document.findAllElements('body', namespace: wNs).firstOrNull
        ?? document.findAllElements('body').firstOrNull;

    if (body == null) {
      return DocumentExtractionResult.error(
        fileName: fileName,
        filePath: file.path,
        extension: ext,
        errorMessage: 'Could not locate document body in "$fileName".',
      );
    }

    _extractBodyText(body, buffer);

    final text = buffer.toString().trim();

    return DocumentExtractionResult(
      fileName: fileName,
      filePath: file.path,
      extension: ext,
      extractedText: text,
      success: true,
      warningMessage: text.isEmpty
          ? 'The document "$fileName" appears to be empty or uses an unsupported '
              'content structure. Please review the extracted text or paste manually.'
          : null,
    );
  }

  /// Recursively walk body nodes, emitting text with paragraph/table breaks.
  static void _extractBodyText(xmllib.XmlNode body, StringBuffer buf) {
    for (final child in body.children) {
      if (child is! xmllib.XmlElement) continue;
      final local = child.localName;

      if (local == 'p') {
        // Paragraph — collect all <w:t> text runs
        final paraText = _collectRunText(child);
        if (paraText.isNotEmpty) {
          buf.write(paraText);
        }
        buf.writeln();
      } else if (local == 'tbl') {
        // Table — extract rows, cells tab-separated
        _extractTableText(child, buf);
      } else {
        // Recurse into other containers (e.g. <w:body> children we may have missed)
        _extractBodyText(child, buf);
      }
    }
  }

  /// Extract all `<w:t>` text runs from a paragraph element.
  static String _collectRunText(xmllib.XmlElement para) {
    final sb = StringBuffer();
    for (final t in para.findAllElements('t')) {
      sb.write(t.innerText);
    }
    return sb.toString();
  }

  /// Extract table rows as tab-separated cells, one row per line.
  static void _extractTableText(xmllib.XmlElement table, StringBuffer buf) {
    for (final row in table.findElements('tr')) {
      final cells = row.findElements('tc').map(_collectRunText).toList();
      if (cells.any((c) => c.isNotEmpty)) {
        buf.writeln(cells.join('\t'));
      }
    }
  }

  // ── .pdf ────────────────────────────────────────────────────────────────────

  static Future<DocumentExtractionResult> _extractPdf(
    File file,
    String fileName,
    String ext,
  ) async {
    final bytes = await file.readAsBytes();
    final PdfDocument doc = PdfDocument(inputBytes: bytes);

    String text;
    try {
      final extractor = PdfTextExtractor(doc);
      text = extractor.extractText();
    } finally {
      doc.dispose();
    }

    final trimmed = text.trim();

    if (trimmed.isEmpty) {
      return DocumentExtractionResult(
        fileName: fileName,
        filePath: file.path,
        extension: ext,
        extractedText: '',
        success: true, // not a hard failure — let user paste manually
        warningMessage:
            'This PDF may be scanned or image-based — no text could be extracted '
            'from "$fileName". Please paste the content manually into the field '
            'below, or convert the PDF to a text-based format first.',
      );
    }

    return DocumentExtractionResult(
      fileName: fileName,
      filePath: file.path,
      extension: ext,
      extractedText: trimmed,
      success: true,
      warningMessage:
          'PDF text extracted from "$fileName". Please review the text below '
          'for formatting issues before applying the assessment.',
    );
  }

  // ── .csv ────────────────────────────────────────────────────────────────────

  static Future<DocumentExtractionResult> _extractCsv(
    File file,
    String fileName,
    String ext,
  ) async {
    String raw;
    try {
      raw = await file.readAsString(encoding: utf8);
    } catch (_) {
      raw = await file.readAsString(encoding: latin1);
    }

    // Simple CSV → tab-separated conversion.
    // Handles quoted fields with embedded commas.
    final lines = raw.split(RegExp(r'\r?\n'));
    final buf = StringBuffer();

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final cells = _parseCsvRow(line);
      buf.writeln(cells.join('\t'));
    }

    return DocumentExtractionResult(
      fileName: fileName,
      filePath: file.path,
      extension: ext,
      extractedText: buf.toString().trim(),
      success: true,
    );
  }

  /// Minimal RFC-4180 CSV row parser.
  static List<String> _parseCsvRow(String row) {
    final cells = <String>[];
    final sb = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < row.length; i++) {
      final ch = row[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < row.length && row[i + 1] == '"') {
          sb.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        cells.add(sb.toString());
        sb.clear();
      } else {
        sb.write(ch);
      }
    }
    cells.add(sb.toString());
    return cells;
  }

  // ── .xlsx ───────────────────────────────────────────────────────────────────

  static Future<DocumentExtractionResult> _extractXlsx(
    File file,
    String fileName,
    String ext,
  ) async {
    final bytes = await file.readAsBytes();
    final excel = xl.Excel.decodeBytes(bytes);

    final buf = StringBuffer();

    for (final sheetName in excel.sheets.keys) {
      final sheet = excel.sheets[sheetName];
      if (sheet == null) continue;

      buf.writeln('--- Sheet: $sheetName ---');

      for (final row in sheet.rows) {
        final cells = row
            .map((cell) => cell?.value?.toString() ?? '')
            .toList();
        if (cells.any((c) => c.isNotEmpty)) {
          buf.writeln(cells.join('\t'));
        }
      }

      buf.writeln(); // blank line between sheets
    }

    final text = buf.toString().trim();

    return DocumentExtractionResult(
      fileName: fileName,
      filePath: file.path,
      extension: ext,
      extractedText: text,
      success: true,
      warningMessage: text.isEmpty
          ? '"$fileName" appears to contain no data. Please check the file.'
          : null,
    );
  }
}
