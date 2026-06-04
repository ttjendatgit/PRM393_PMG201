// SAMPLE DATA ONLY — PMG201c Practical Exam 2
//
// This file is a default demo rubric to bootstrap the grading workflow.
// It is NOT the app's fixed grading logic. For other courses or exams,
// create a new assessment via the Assessment Setup screen.

import '../models/assessment.dart';
import '../models/rubric.dart';

Assessment buildPmg201cPe2SampleAssessment() => Assessment(
      assessmentId: 'pmg201c-pe2-sample',
      courseCode: 'PMG201c',
      assessmentTitle: 'Practical Exam 2',
      examQuestionText: _examQuestionText,
      gradingGuideText: _gradingGuideText,
      totalRawScore: 100,
      totalConvertedScore: 10,
      createdAt: DateTime(2026, 6, 1),
      questions: const [
        QuestionRubric(
          questionId: 'q1',
          title: 'Project Charter Statement',
          rawMaxScore: 20,
          convertedMaxScore: 2,
          description:
              'Evaluate the ability to define a project charter with clear objectives, scope, and stakeholder identification.',
          subCriteria: [
            SubCriterion(
              code: 'Q1.1',
              title: 'Project Objectives',
              maxScore: 10,
              fullMarkDescription:
                  'Clear, measurable SMART objectives fully defined with success metrics',
              partialMarkDescription:
                  'Objectives present but lack specificity or measurability',
              lowMarkDescription: 'Vague or missing objectives',
              commonMistakes: [
                'Objectives not SMART',
                'Too broad',
                'No success metrics',
              ],
            ),
            SubCriterion(
              code: 'Q1.2',
              title: 'Scope & Stakeholders',
              maxScore: 10,
              fullMarkDescription:
                  'Scope clearly defined with in/out boundaries and all stakeholders identified',
              partialMarkDescription:
                  'Scope partially defined; some stakeholders missing',
              lowMarkDescription: 'Scope missing or unclear; no stakeholder list',
              commonMistakes: [
                'No exclusions listed',
                'Scope creep not addressed',
                'Key stakeholders omitted',
              ],
            ),
          ],
        ),
        QuestionRubric(
          questionId: 'q2',
          title: 'Cost / Budget Plan',
          rawMaxScore: 20,
          convertedMaxScore: 2,
          description:
              'Assess completeness and accuracy of cost estimation and budget allocation across project phases.',
          subCriteria: [
            SubCriterion(
              code: 'Q2.1',
              title: 'Cost Estimation',
              maxScore: 10,
              fullMarkDescription:
                  'Detailed cost breakdown with justified estimates for all categories',
              partialMarkDescription:
                  'Cost breakdown present but missing justifications or categories',
              lowMarkDescription: 'Minimal or no cost detail',
              commonMistakes: [
                'No contingency budget',
                'Missing labor cost',
                'Unjustified estimates',
              ],
            ),
            SubCriterion(
              code: 'Q2.2',
              title: 'Budget Allocation',
              maxScore: 10,
              fullMarkDescription:
                  'Budget allocated by phase/deliverable with totals matching',
              partialMarkDescription:
                  'Allocation partially defined; some phases missing',
              lowMarkDescription: 'No phased allocation',
              commonMistakes: [
                'Phase budgets do not add up to total',
                'Missing phases',
              ],
            ),
          ],
        ),
        QuestionRubric(
          questionId: 'q3',
          title: 'Risk Register',
          rawMaxScore: 30,
          convertedMaxScore: 3,
          description:
              'Evaluate risk identification, probability/impact assessment, and mitigation strategies.',
          subCriteria: [
            SubCriterion(
              code: 'Q3.1',
              title: 'Risk Identification',
              maxScore: 10,
              fullMarkDescription:
                  'At least 5 relevant risks identified across multiple categories',
              partialMarkDescription: '3–4 risks identified; some categories missed',
              lowMarkDescription: 'Fewer than 3 risks or irrelevant risks listed',
              commonMistakes: [
                'Only generic risks listed',
                'No technical risks included',
              ],
            ),
            SubCriterion(
              code: 'Q3.2',
              title: 'Probability & Impact',
              maxScore: 10,
              fullMarkDescription:
                  'P×I matrix completed with justified ratings for all risks',
              partialMarkDescription:
                  'Ratings present but inconsistently justified',
              lowMarkDescription: 'No P×I assessment',
              commonMistakes: [
                'All risks rated the same',
                'No justification for ratings',
              ],
            ),
            SubCriterion(
              code: 'Q3.3',
              title: 'Mitigation Strategies',
              maxScore: 10,
              fullMarkDescription:
                  'Actionable mitigation for each risk with owners assigned',
              partialMarkDescription:
                  'Mitigation present but generic or owner missing',
              lowMarkDescription: 'No mitigation strategies',
              commonMistakes: [
                'Mitigation too vague',
                'No risk owner assigned',
              ],
            ),
          ],
        ),
        QuestionRubric(
          questionId: 'q4',
          title: 'RACI Matrix',
          rawMaxScore: 30,
          convertedMaxScore: 3,
          description:
              'Assess completeness of the RACI matrix covering key deliverables and all stakeholder roles.',
          subCriteria: [
            SubCriterion(
              code: 'Q4.1',
              title: 'Role Coverage',
              maxScore: 15,
              fullMarkDescription:
                  'All relevant stakeholder roles included with clear titles',
              partialMarkDescription: 'Most roles covered; 1–2 missing',
              lowMarkDescription: 'Key roles missing or roles not relevant',
              commonMistakes: [
                'Missing sponsor or PM role',
                'Too few roles to be meaningful',
              ],
            ),
            SubCriterion(
              code: 'Q4.2',
              title: 'Task Assignment',
              maxScore: 15,
              fullMarkDescription:
                  'All deliverables covered with correct R/A/C/I assignments',
              partialMarkDescription:
                  'Most tasks covered; some assignments questionable',
              lowMarkDescription: 'Few tasks or incorrect R/A/C/I usage',
              commonMistakes: [
                'Multiple Accountable per task',
                'Responsible missing',
                'Incomplete task list',
              ],
            ),
          ],
        ),
      ],
    );

