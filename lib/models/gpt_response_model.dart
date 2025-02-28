import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GPTResponse {
  final apiKey = '';  // 여기에 GPT API 키를 입력하세요
  final url = Uri.parse("");


// 실제 GPT 응답을 받는 메서드
  Future<String> fetchGPTCommentResponse(String content) async {
    String systemRole = '''
당신은 사용자가 제공한 텍스트를 기반으로 REBT(합리적 정서행동치료) 접근법을 활용하여 
공감과 현실적인 사고를 유도하는 피드백을 작성하는 역할입니다. 
피드백은 다음 원칙에 따라 작성됩니다:

1. 감정을 촉발한 사건을 언급하여 사용자의 감정에 공감합니다.
2. 사용자의 신념을 이해하고 반영하되, 그것이 지나치게 비합리적이지 않다는 점을 수용합니다.
3. 그 신념이 불필요한 부정적인 결과를 초래할 가능성을 부드럽게 지적합니다.
4. 더 현실적이고 균형 잡힌 시각으로 상황을 바라볼 수 있도록 제안합니다.
5. 새로운 시각으로 긍정적인 변화를 격려합니다.

[출력 조건]
- 문장은 3문장을 초과하지 않습니다.
- 피드백에서 '일기 내용', '댓글', 'REBT' 단어는 사용하지 않습니다.
- 사용자를 지칭할 때, 복수형 대신 단수형을 사용합니다.
- 순서를 매기거나 'A', 'B', 'C' 등과 같은 표현은 사용하지 않습니다.
    ''';



    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4',
          'messages': [
            {
              'role': 'system',
              'content': systemRole,
            },
            {
              'role': 'user',
              'content': content,
            },
          ],
          'temperature': 1,
        }),
      );

      if (response.statusCode == 200) {
        var data = json.decode(utf8.decode(response.bodyBytes));
        var text = data['choices'][0]['message']['content'].trim();
        return text;
      } else {
        return "오류 발생! 해당 페이지 캡쳐 후 버그 레포트 부탁드립니다:\nError: ${response.statusCode} ${response.body}";
      }
    } catch (e) {
      return 'Exception: $e';
    }
  }

  // 시스템과 사용자 프롬프트 설정 및 GPT 응답 받기
  Future<String> fetchPromptResponse(String systemRole, String prompt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userPrompt', prompt);
    await prefs.setString('systemPrompt', systemRole);

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4-turbo',
          'messages': [
            {
              'role': 'system',
              'content': systemRole,
            },
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'temperature': 1,
        }),
      );

      if (response.statusCode == 200) {
        var data = json.decode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content']
            .trim()
            .replaceAll(RegExp(r'^"|"$'), '');
      } else {
        return "Failed to load data from OpenAI";
      }
    } catch (e) {
      return 'Exception: $e';
    }
  }
}
