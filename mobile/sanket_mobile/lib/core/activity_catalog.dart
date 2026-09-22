import 'measurement.dart';
import 'prototype_parameters.dart';

/// Evidence level for each construct, as stated in the submission's §7 table.
enum EvidenceLevel { evidenceBacked, emerging, promising, supportiveOnly }

/// How an activity's detected patterns may influence the next-step state.
///
/// Derived from [EvidenceLevel] so the influence of each activity is traceable
/// to the specification rather than chosen per case.
enum InterpretationRole {
  /// Evidence-backed constructs: patterns count toward Monitor / Discuss.
  escalating,

  /// Emerging constructs: a pattern can raise the state to Monitor at most.
  monitorOnly,

  /// Promising / supportive-only: reported descriptively, never escalates.
  descriptive,
}

enum ActivityId {
  socialStory,
  nameResponse,
  followMyLook,
  bubbleTrail,
  copyMe,
  switchIt
}

class ActivityDefinition {
  const ActivityDefinition({
    required this.id,
    required this.evidence,
    required this.modalities,
    this.minAgeMonths = 0,
  });
  final ActivityId id;
  final EvidenceLevel evidence;

  /// Modalities the activity measures with (spec §7 "Signals").
  final List<Modality> modalities;
  final int minAgeMonths;

  InterpretationRole get role => switch (evidence) {
        EvidenceLevel.evidenceBacked => InterpretationRole.escalating,
        EvidenceLevel.emerging => InterpretationRole.monitorOnly,
        EvidenceLevel.promising ||
        EvidenceLevel.supportiveOnly =>
          InterpretationRole.descriptive,
      };

  bool offeredFor(int ageMonths) => ageMonths >= minAgeMonths;
}

extension ActivityIdDefinition on ActivityId {
  ActivityDefinition get definition => activityCatalog[index];
}

/// Session order follows the submission's activity table.
const activityCatalog = <ActivityDefinition>[
  ActivityDefinition(
      id: ActivityId.socialStory,
      evidence: EvidenceLevel.evidenceBacked,
      modalities: [Modality.camera, Modality.face, Modality.gaze]),
  ActivityDefinition(
      id: ActivityId.nameResponse,
      evidence: EvidenceLevel.evidenceBacked,
      modalities: [Modality.camera, Modality.face, Modality.audio]),
  ActivityDefinition(
      // Spec: "Evidence-backed / emerging camera measurement".
      id: ActivityId.followMyLook,
      evidence: EvidenceLevel.evidenceBacked,
      modalities: [
        Modality.camera,
        Modality.face,
        Modality.gaze,
        Modality.touch
      ]),
  ActivityDefinition(
      id: ActivityId.bubbleTrail,
      evidence: EvidenceLevel.promising,
      modalities: [Modality.touch]),
  ActivityDefinition(
      id: ActivityId.copyMe,
      evidence: EvidenceLevel.emerging,
      modalities: [Modality.camera, Modality.pose]),
  ActivityDefinition(
      id: ActivityId.switchIt,
      evidence: EvidenceLevel.supportiveOnly,
      modalities: [Modality.touch],
      minAgeMonths: PrototypeParameters.switchMinAgeMonths),
];
