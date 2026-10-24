import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/canonical_json.dart';
import '../../core/errors/setup_failure.dart';
import '../../core/setup_state.dart';
import '../../crypto/pin_service.dart';
import '../../crypto/setup_crypto.dart';
import '../../data/setup_repository.dart';
import '../../transport/sync_envelope.dart';
import 'domain/setup_models.dart';

export 'domain/setup_models.dart';

const consentVersion = 'PLACEHOLDER-1';

/// Owns all setup mutations. Widgets receive no database or private key
/// handles, and read typed models only: the signed maps stay inside this
/// class because their exact JSON is what the signatures cover.
class SetupService extends ChangeNotifier {
  SetupService(
    this.repository,
    this.secrets, {
    PinService? pin,
    this.purgeTransfers,
  }) : crypto = SetupCrypto(secrets),
       pin = pin ?? PinService(secrets);
  final SetupRepository repository;
  final SecretStore secrets;
  final SetupCrypto crypto;
  final PinService pin;
  final Future<void> Function()? purgeTransfers;
  Map<String, dynamic> _data = {};
  bool unlocked = false;
  bool _mutating = false;
  SetupState get state => SetupState(
    SetupStage.values.byName(_data['stage'] as String? ?? 'unset'),
  );
  String get locale => _data['locale'] as String? ?? 'en';
  String get id => _data['id'] as String? ?? '';

  /// This therapist phone's own profile, once signed up.
  TherapistProfile? get profile {
    final raw = _data['profile'] as Map?;
    if (raw == null) return null;
    return TherapistProfile(
      id: id,
      name: raw['name'] as String,
      clinic: raw['clinic'] as String,
    );
  }

  /// The therapist this patient phone joined.
  TherapistProfile? get therapist {
    final raw = _therapist;
    if (raw.isEmpty) return null;
    return TherapistProfile(
      id: raw['therapistId'] as String,
      name: raw['name'] as String,
      clinic: raw['clinic'] as String,
    );
  }

  List<SetupPatient> get patients => [
    for (final MapEntry(:key, :value) in _patients.entries)
      _patientFrom(key, Map<String, dynamic>.from(value as Map)),
  ];

  SetupPatient? patient(String participantId) {
    final raw = _patients[participantId] as Map?;
    return raw == null
        ? null
        : _patientFrom(participantId, Map<String, dynamic>.from(raw));
  }

  Map<ConsentItem, bool> get draftChecks {
    final raw = _data['checks'] as Map? ?? {};
    return {
      for (final item in ConsentItem.values) item: raw[item.name] == true,
    };
  }

  Map<String, dynamic> get _therapist =>
      Map<String, dynamic>.from(_data['therapist'] as Map? ?? {});
  Map<String, dynamic> get _patients =>
      Map<String, dynamic>.from(_data['patients'] as Map? ?? {});
  Map<String, dynamic>? get _signedConsent =>
      _data['consent'] as Map<String, dynamic>?;

  static SetupPatient _patientFrom(String id, Map<String, dynamic> raw) {
    final record = (raw['consent'] as Map)['record'] as Map<String, dynamic>;
    final checks = record['checks'] as Map<String, dynamic>;
    return SetupPatient(
      id: id,
      status: SetupPatientStatus.values.byName(raw['status'] as String),
      consent: ConsentSummary(
        version: record['consentVersion'] as String,
        signedAt: DateTime.parse(record['signedAt'] as String),
        locale: record['locale'] as String,
        checks: {
          for (final item in ConsentItem.values)
            item: checks[item.name] == true,
        },
        signaturePng: base64Decode(record['signaturePng'] as String),
      ),
      hasForms: raw['forms'] != null,
      hasPlan: raw['plan'] != null,
    );
  }

