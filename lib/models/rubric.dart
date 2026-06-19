class SubCriterion {
  final String code;
  final String title;
  final double maxScore;
  final String fullMarkDescription;
  final String partialMarkDescription;
  final String lowMarkDescription;
  final List<String> commonMistakes;

  const SubCriterion({
    required this.code,
    required this.title,
    required this.maxScore,
    required this.fullMarkDescription,
    required this.partialMarkDescription,
    required this.lowMarkDescription,
    this.commonMistakes = const [],
  });

  factory SubCriterion.fromJson(Map<String, dynamic> json) {
    return SubCriterion(
      code: json['code'] as String? ?? '',
      title: json['title'] as String? ?? '',
      maxScore: (json['maxScore'] as num?)?.toDouble() ?? 0,
      fullMarkDescription: json['fullMarkDescription'] as String? ?? '',
      partialMarkDescription: json['partialMarkDescription'] as String? ?? '',
      lowMarkDescription: json['lowMarkDescription'] as String? ?? '',
      commonMistakes: (json['commonMistakes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class QuestionRubric {
  final String questionId;
  final String title;
  final double rawMaxScore;
  final double convertedMaxScore;
  final String description;
  final List<SubCriterion> subCriteria;

  const QuestionRubric({
    required this.questionId,
    required this.title,
    required this.rawMaxScore,
    required this.convertedMaxScore,
    required this.description,
    this.subCriteria = const [],
  });

  /// Creates from the BE [RubricItemResponse] JSON shape:
  /// { id, assessmentId, questionNo, title, description,
  ///   maxRawScore, maxConvertedScore, orderIndex, ... }
  factory QuestionRubric.fromJson(Map<String, dynamic> json) {
    // If subCriteria are nested inline, parse them
    List<SubCriterion> subs = [];
    if (json['subCriteria'] != null) {
      subs = (json['subCriteria'] as List<dynamic>)
          .map((e) => SubCriterion.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return QuestionRubric(
      questionId:
          (json['id'] ?? json['questionNo'] ?? '').toString(),
      title: json['title'] as String? ?? '',
      rawMaxScore: (json['maxRawScore'] as num?)?.toDouble() ??
          (json['rawMaxScore'] as num?)?.toDouble() ?? 0,
      convertedMaxScore:
          (json['maxConvertedScore'] as num?)?.toDouble() ??
              (json['convertedMaxScore'] as num?)?.toDouble() ?? 0,
      description: json['description'] as String? ?? '',
      subCriteria: subs,
    );
  }
}
