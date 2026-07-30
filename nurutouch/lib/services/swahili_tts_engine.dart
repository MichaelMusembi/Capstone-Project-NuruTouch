import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:path_provider/path_provider.dart';

/// Piper TTS Engine for Swahili
/// Model: sw_fine-tuned-medium (Piper v1.0 format, 22050 Hz)
///
/// Piper ONNX inputs:
///   - input:          int64[1, seq_len]  — phoneme IDs
///   - input_lengths:  int64[1]           — sequence length
///   - scales:         float32[3]         — [noise_scale, length_scale, noise_w]
///
/// Piper ONNX output:
///   - output:         float32[1, 1, samples] — raw audio waveform
class SwahiliTTSEngine {
  late OnnxRuntime _ort;
  late OrtSession _session;

  // Character to ID map from vocab.json
  Map<String, dynamic> _vocabMap = {};

  // Sample rate from model config (16000 Hz for this VITS model)
  final int _sampleRate = 16000;

  // Pad token ID for add_blank (vocab["2"] = 0)
  static const int _padId = 0;

  // 1. INITIALIZE THE ENGINE
  Future<void> init() async {
    print('⚙️ Initializing Swahili TTS Engine (VITS)...');

    // Load the vocab.json
    final vocabString = await rootBundle.loadString('assets/salama_assets/vocab.json');
    _vocabMap = json.decode(vocabString);

    // Boot up the ONNX Runtime with multi-threading
    _ort = OnnxRuntime();
    final options = OrtSessionOptions(intraOpNumThreads: 4, interOpNumThreads: 2);
    _session = await _ort.createSessionFromAsset(
      'assets/salama_assets/swahili_tts.onnx',
      options: options,
    );

    print('✅ VITS Engine Ready! Sample rate: $_sampleRate Hz');
  }

  String _normalizeText(String text) {
    text = text.toLowerCase();
    
    // Replace numbers with Swahili words (basic 0-9)
    const numbers = {
      '1': 'moja', '2': 'mbili', '3': 'tatu', '4': 'nne', '5': 'tano',
      '6': 'sita', '7': 'saba', '8': 'nane', '9': 'tisa', '0': 'sifuri'
    };
    numbers.forEach((key, value) {
      text = text.replaceAll(key, value);
    });

    // Phonetic mapping for standalone Swahili consonants and digraphs.
    // Order matters: Digraphs must come before single letters.
    final phonetics = {
      'ch': 'cha', 'dh': 'dha', 'gh': 'gha', 'ny': 'nya', "ng'": "ng'a",
      'b': 'ba', 'c': 'se', 'd': 'da', 'f': 'fa', 'g': 'ga', 'h': 'ha',
      'j': 'ja', 'k': 'ka', 'l': 'la', 'm': 'ma', 'n': 'na', 'p': 'pa',
      'q': 'kyu', 'r': 'ra', 's': 'sa', 't': 'ta', 'v': 'va', 'w': 'wa',
      'x': 'eksi', 'y': 'ya', 'z': 'za'
    };

    phonetics.forEach((key, value) {
      // Use lookaround to only replace standalone occurrences (not within words).
      // (?<=^|[^a-z]) ensures preceding char is not a letter.
      // (?=$|[^a-z]) ensures succeeding char is not a letter.
      text = text.replaceAllMapped(
        RegExp('(?<=^|[^a-z])' + RegExp.escape(key) + r'(?=$|[^a-z])'),
        (match) => value,
      );
    });

    // Replace smart quotes and scrub unsupported punctuation
    text = text.replaceAll(RegExp(r'[“”]'), '"');
    text = text.replaceAll(RegExp(r'[‘’]'), "'");
    text = text.replaceAll(RegExp(r'[–—]'), '-');
    text = text.replaceAll(RegExp(r'[\(\)\[\]\{\}]'), ' ');

    return text.trim();
  }

