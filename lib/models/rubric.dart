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
}
