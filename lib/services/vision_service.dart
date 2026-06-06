import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class VisionService {
  static const String _endpoint =
      'https://vision.googleapis.com/v1/images:annotate';

  Future<String> extractText(Uint8List imageBytes) async {
    if (visionApiKey.isEmpty) {
      throw Exception(
        'VISION_API_KEY is not set. Run with --dart-define=VISION_API_KEY=your_key',
      );
    }

    final base64Image = base64Encode(imageBytes);

    final response = await http.post(
      Uri.parse('$_endpoint?key=$visionApiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'requests': [
          {
            'image': {'content': base64Image},
            'features': [
              {'type': 'DOCUMENT_TEXT_DETECTION'},
            ],
          }
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Vision API error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final text = (data['responses'] as List?)
        ?.firstOrNull?['fullTextAnnotation']?['text'] as String?;

    if (text == null || text.trim().isEmpty) {
      throw Exception('No text found in image. Try a clearer photo.');
    }

    return text;
  }
}
