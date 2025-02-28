import 'package:flutter/material.dart';

class ResponseRatingWidget extends StatefulWidget {
  final Function(Map<String, int>) onRatingSubmitted; // 각 질문에 대한 점수 제출 함수
  final List<Map<String, dynamic>> questionsWithTypes; // 질문과 유형 리스트
  final String buttonLabel; // Button label ('다음' or '제출')

  ResponseRatingWidget({required this.onRatingSubmitted, required this.questionsWithTypes,  required this.buttonLabel, Key? key}) : super(key: key);

  @override
  _ResponseRatingWidgetState createState() => _ResponseRatingWidgetState();
}

class _ResponseRatingWidgetState extends State<ResponseRatingWidget> {
  Map<String, int?> _selectedRatings = {}; // 질문별 선택한 점수를 저장할 맵
  int _currentPage = 0; // 현재 페이지를 추적
  static const int _questionsPerPage = 10; // 페이지당 표시할 피드백 설문 수

  @override
  void initState() {
    super.initState();
    // 각 질문에 대해 초기값을 null로 설정
    for (var question in widget.questionsWithTypes) {
      _selectedRatings[question['question']] = null;
    }
  }

  List<Map<String, dynamic>> _getFeedbackQuestions() {
    return widget.questionsWithTypes
        .where((question) => question['type'] == 'feedback')
        .toList();
  }

  List<Map<String, dynamic>> _getEmotionQuestions() {
    return widget.questionsWithTypes
        .where((question) => question['type'] == 'emotion')
        .toList();
  }

  List<Map<String, dynamic>> _getQuestionsForCurrentPage() {
    final feedbackQuestions = _getFeedbackQuestions();
    final startIndex = _currentPage * _questionsPerPage;
    final endIndex = startIndex + _questionsPerPage;
    return feedbackQuestions.sublist(
      startIndex,
      endIndex > feedbackQuestions.length ? feedbackQuestions.length : endIndex,
    );
  }

  bool _isAllAnsweredForPage() {
    final currentQuestions = _getQuestionsForCurrentPage();
    return currentQuestions.every(
            (question) => _selectedRatings[question['question']] != null);
  }

  bool _isAllAnswered() {
    return widget.questionsWithTypes.every(
            (question) => _selectedRatings[question['question']] != null);
  }

  @override
  Widget build(BuildContext context) {
    final emotionQuestions = _getEmotionQuestions();
    final currentFeedbackQuestions = _getQuestionsForCurrentPage();
    final isLastPage = (_currentPage + 1) * _questionsPerPage >=
        _getFeedbackQuestions().length;

    final labelsForEmotion = ["매우 나쁨", "나쁨", "보통", "좋음", "매우 좋음"];
    final labelsForComment = ["매우 아니다", "아니다", "보통", "그렇다", "매우 그렇다"];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Color(0xffdfcdf3), width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 감정 설문
            for (var questionWithType in emotionQuestions) ...[
              Text(
                questionWithType['question'],
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                textAlign: TextAlign.left,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (index) {
                  int ratingValue = index + 1;
                  return Column(
                    children: [
                      Radio<int>(
                        value: ratingValue,
                        groupValue:
                        _selectedRatings[questionWithType['question']],
                        onChanged: (value) {
                          setState(() {
                            _selectedRatings[questionWithType['question']] =
                                value;
                            // 디버깅 로그 추가: 누른 값 출력
                            print("Question: ${questionWithType['question']}, Selected Value: $value");
                            // Emotion After Feedback 값 갱신
                            if (questionWithType['question'] == "피드백 확인 후 기분이 어떠신가요?") {
                              print("Updating Emotion After Feedback: $value");
                            }
                          });
                        },
                      ),
                      Text(
                        labelsForEmotion[index],
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ],
                  );
                }),
              ),
              const SizedBox(height: 40),
            ],

            // 피드백 설문
            for (var questionWithType in currentFeedbackQuestions) ...[
              Text(
                questionWithType['question'],
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                textAlign: TextAlign.left,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (index) {
                  int ratingValue = index + 1;
                  return Column(
                    children: [
                      Radio<int>(
                        value: ratingValue,
                        groupValue:
                        _selectedRatings[questionWithType['question']],
                        onChanged: (value) {
                          setState(() {
                            _selectedRatings[questionWithType['question']] =
                                value;
                          });
                        },
                      ),
                      Text(
                        labelsForComment[index],
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ],
                  );
                }),
              ),
              const SizedBox(height: 40),
            ],

            // 제출 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: _isAllAnswered()
                      ? () => widget.onRatingSubmitted(
                    _selectedRatings
                        .map((key, value) => MapEntry(key, value!)),
                  )
                      : null,
                  child: Text(widget.buttonLabel), // Use the passed button label
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}