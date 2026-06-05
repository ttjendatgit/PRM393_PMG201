/// Multi-format document text extractor.
///
/// Supported formats: .txt, .md, .docx, .pdf (text-based), .csv, .xlsx
/// NOT supported: scanned/image PDFs, OCR.
library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:excel/excel.dart' as xl;
import 'package:flutter/foundation.dart';
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
  /// Always returns a [DocumentExtractionResult]. Check [result.success],
  /// [result.warningMessage], and [result.errorMessage] before using the text.
  static Future<DocumentExtractionResult> extractTextFromFile(
    String path,
  ) async {
    final file = File(path);
    final fileName = file.uri.pathSegments.last;
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';

    debugPrint('[Extractor] File: $path');
    debugPrint('[Extractor] Extension: "$ext"');

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
          debugPrint('[Extractor] Unsupported extension: "$ext"');
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
      debugPrint('[Extractor] Uncaught error for "$fileName": $e');
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
    debugPrint('[Extractor] Branch: plaintext ($ext)');
    String text;
    try {
      text = await file.readAsString(encoding: utf8);
    } catch (_) {
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
    debugPrint('[Extractor] Plaintext chars: ${text.length}');
    return DocumentExtractionResult(
      fileName: fileName,
      filePath: file.path,
      extension: ext,
      extractedText: text,
      success: true,
    );
  }

  // ── .docx ───────────────────────────────────────────────────────────────────
  //
  // Root cause of old empty-text bug:
  //   _collectRunText used findAllElements('t') which in xml 6.x matches by
  //   *qualified* name — so it looked for <t>, not <w:t> — returning nothing.
  //   Fix: traverse descendants and match by localName throughout.

  static Future<DocumentExtractionResult> _extractDocx(
    File file,
    String fileName,
    String ext,
  ) async {
    debugPrint('[Extractor] Branch: docx');

    final bytes = await file.readAsBytes();

    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      return DocumentExtractionResult.error(
        fileName: fileName,
        filePath: file.path,
        extension: ext,
        errorMessage:
            '"$fileName" does not appear to be a valid .docx file: $e',
      );
    }

    debugPrint('[Extractor] DOCX archive entries: ${archive.files.length}');

    final buffer = StringBuffer();
    final foundParts = <String>[];

    // Build list of XML parts to process, in reading order.
    final partsToProcess = <String>['word/document.xml'];
    for (final f in archive.files) {
      if (RegExp(r'^word/header\d*\.xml$').hasMatch(f.name)) {
        partsToProcess.add(f.name);
      } else if (RegExp(r'^word/footer\d*\.xml$').hasMatch(f.name)) {
        partsToProcess.add(f.name);
      }
    }
    if (archive.files.any((f) => f.name == 'word/footnotes.xml')) {
      partsToProcess.add('word/footnotes.xml');
    }
    if (archive.files.any((f) => f.name == 'word/endnotes.xml')) {
      partsToProcess.add('word/endnotes.xml');
    }

    debugPrint('[Extractor] DOCX parts to process: $partsToProcess');

    for (final partName in partsToProcess) {
      final entry = archive.files
          .where((f) => f.name == partName)
          .firstOrNull;

      if (entry == null) {
        debugPrint('[Extractor] DOCX part not found: $partName');
        continue;
      }

      foundParts.add(partName);
      try {
        final xmlString = utf8.decode(entry.content as List<int>);
        final doc = xmllib.XmlDocument.parse(xmlString);
        _docxExtractFromRoot(doc.rootElement, buffer);
      } catch (e) {
        debugPrint('[Extractor] Failed to parse DOCX part "$partName": $e');
        // Continue to next part — don't abort on one bad part.
      }
    }

    debugPrint('[Extractor] DOCX parts found: $foundParts');

    final text = buffer.toString().trim();
    debugPrint('[Extractor] DOCX extracted chars: ${text.length}');

    if (text.isEmpty) {
      debugPrint(
        '[Extractor] DOCX zero chars — possible causes: '
        'image-only content, protected document, '
        'unsupported content structure, or parts list: $foundParts',
      );
      return DocumentExtractionResult(
        fileName: fileName,
        filePath: file.path,
        extension: ext,
        extractedText: '',
        success: true,
        warningMessage:
            'Could not extract text from this DOCX. The file may contain '
            'unsupported objects, images, or protected content. '
            'Please try saving it as a standard Word .docx or paste the text manually.',
      );
    }

    return DocumentExtractionResult(
      fileName: fileName,
      filePath: file.path,
      extension: ext,
      extractedText: text,
      success: true,
    );
  }

  // ── DOCX XML helpers ────────────────────────────────────────────────────────

  /// Entry point for one XML part: find the content container then walk it.
  ///
  /// document.xml → w:body; header/footer → w:hdr/w:ftr;
  /// footnotes/endnotes → w:footnotes/w:endnotes; fallback → root itself.
  static void _docxExtractFromRoot(
    xmllib.XmlElement root,
    StringBuffer buf,
  ) {
    const containerLocalNames = {
      'body', 'hdr', 'ftr', 'footnotes', 'endnotes',
    };
    final container = root.descendants
        .whereType<xmllib.XmlElement>()
        .where((e) => containerLocalNames.contains(e.localName))
        .firstOrNull ?? root;

    _walkDocxElement(container, buf);
  }

  /// Walk any DOCX XML node, dispatching on localName.
  static void _walkDocxElement(xmllib.XmlNode node, StringBuffer buf) {
    for (final child in node.children) {
      if (child is! xmllib.XmlElement) continue;
      final local = child.localName;

      switch (local) {
        case 'p':
          // Paragraph — collect w:t runs in document order, then newline.
          final text = _collectDocxParagraphText(child);
          buf.writeln(text);

        case 'tbl':
          _walkDocxTable(child, buf);

        case 'sdt':
          // Structured document tag (content control) — descend into sdtContent.
          final content = child.children
              .whereType<xmllib.XmlElement>()
              .where((e) => e.localName == 'sdtContent')
              .firstOrNull;
          if (content != null) _walkDocxElement(content, buf);

        case 'footnote':
        case 'endnote':
          // Skip separator/continuation stubs (id <= 0).
          final idAttr = child.attributes
              .where((a) => a.localName == 'id')
              .firstOrNull;
          final id = int.tryParse(idAttr?.value ?? '') ?? -1;
          if (id > 0) _walkDocxElement(child, buf);

        default:
          // Recurse into unknown containers (e.g. w:txbxContent, w:ins, etc.)
          _walkDocxElement(child, buf);
      }
    }
  }

  /// Collect all text from a single paragraph element.
  ///
  /// Iterates ALL descendants by localName — avoids the xml-6.x bug where
  /// findAllElements('t') matches by qualified name and misses w:t elements.
  static String _collectDocxParagraphText(xmllib.XmlElement para) {
    final sb = StringBuffer();
    for (final el in para.descendants.whereType<xmllib.XmlElement>()) {
      switch (el.localName) {
        case 't':
          sb.write(el.innerText);
        case 'br':
          sb.write('\n');
        case 'tab':
          sb.write('\t');
      }
    }
    return sb.toString();
  }

  /// Extract table rows as tab-separated cells.
  static void _walkDocxTable(xmllib.XmlElement table, StringBuffer buf) {
    for (final child in table.children.whereType<xmllib.XmlElement>()) {
      switch (child.localName) {
        case 'tr':
          _walkDocxTableRow(child, buf);
        case 'sdt':
          final content = child.children
              .whereType<xmllib.XmlElement>()
              .where((e) => e.localName == 'sdtContent')
              .firstOrNull;
          if (content != null) _walkDocxTable(content, buf);
        default:
          break; // skip tblPr, tblGrid, etc.
      }
    }
  }

  static void _walkDocxTableRow(xmllib.XmlElement row, StringBuffer buf) {
    final cells = <String>[];

    for (final child in row.children.whereType<xmllib.XmlElement>()) {
      switch (child.localName) {
        case 'tc':
          final cellBuf = StringBuffer();
          _walkDocxElement(child, cellBuf);
          cells.add(cellBuf.toString().trim());

        case 'sdt':
          // SDT wrapping a table cell.
          final content = child.children
              .whereType<xmllib.XmlElement>()
              .where((e) => e.localName == 'sdtContent')
              .firstOrNull;
          if (content != null) {
            final tc = content.children
                .whereType<xmllib.XmlElement>()
                .where((e) => e.localName == 'tc')
                .firstOrNull;
            if (tc != null) {
              final cellBuf = StringBuffer();
              _walkDocxElement(tc, cellBuf);
              cells.add(cellBuf.toString().trim());
            }
          }

        default:
          break; // skip trPr, bookmarkStart, etc.
      }
    }

    if (cells.any((c) => c.isNotEmpty)) {
      buf.writeln(cells.join('\t'));
    }
  }

  // ── .pdf ────────────────────────────────────────────────────────────────────

  static Future<DocumentExtractionResult> _extractPdf(
    File file,
    String fileName,
    String ext,
  ) async {
    debugPrint('[Extractor] Branch: pdf');
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
    debugPrint('[Extractor] PDF extracted chars: ${trimmed.length}');

    if (trimmed.isEmpty) {
      debugPrint('[Extractor] PDF zero chars — likely scanned/image-based');
      return DocumentExtractionResult(
        fileName: fileName,
        filePath: file.path,
        extension: ext,
        extractedText: '',
        success: true,
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
    debugPrint('[Extractor] Branch: csv');
    String raw;
    try {
      raw = await file.readAsString(encoding: utf8);
    } catch (_) {
      raw = await file.readAsString(encoding: latin1);
    }

    final lines = raw.split(RegExp(r'\r?\n'));
    final buf = StringBuffer();

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final cells = _parseCsvRow(line);
      buf.writeln(cells.join('\t'));
    }

    final text = buf.toString().trim();
    debugPrint('[Extractor] CSV extracted chars: ${text.length}');

    return DocumentExtractionResult(
      fileName: fileName,
      filePath: file.path,
      extension: ext,
      extractedText: text,
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
    debugPrint('[Extractor] Branch: xlsx');
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

      buf.writeln();
    }

    final text = buf.toString().trim();
    debugPrint('[Extractor] XLSX extracted chars: ${text.length}');

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
