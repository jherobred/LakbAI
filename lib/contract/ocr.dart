import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// On-device text recognition (Google ML Kit). Images never leave the phone.
class OcrService {
  OcrService._();
  static final instance = OcrService._();

  TextRecognizer? _recognizer;

  Future<String> readImage(String path) async {
    _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    final result = await _recognizer!.processImage(InputImage.fromFilePath(path));
    // Keep line order so labelled clauses ("Salary: ...") stay on one line.
    final b = StringBuffer();
    for (final block in result.blocks) {
      for (final line in block.lines) {
        b.writeln(line.text);
      }
      b.writeln();
    }
    return b.toString();
  }

  Future<String> readPages(List<String> paths) async {
    final b = StringBuffer();
    for (final p in paths) {
      b.writeln(await readImage(p));
    }
    return b.toString();
  }

  void dispose() {
    _recognizer?.close();
    _recognizer = null;
  }
}