  static bool _requiredChecked(Map<String, dynamic> checks) => ConsentItem
      .values
      .where((item) => item.isRequired)
      .every((item) => checks[item.name] == true);
  List<int> get baselineDone =>
      List<int>.from(_data['baseline'] as List? ?? []);
  bool get biometrics => _data['biometrics'] == true;
  String get code => _data['code'] as String? ?? '';

  Future<void> load() async {
    if (await secrets.read('resetPending') == 'true') {
      await _finishReset();
      return;
    }
    _data = await repository.load();
    unlocked = false;
    notifyListeners();
  }

  Future<void> _change(Future<void> Function() action) async {
    if (_mutating) throw const SetupFailure(SetupFailureReason.busy);
    _mutating = true;
    final before = jsonEncode(_data);
    try {
      await action();
      await repository.save(_data);
      notifyListeners();
    } catch (_) {
      _data = jsonDecode(before) as Map<String, dynamic>;
      rethrow;
    } finally {
      _mutating = false;
    }
  }

  void _at(SetupStage expected) {
    if (state.stage != expected) {
      throw const SetupFailure(SetupFailureReason.wrongStep);
    }
  }

  void _next(SetupStage next) {
    _data['stage'] = state.advance(next).stage.name;
  }

  void _therapistAccess() {
    _at(SetupStage.ready);
    if (!unlocked) throw const SetupFailure(SetupFailureReason.locked);
  }

  Future<void> chooseRole(DeviceRole role) => _change(() async {
    _at(SetupStage.unset);
    _next(
      role == DeviceRole.patient
          ? SetupStage.needsJoin
          : SetupStage.needsSignup,
    );
  });
  Future<void> signup(String name, String clinic, String registration) =>
      _change(() async {
        _at(SetupStage.needsSignup);
        if ([
          name,
          clinic,
          registration,
        ].any((s) => s.trim().isEmpty || s.length > 200)) {
          throw const SetupFailure(SetupFailureReason.profileIncomplete);
        }
        _data.addAll({
          'id': const Uuid().v4(),
          'profile': {
            'name': name.trim(),
            'clinic': clinic.trim(),
            'registration': registration.trim(),
          },
          'code': (100000 + Random.secure().nextInt(900000)).toString(),
        });
        _next(SetupStage.needsPin);
      });
  Future<void> setPin(String value, String confirm, bool biometrics) =>
      _change(() async {
        _at(SetupStage.needsPin);
        if (value != confirm) {
          throw const SetupFailure(SetupFailureReason.pinMismatch);
        }
        await pin.set(value);
        _data['biometrics'] = biometrics;
        _next(SetupStage.needsKeys);
      });
  Future<void> generateKeys() => _change(() async {
    _at(SetupStage.needsKeys);
    _data['publicKeys'] = await crypto.generate(therapist: true);
    _next(SetupStage.ready);
    unlocked = true;
  });
  Future<Duration> remainingLockout() => pin.remaining();

  Future<bool> unlock(String value) async {
    if (state.role != DeviceRole.therapist) return false;
    unlocked = await pin.verify(value);
    notifyListeners();
    return unlocked;
  }

  Future<void> unlockBiometric(Future<bool> Function() authenticate) async {
    if (!biometrics || (await pin.remaining()) > Duration.zero) return;
    unlocked = await authenticate();
    notifyListeners();
  }

  void lock() {
    unlocked = false;
    notifyListeners();
  }

  Future<void> resetTherapist(String confirmation) async {
    if (state.role != DeviceRole.therapist || confirmation != 'DELETE') {
      throw const SetupFailure(SetupFailureReason.eraseConfirmation);
    }
    await secrets.write('resetPending', 'true');
    await _finishReset();
  }

  Future<void> _finishReset() async {
    await secrets.clear();
    await repository.wipe();
    _data = {'stage': SetupStage.needsSignup.name};
    unlocked = false;
    await repository.save(_data);
    await purgeTransfers?.call();
    await secrets.write('resetPending', 'false');
    notifyListeners();
  }

