enum SetupStage {
  unset,
  needsJoin,
  language,
  information,
  consent,
  signature,
  sendConsent,
  awaitingPlan,
  orientation,
  baseline,
  active,
  needsSignup,
  needsPin,
  needsKeys,
  ready,
}

enum DeviceRole { patient, therapist }

class SetupState {
  const SetupState(this.stage);
  final SetupStage stage;
  DeviceRole? get role => stage == SetupStage.unset
      ? null
      : stage.index >= SetupStage.needsSignup.index
      ? DeviceRole.therapist
      : DeviceRole.patient;
  String route({required bool unlocked}) =>
      stage == SetupStage.ready && !unlocked ? '/unlock' : '/${stage.name}';

  SetupState advance(SetupStage next) {
    final allowed = stage == SetupStage.unset
        ? [SetupStage.needsJoin, SetupStage.needsSignup]
        : stage == SetupStage.active || stage == SetupStage.ready
        ? <SetupStage>[]
        : [SetupStage.values[stage.index + 1]];
    if (!allowed.contains(next)) throw StateError('Invalid setup transition');
    return SetupState(next);
  }
}
