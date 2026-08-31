import 'package:flutter_test/flutter_test.dart';
import 'package:application/services/encryption_service.dart';

void main() {
  test('Non-functional Cryptographic Benchmark Test (50 Iterations)', () {
    const int iterations = 50;
    const String testPayload =
        "Patient Health Record: Confidential Medical History, Prescriptions & Biomarkers Payload";
    const String testPassword = "passcode_fyp_123";
    const String testSalt = "patient_014172";

    // Pre-generate RSA key pair for rsaSign benchmarking
    final keyPair = EncryptionService.generateRSAKeyPair();
    final privateKey = keyPair.privateKey;
    final publicKey = keyPair.publicKey;

    // 1. Benchmark deriveKey
    final List<double> deriveKeyTimesMs = [];
    bool deriveKeyVerified = true;

    for (int i = 0; i < iterations; i++) {
      final sw = Stopwatch()..start();
      final key = EncryptionService.deriveKey(testPassword, testSalt);
      sw.stop();
      deriveKeyTimesMs.add(sw.elapsedMicroseconds / 1000.0);

      if (key.isEmpty) {
        deriveKeyVerified = false;
      }
    }

    // 2. Benchmark encrypt
    final List<double> encryptTimesMs = [];
    bool encryptVerified = true;

    for (int i = 0; i < iterations; i++) {
      final sw = Stopwatch()..start();
      final encrypted = EncryptionService.encrypt(testPayload);
      sw.stop();
      encryptTimesMs.add(sw.elapsedMicroseconds / 1000.0);

      final decrypted = EncryptionService.decrypt(encrypted);
      if (encrypted.isEmpty || decrypted != testPayload) {
        encryptVerified = false;
      }
    }

    // 3. Benchmark rsaSign
    final List<double> rsaSignTimesMs = [];
    bool rsaSignVerified = true;

    for (int i = 0; i < iterations; i++) {
      final sw = Stopwatch()..start();
      final signature = EncryptionService.rsaSign(testPayload, privateKey);
      sw.stop();
      rsaSignTimesMs.add(sw.elapsedMicroseconds / 1000.0);

      final isValid =
          EncryptionService.rsaVerify(testPayload, signature, publicKey);
      if (signature.isEmpty || !isValid) {
        rsaSignVerified = false;
      }
    }

    // Statistical calculations
    double mean(List<double> values) =>
        values.reduce((a, b) => a + b) / values.length;
    double min(List<double> values) =>
        values.reduce((a, b) => a < b ? a : b);
    double max(List<double> values) =>
        values.reduce((a, b) => a > b ? a : b);

    final deriveMean = mean(deriveKeyTimesMs);
    final deriveMin = min(deriveKeyTimesMs);
    final deriveMax = max(deriveKeyTimesMs);

    final encMean = mean(encryptTimesMs);
    final encMin = min(encryptTimesMs);
    final encMax = max(encryptTimesMs);

    final rsaMean = mean(rsaSignTimesMs);
    final rsaMin = min(rsaSignTimesMs);
    final rsaMax = max(rsaSignTimesMs);

    // Formatted ASCII Table Output
    const String lineSeparator =
        "+----------------------------------+---------------+---------------+---------------+----------------+";
    const String header =
        "| Operation                        | Mean (ms)     | Min (ms)      | Max (ms)      | Verification   |";

    // ignore: avoid_print
    print("\n$lineSeparator");
    // ignore: avoid_print
    print(
        "|                    NON-FUNCTIONAL BENCHMARK TEST RESULTS ($iterations ITERATIONS)                    |");
    // ignore: avoid_print
    print(lineSeparator);
    // ignore: avoid_print
    print(header);
    // ignore: avoid_print
    print(lineSeparator);
    // ignore: avoid_print
    print(
        "| EncryptionService.deriveKey()    | ${deriveMean.toStringAsFixed(3).padLeft(13)} | ${deriveMin.toStringAsFixed(3).padLeft(13)} | ${deriveMax.toStringAsFixed(3).padLeft(13)} | ${(deriveKeyVerified ? 'PASSED' : 'FAILED').padRight(14)} |");
    // ignore: avoid_print
    print(
        "| EncryptionService.encrypt()      | ${encMean.toStringAsFixed(3).padLeft(13)} | ${encMin.toStringAsFixed(3).padLeft(13)} | ${encMax.toStringAsFixed(3).padLeft(13)} | ${(encryptVerified ? 'PASSED' : 'FAILED').padRight(14)} |");
    // ignore: avoid_print
    print(
        "| EncryptionService.rsaSign()      | ${rsaMean.toStringAsFixed(3).padLeft(13)} | ${rsaMin.toStringAsFixed(3).padLeft(13)} | ${rsaMax.toStringAsFixed(3).padLeft(13)} | ${(rsaSignVerified ? 'PASSED' : 'FAILED').padRight(14)} |");
    // ignore: avoid_print
    print("$lineSeparator\n");

    // Assertions
    expect(deriveKeyVerified, isTrue,
        reason: 'deriveKey benchmark verification failed');
    expect(encryptVerified, isTrue,
        reason: 'encrypt benchmark verification failed');
    expect(rsaSignVerified, isTrue,
        reason: 'rsaSign benchmark verification failed');
  });
}