  SyncEnvelope joinEnvelope() {
    _therapistAccess();
    final keys = _data['publicKeys'] as Map<String, dynamic>;
    return SyncEnvelope(
      type: EnvelopeType.join,
      senderId: id,
      recipientId: '*',
      nonce: '',
      mac: '',
      ciphertext: base64Encode(
        utf8.encode(
          canonical({
            'v': 1,
            'therapistId': id,
            'name': profile!.name,
            'clinic': profile!.clinic,
            ...keys,
            'consentVersion': consentVersion,
          }),
        ),
      ),
    );
  }

  Future<void> join(SyncEnvelope envelope) => _change(() async {
    _at(SetupStage.needsJoin);
    if (envelope.type != EnvelopeType.join || envelope.recipientId != '*') {
      throw const SetupFailure(SetupFailureReason.notJoinPackage);
    }
    final p =
        jsonDecode(utf8.decode(base64Decode(envelope.ciphertext)))
            as Map<String, dynamic>;
    if (p['v'] != 1 ||
        p['therapistId'] != envelope.senderId ||
        p['consentVersion'] != consentVersion ||
        p['name'] is! String ||
        p['clinic'] is! String ||
        base64Decode(p['x25519Pub'] as String).length != 32 ||
        base64Decode(p['ed25519Pub'] as String).length != 32) {
      throw const SetupFailure(SetupFailureReason.unsupportedProfile);
    }
    _data.addAll({
      'id': const Uuid().v4(),
      'therapist': p,
      'publicKeys': await crypto.generate(therapist: false),
    });
    _next(SetupStage.language);
  });
  Future<void> selectLanguage(String value) => _change(() async {
    _at(SetupStage.language);
    if (!['en', 'hi', 'pa'].contains(value)) {
      throw const SetupFailure(SetupFailureReason.unsupportedLanguage);
    }
    _data['locale'] = value;
    _next(SetupStage.information);
  });
  Future<void> readInformation() => _change(() async {
    _at(SetupStage.information);
    _next(SetupStage.consent);
  });
  Future<void> saveChecks(Map<ConsentItem, bool> checks) => _change(() async {
    _at(SetupStage.consent);
    _data['checks'] = {
      for (final item in ConsentItem.values) item.name: checks[item] == true,
    };
  });
  Future<void> agree() => _change(() async {
    _at(SetupStage.consent);
    if (!_requiredChecked(
      Map<String, dynamic>.from(_data['checks'] as Map? ?? {}),
    )) {
      throw const SetupFailure(SetupFailureReason.consentIncomplete);
    }
    _next(SetupStage.signature);
  });
  Future<void> signConsent(List<int> png) => _change(() async {
    _at(SetupStage.signature);
    if (png.length < 8 ||
        png.length > 250000 ||
        !listEquals(png.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10])) {
      throw const SetupFailure(SetupFailureReason.signatureMissing);
    }
    final record = {
      'participantId': id,
      'therapistId': _therapist['therapistId'],
      'consentVersion': consentVersion,
      'signedAt': DateTime.now().toUtc().toIso8601String(),
      'locale': locale,
      'checks': {
        for (final MapEntry(:key, :value) in draftChecks.entries)
          key.name: value,
      },
      'signaturePng': base64Encode(png),
      'ed25519Pub': (_data['publicKeys'] as Map)['ed25519Pub'],
    };
    _data['consent'] = {
      'record': record,
      'signature': await crypto.sign(record),
    };
    _next(SetupStage.sendConsent);
  });
  Future<SyncEnvelope> consentEnvelope() async {
    if (![
      SetupStage.sendConsent,
      SetupStage.awaitingPlan,
    ].contains(state.stage)) {
      throw const SetupFailure(SetupFailureReason.consentNotReady);
    }
    return crypto.encrypt(
      type: EnvelopeType.consent,
      senderId: id,
      recipientId: _therapist['therapistId'] as String,
      publicKey: _therapist['x25519Pub'] as String,
      payload: _signedConsent!,
    );
  }

  Future<void> markConsentSent() => _change(() async {
    _at(SetupStage.sendConsent);
    _next(SetupStage.awaitingPlan);
  });
  Future<void> importConsent(SyncEnvelope envelope) => _change(() async {
    _therapistAccess();
    if (envelope.type != EnvelopeType.consent) {
      throw const SetupFailure(SetupFailureReason.notConsentPackage);
    }
    final signed = await crypto.decrypt(envelope, id);
    final record = signed['record'] as Map<String, dynamic>;
    final checks = record['checks'] as Map<String, dynamic>;
    if (record['therapistId'] != id ||
        record['participantId'] != envelope.senderId ||
        record['consentVersion'] != consentVersion ||
        DateTime.tryParse(record['signedAt'] as String) == null ||
        !_requiredChecked(checks) ||
        !await crypto.verify(
          record,
          signed['signature'] as String,
          record['ed25519Pub'] as String,
        )) {
      throw const SetupFailure(SetupFailureReason.consentInvalid);
    }
    final records = _patients;
    if (records.containsKey(envelope.senderId)) {
      final existing = records[envelope.senderId] as Map;
      if (canonical(existing['consent']) != canonical(signed)) {
        throw const SetupFailure(SetupFailureReason.consentConflict);
      }
      return; // Idempotent rescan must never undo approval or forms.
    }
    // Typed as dynamic so approve can add its fields to the same record.
    records[envelope.senderId] = <String, dynamic>{
      'consent': signed,
      'status': SetupPatientStatus.pending.name,
    };
    _data['patients'] = records;
  });
  Future<String> _consentHash(Object consent) async => base64Encode(
    (await Sha256().hash(utf8.encode(canonical(consent)))).bytes,
  );
  Future<void> approve(String participantId, bool paperCopy) =>
      _change(() async {
        _therapistAccess();
        if (!paperCopy) {
          throw const SetupFailure(SetupFailureReason.paperCopyRequired);
        }
        final patient = _patients[participantId] as Map<String, dynamic>?;
        if (patient == null ||
            patient['status'] != SetupPatientStatus.pending.name) {
          throw const SetupFailure(SetupFailureReason.noPendingConsent);
        }
        final approval = {
          'participantId': participantId,
          'therapistId': id,
          'consentVersion': consentVersion,
          'consentHash': await _consentHash(patient['consent'] as Object),
          'approvedAt': DateTime.now().toUtc().toIso8601String(),
          'paperCopy': true,
        };
        patient.addAll({
          'approval': approval,
          'countersignature': await crypto.sign(approval),
          'status': SetupPatientStatus.approved.name,
        });
        _data['patients'] = {..._patients, participantId: patient};
      });
  Future<void> saveForms(String participantId, ParticipantForms forms) =>
      _change(() async {
        _therapistAccess();
        final patient = _patients[participantId] as Map<String, dynamic>?;
        if (patient == null ||
            patient['approval'] == null ||
            patient['countersignature'] == null) {
          throw const SetupFailure(SetupFailureReason.approvalRequired);
        }
        final text = [forms.demographic, forms.clinical];
        if (forms.age < 18 ||
            forms.age > 120 ||
            text.any((v) => v.trim().isEmpty || v.length > 2000)) {
          throw const SetupFailure(SetupFailureReason.formsIncomplete);
        }
        patient['forms'] = {
          'age': '${forms.age}',
          'demographic': forms.demographic,
          'clinical': forms.clinical,
          'savedAt': DateTime.now().toUtc().toIso8601String(),
        };
        _data['patients'] = {..._patients, participantId: patient};
      });
  Future<void> prescribe(
    String participantId,
    List<String> exercises,
    int dose,
  ) => _change(() async {
    _therapistAccess();
    final patient = _patients[participantId] as Map<String, dynamic>?;
    if (patient == null ||
        patient['forms'] == null ||
        patient['approval'] == null) {
      throw const SetupFailure(SetupFailureReason.planPrerequisites);
    }
    if (exercises.toSet().length != 3 ||
        !exercises.every(mockExercises.contains) ||
        dose < 1 ||
        dose > 20) {
      throw const SetupFailure(SetupFailureReason.planChoice);
    }
    final plan = {
      'v': 1,
      'participantId': participantId,
      'therapistId': id,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'exercises': exercises,
      'dose': dose,
      'approval': patient['approval'],
      'countersignature': patient['countersignature'],
    };
    patient['plan'] = {'record': plan, 'signature': await crypto.sign(plan)};
    patient['status'] = SetupPatientStatus.planReady.name;
    _data['patients'] = {..._patients, participantId: patient};
  });
  SyncEnvelope planEnvelope(String participantId) {
    _therapistAccess();
    final plan = (_patients[participantId] as Map?)?['plan'];
    if (plan == null) throw const SetupFailure(SetupFailureReason.planMissing);
    return SyncEnvelope(
      type: EnvelopeType.plan,
      senderId: id,
      recipientId: participantId,
      nonce: '',
      ciphertext: base64Encode(utf8.encode(canonical(plan))),
      mac: '',
    );
  }

  Future<void> importPlan(SyncEnvelope envelope) => _change(() async {
    _at(SetupStage.awaitingPlan);
    if (envelope.type != EnvelopeType.plan ||
        envelope.recipientId != id ||
        envelope.senderId != _therapist['therapistId']) {
      throw const SetupFailure(SetupFailureReason.planWrongRecipient);
    }
    final signed =
        jsonDecode(utf8.decode(base64Decode(envelope.ciphertext)))
            as Map<String, dynamic>;
    final record = signed['record'] as Map<String, dynamic>;
    final approval = record['approval'] as Map<String, dynamic>;
    final public = _therapist['ed25519Pub'] as String;
    final exercises = List<String>.from(record['exercises'] as List);
    final dose = record['dose'] as int;
    if (record['v'] != 1 ||
        exercises.length != 3 ||
        exercises.toSet().length != 3 ||
        !exercises.every(mockExercises.contains) ||
        dose < 1 ||
        dose > 20 ||
        DateTime.tryParse(record['createdAt'] as String) == null ||
        DateTime.tryParse(approval['approvedAt'] as String) == null ||
        record['participantId'] != id ||
        record['therapistId'] != _therapist['therapistId'] ||
        approval['participantId'] != id ||
        approval['therapistId'] != _therapist['therapistId'] ||
        approval['consentVersion'] != consentVersion ||
        approval['paperCopy'] != true ||
        approval['consentHash'] != await _consentHash(_signedConsent!) ||
        !await crypto.verify(record, signed['signature'] as String, public) ||
        !await crypto.verify(
          approval,
          record['countersignature'] as String,
          public,
        )) {
      throw const SetupFailure(SetupFailureReason.planInvalid);
    }
    _data['plan'] = signed;
    _next(SetupStage.orientation);
  });
  Future<void> finishOrientation() => _change(() async {
    _at(SetupStage.orientation);
    _next(SetupStage.baseline);
  });
  Future<void> completeBaseline(int task) => _change(() async {
    _at(SetupStage.baseline);
    if (task < 0 || task > 2) {
      throw const SetupFailure(SetupFailureReason.baselineTask);
    }
    _data['baseline'] = {...baselineDone, task}.toList();
  });
  Future<void> finishBaseline() => _change(() async {
    _at(SetupStage.baseline);
    if (baselineDone.length != 3) {
      throw const SetupFailure(SetupFailureReason.baselineIncomplete);
    }
    _next(SetupStage.active);
  });
}

const mockExercises = [
  'Gentle humming',
  'Lip trills',
  'Breathing',
  'Easy onset',
  'Resonant voice',
];