const _examQuestionText = '''PMG201c — Practical Exam 2

Q1 — Project Charter Statement (20 marks)
Prepare a project charter for the given scenario. Your charter must include:
  • Project objectives (must be SMART)
  • Project scope (clearly state in-scope and out-of-scope items)
  • Key stakeholders and their roles

Q2 — Cost / Budget Plan (20 marks)
Create a cost and budget plan for the project. Include:
  • Itemised cost breakdown by category (labour, equipment, software, etc.)
  • Phase-by-phase budget allocation
  • Contingency reserve with justification

Q3 — Risk Register (30 marks)
Develop a risk register with at least 5 risks. For each risk:
  • Identify and describe the risk clearly
  • Assess probability and impact using a 1–5 scale
  • Propose a concrete mitigation strategy and assign a risk owner

Q4 — RACI Matrix (30 marks)
Build a RACI matrix for the project. Include:
  • At least 5 key deliverables or tasks as rows
  • All major stakeholder roles as columns
  • Correct Responsible / Accountable / Consulted / Informed assignments
''';

const _gradingGuideText = '''PMG201c PE2 — Grading Guide

Total: 100 raw marks → converted to /10

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Q1 — Project Charter Statement: 20 raw → 2 converted points

  Q1.1 Project Objectives (/10)
    Full  (9–10): SMART objectives with clear metrics
    Part  (5–8):  Objectives present, not fully SMART
    Low   (0–4):  Vague or missing objectives

  Q1.2 Scope & Stakeholders (/10)
    Full  (9–10): In/out scope defined, all stakeholders listed
    Part  (5–8):  Partial scope or missing stakeholders
    Low   (0–4):  No scope definition or stakeholder list

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Q2 — Cost / Budget Plan: 20 raw → 2 converted points

  Q2.1 Cost Estimation (/10)
    Full  (9–10): Detailed breakdown, all categories justified
    Part  (5–8):  Breakdown present, incomplete justification
    Low   (0–4):  Minimal or no cost detail

  Q2.2 Budget Allocation (/10)
    Full  (9–10): Phase allocation, totals match
    Part  (5–8):  Partial allocation
    Low   (0–4):  No phased allocation

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Q3 — Risk Register: 30 raw → 3 converted points

  Q3.1 Risk Identification (/10)
  Q3.2 Probability & Impact (/10)
  Q3.3 Mitigation Strategies (/10)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Q4 — RACI Matrix: 30 raw → 3 converted points

  Q4.1 Role Coverage (/15)
  Q4.2 Task Assignment (/15)
''';