  // 2. THE TOKENIZER
  // Converts text → IDs using vocab.json
  // add_blank=true means interleaved padding token (ID 0)
  List<int> _tokenize(String text) {
    text = _normalizeText(text);
    if (text.isEmpty) return [];

    int? getId(String char) {
      if (!_vocabMap.containsKey(char)) return null;
      return _vocabMap[char] as int;
    }

    final List<int> ids = [];

    // Interleave padding token
    ids.add(_padId);
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final id = getId(char);
      if (id != null) {
        ids.add(id);
        ids.add(_padId);
      }
    }

    // Add trailing spaces to prevent audio clipping at the end
    ids.addAll([34, _padId, 34, _padId]);

    return ids;
  }

  // 3. THE INFERENCE PIPELINE
  Future<String> synthesizeSpeech(String text) async {
    print('Processing text: $text');

    final inputIds = _tokenize(text);
    if (inputIds.isEmpty) throw Exception('Tokenization produced empty input');

    final seqLen = inputIds.length;

    // VITS expects a single input tensor:
    // input: int64[batch_size, sequence]

    final inputTensor = await OrtValue.fromList(
      Int64List.fromList(inputIds),
      [1, seqLen],
    );

    final inputs = {
      'input': inputTensor,
    };

    final runOptions = OrtRunOptions();
    final outputs = await _session.run(inputs, options: runOptions);

    // VITS output key is 'output', shape [batch_size, sequence]
    // which effectively contains the raw waveform samples.
    final waveformOrt = outputs['output']!;
    final List<dynamic> rawList = await waveformOrt.asFlattenedList();
    final List<double> audioData = rawList.map((e) => (e as num).toDouble()).toList();

    // Cleanup
    await inputTensor.dispose();
    for (final v in outputs.values) {
      await v.dispose();
    }

    return await _saveToWav(audioData);
  }

  // 4. WAV BUILDER (PCM 16-bit)
  Future<String> _saveToWav(List<double> audioData) async {
    const int channels = 1;
    const int bitsPerSample = 16;
    final int byteRate = _sampleRate * channels * (bitsPerSample ~/ 8);
    final int totalAudioLen = audioData.length * (bitsPerSample ~/ 8);

    final byteData = ByteData(44 + totalAudioLen);

    // RIFF header
    byteData.setUint8(0, 82);  // R
    byteData.setUint8(1, 73);  // I
    byteData.setUint8(2, 70);  // F
    byteData.setUint8(3, 70);  // F
    byteData.setUint32(4, 36 + totalAudioLen, Endian.little);
    byteData.setUint8(8, 87);  // W
    byteData.setUint8(9, 65);  // A
    byteData.setUint8(10, 86); // V
    byteData.setUint8(11, 69); // E

    // fmt chunk
    byteData.setUint8(12, 102); byteData.setUint8(13, 109);
    byteData.setUint8(14, 116); byteData.setUint8(15, 32);
    byteData.setUint32(16, 16, Endian.little);
    byteData.setUint16(20, 1, Endian.little);                         // PCM
    byteData.setUint16(22, channels, Endian.little);
    byteData.setUint32(24, _sampleRate, Endian.little);
    byteData.setUint32(28, byteRate, Endian.little);
    byteData.setUint16(32, channels * (bitsPerSample ~/ 8), Endian.little);
    byteData.setUint16(34, bitsPerSample, Endian.little);

    // data chunk
    byteData.setUint8(36, 100); byteData.setUint8(37, 97);
    byteData.setUint8(38, 116); byteData.setUint8(39, 97);
    byteData.setUint32(40, totalAudioLen, Endian.little);

    int offset = 44;
    for (final sample in audioData) {
      int intVal = (sample.clamp(-1.0, 1.0) * 32767).toInt();
      byteData.setInt16(offset, intVal, Endian.little);
      offset += 2;
    }

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '${directory.path}/swahili_vits_$timestamp.wav';
    await File(path).writeAsBytes(byteData.buffer.asUint8List());

    print('Audio saved to: $path');
    return path;
  }
}
