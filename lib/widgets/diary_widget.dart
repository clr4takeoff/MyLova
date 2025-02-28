import 'package:expandable_text/expandable_text.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/diary_content_model.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'response_rating_widget.dart';
import 'package:emo_diary_project/sqflite/db_helper.dart';

class DiaryWidget extends StatefulWidget {
  final int timeDelay;
  final DiaryContent diaryContent;
  final VoidCallback onRefreshRequested;

  DiaryWidget(
      {super.key,
        required this.timeDelay,
        required this.diaryContent,
        required this.onRefreshRequested});

  @override
  State<DiaryWidget> createState() => _DiaryWidgetState();
}


class _DiaryWidgetState extends State<DiaryWidget> {
  final dbHelper = DBHelper();
  bool isCommented = false;
  bool isSaving = false;
  String displayedComment = "로바가 답글을 작성중이에요.";
  bool isRated = false;
  String? deviceToken;
  String userName = "tester";
  bool shouldShowReply = false;
  bool isInitialQuestionAnswered = false; // 첫 번째 질문 답변 상태
  bool isSecondEmotionAsked = false; // 두 번째 설문 완료 상태 추가
  int? initialQuestionRating; // 첫 번째 질문의 답변 값
  int _currentPage = 0; // 현재 페이지를 추적
  Map<String, int?> _selectedRatings = {}; // 각 질문에 대한 선택된 점수 저장
  bool isDataLoaded = false; // 데이터 로드 상태 추가
  int? _emotionBeforeFeedback; // 피드백 전 감정 값 저장
  int? _emotionAfterFeedback;  // 피드백 후 감정 값 저장

  final List<Map<String, String>> _questionsWithTypes = [
    // 피드백 설문
    // 수용도 설문
    {"question": "1. 나는 로바의 답변을 수용할 의향이 있다.", "type": "feedback"},

    // PETS-ER Emotional Responsiveness 질문
    {"question": "2. 로바는 나의 정신 상태를 고려했다.", "type": "feedback"},
    {"question": "3. 로바는 감정적으로 지능적이라고 느껴졌다.", "type": "feedback"},
    {"question": "4. 로바는 감정을 표현했다.", "type": "feedback"},
    {"question": "5. 로바는 나를 공감했다(이해하려고 했다).", "type": "feedback"},
    {"question": "6. 로바는 나에게 관심을 보였다.", "type": "feedback"},
    {"question": "7. 로바는 내가 감정적인 상황을 극복할 수 있도록 도와줬다.", "type": "feedback"},

    // PETS-UT Understanding and Trust 질문
    {"question": "8. 로바는 나의 목표를 이해했다.", "type": "feedback"},
    {"question": "9. 로바는 나의 필요를 이해했다.", "type": "feedback"},
    {"question": "10. 나는 로바를 신뢰했다.", "type": "feedback"},
    {"question": "11. 로바는 나의 의도를 이해했다.", "type": "feedback"},
  ];


  @override
  void initState() {
    super.initState();

    _loadUserName();
    _getFCMToken();
    _initializeState();
    _listenToCommentUpdates();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data['isCommented'] == "true") {
        if (mounted) {
          setState(() {
            isCommented = true;
          });
        }
      }
    });

    isCommented = widget.diaryContent.showComment == 1;
  }


  Future<void> _initializeState() async {
    String userName = (await SharedPreferences.getInstance()).getString('name') ?? "tester";
    DatabaseReference ref = FirebaseDatabase.instance.ref('test/$userName/${widget.diaryContent.id}');

    try {
      // Fetch isRated, isCommented, and comment
      DataSnapshot isRatedSnapshot = await ref.child('isRated').get();
      DataSnapshot isCommentedSnapshot = await ref.child('isCommented').get();
      DataSnapshot commentSnapshot = await ref.child('comment').get();

      bool firebaseIsRated = isRatedSnapshot.value as bool? ?? false;
      bool firebaseIsCommented = isCommentedSnapshot.value as bool? ?? false;
      String? firebaseComment = commentSnapshot.value as String?;

      setState(() {
        isRated = firebaseIsRated;
        isCommented = firebaseIsCommented;
        isDataLoaded = true; // 데이터 로드 완료

        // 디버그 로그 추가
        print("isRated: $isRated, isCommented: $isCommented, isDataLoaded: $isDataLoaded");
        print("isInitialQuestionAnswered: $isInitialQuestionAnswered, isSecondEmotionAsked: $isSecondEmotionAsked");

        // Update displayedComment based on conditions
        if (isRated) {
          displayedComment = firebaseComment ?? "피드백이 완료되었습니다. 답글을 확인하세요.";
        } else if (!isCommented) {
          displayedComment = "로바가 답글을 작성중이에요.";
        } else if (!isRated && !isInitialQuestionAnswered && !isSecondEmotionAsked) {
          displayedComment = "설문 후에 답글을 볼 수 있어요.";
        } else {
          displayedComment = "상태를 확인 중입니다.";
        }

        print("Updated displayedComment: $displayedComment");
      });
    } catch (error) {
      print("Error initializing state: $error");
    }
  }


  Future<void> _loadUserName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? name = prefs.getString('name');
    setState(() {
      userName = name ?? "tester";
    });
  }

  Future<void> _listenToCommentUpdates() async {
    String userName = (await SharedPreferences.getInstance()).getString('name') ?? "tester";
    DatabaseReference ref = FirebaseDatabase.instance.ref('test/$userName/${widget.diaryContent.id}');

    ref.onValue.listen((DatabaseEvent event) async {
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
        bool firebaseIsCommented = data['isCommented'] ?? false;
        bool firebaseIsRated = data['isRated'] ?? false;
        String? firebaseComment = data['comment'] as String?;

        setState(() {
          isCommented = firebaseIsCommented;
          isRated = firebaseIsRated;

          if (!isCommented) {
            displayedComment = "로바가 답글을 작성중이에요.";
          } else if (isInitialQuestionAnswered || firebaseIsRated) {
            displayedComment = firebaseComment ?? "답글을 가져오는 중 오류 발생";
          } else {
            displayedComment = "설문 후에 답글을 볼 수 있어요.";
          }
        });
      }
    });
  }


  Future<void> _getFCMToken() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    try {
      deviceToken = await messaging.getToken();
      print("FCM Token: $deviceToken");
    } catch (e) {
      print("FCM 토큰을 가져오는 중 오류 발생: $e");
    }
  }

  void _deleteDiary(DiaryContent diaryContent) async {
    if (isSaving) return;

    setState(() {
      isSaving = true;
    });

    try {
      String userName =
          (await SharedPreferences.getInstance()).getString('name') ?? "tester";
      String refDir = 'test/$userName/${widget.diaryContent.id}';
      DatabaseReference ref = FirebaseDatabase.instance.ref(refDir);

      await dbHelper.delete(diaryContent.id);
      await ref.update({'status': 'deleted'});

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('일기가 삭제되었습니다'),
        duration: Duration(seconds: 2),
      ));

      widget.onRefreshRequested();
    } catch (error) {
      print("일기 삭제 오류: $error");
    } finally {
      setState(() {
        isSaving = false;
      });
    }
  }

  Future<void> _submitRatingToFirebase(Map<String, int> ratings) async {
    String userName =
        (await SharedPreferences.getInstance()).getString('name') ?? "tester";
    DatabaseReference ref = FirebaseDatabase.instance
        .ref('test/$userName/${widget.diaryContent.id}');

    try {
      // 각 질문의 점수를 r1 ~ r11로 저장
      Map<String, dynamic> ratingsToSave = {};
      int index = 1;
      ratings.forEach((key, value) {
        ratingsToSave['r$index'] = value;
        index++;
      });

      // 모든 점수 저장 및 isRated 업데이트
      await ref.update({
        ...ratingsToSave,
        'isRated': true, // 모든 질문에 답변 완료되었음을 표시
      });

      setState(() {
        isRated = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('답변이 완료되었습니다.'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (error) {
      print("평가 저장 오류: $error");
    }
  }


  List<Map<String, String>> _getQuestionsForCurrentPage() {
    if (_currentPage == 0) {
      // 첫 번째 페이지에서는 첫 번째 질문만 반환
      return [_questionsWithTypes[0]];
    } else {
      // 두 번째 페이지에서는 나머지 10개 질문 반환
      return _questionsWithTypes.sublist(1);
    }
  }


  @override
  Widget build(BuildContext context) {
    final currentQuestions = _getQuestionsForCurrentPage();
    final isLastPage = _currentPage == 1; // 마지막 페이지 여부

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 14, 6),
      child: Card(
        clipBehavior: Clip.antiAliasWithSaveLayer,
        color: const Color(0xFFFEF7FF),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(0, 6, 6, 6),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              // 데이터 로드 중 로딩 인디케이터 표시
              if (!isDataLoaded)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                // 데이터 로드 후 UI 렌더링
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 10, 4),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF7FF),
                      shape: BoxShape.rectangle,
                    ),
                    width: double.infinity,
                    child: Row(
                      children: [
                        Flexible(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 0, 4),
                              child: ExpandableText(
                                widget.diaryContent.content, // 작성한 글
                                expandText: "펼치기",
                                collapseText: "접기",
                                expandOnTextTap: true,
                                collapseOnTextTap: true,
                                maxLines: 3,
                                linkColor: Colors.blue, // 링크 색상을 파란색으로 설정
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 피드백 표시
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(6, 4, 6, 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Image.asset(
                          isCommented
                              ? 'assets/images/purple_flower2.png'
                              : 'assets/images/purple_flower.png',
                          height: 40,
                          width: 40,
                        ),
                      ),
                      Flexible(
                        child: Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1.0,
                            ),
                          ),
                          child: Text(
                            displayedComment,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),



                // 피드백과 설문을 isCommented가 true인 경우에만 표시
                if (isCommented) ...[
                  // 감정 설문: "피드백 확인 전 기분이 어떠신가요?"
                  if (isDataLoaded && !isRated && !isInitialQuestionAnswered && !isSecondEmotionAsked)
                    ResponseRatingWidget(
                      key: ValueKey("beforeFeedback"),
                      onRatingSubmitted: (ratings) async {
                        setState(() {
                          _emotionBeforeFeedback = ratings.values.first;
                          isInitialQuestionAnswered = true;
                        });

                        // Firebase 업데이트
                        String userName =
                            (await SharedPreferences.getInstance()).getString('name') ?? "tester";
                        DatabaseReference ref =
                        FirebaseDatabase.instance.ref('test/$userName/${widget.diaryContent.id}');

                        try {
                          await ref.child('3_emotion_bc').set(_emotionBeforeFeedback);
                          print("Emotion Before Feedback: $_emotionBeforeFeedback"); // 디버깅 로그

                          DataSnapshot commentSnapshot = await ref.child('comment').get();
                          String? updatedComment = commentSnapshot.value as String?;
                          setState(() {
                            displayedComment = updatedComment ?? "답글을 가져오는 중 오류 발생";
                          });
                        } catch (error) {
                          print("Error updating Firebase: $error");
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("데이터 저장 중 문제가 발생했습니다. 다시 시도해주세요.")),
                          );
                        }
                      },
                      questionsWithTypes: [
                        {"question": "피드백 확인 전 기분이 어떠신가요?", "type": "emotion"},
                      ],
                      buttonLabel: '다음',
                    ),

                  // 감정 설문: "피드백 확인 후 기분이 어떠신가요?"
                  if (!isRated && isInitialQuestionAnswered && !isSecondEmotionAsked)
                    ResponseRatingWidget(
                      key: ValueKey("afterFeedback"),
                      onRatingSubmitted: (ratings) async {
                        setState(() {
                          _emotionAfterFeedback = ratings.values.first;
                          isSecondEmotionAsked = true;
                        });

                        // Firebase 업데이트
                        String userName =
                            (await SharedPreferences.getInstance()).getString('name') ?? "tester";
                        DatabaseReference ref =
                        FirebaseDatabase.instance.ref('test/$userName/${widget.diaryContent.id}');

                        try {
                          await ref.child('4_emotion_ac').set(_emotionAfterFeedback);
                          print("Emotion After Feedback: $_emotionAfterFeedback"); // 디버깅 로그
                          print("Emotion Before Feedback: $_emotionBeforeFeedback"); // 디버깅 로그
                        } catch (error) {
                          print("Error updating Firebase: $error");
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("데이터 저장 중 문제가 발생했습니다. 다시 시도해주세요.")),
                          );
                        }
                      },
                      questionsWithTypes: [
                        {"question": "피드백 확인 후 기분이 어떠신가요?", "type": "emotion"},
                      ],
                      buttonLabel: '다음',
                    ),

                  // 피드백 설문
                  if (!isRated && isSecondEmotionAsked) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: ResponseRatingWidget(
                        onRatingSubmitted: (ratings) {
                          setState(() {
                            _selectedRatings.addAll(ratings);
                            if (isLastPage) {
                              // 마지막 페이지에서는 답변 제출
                              _submitRatingToFirebase(
                                _selectedRatings.map((key, value) => MapEntry(key, value!)),
                              );
                            } else {
                              // 다음 페이지로 이동
                              _currentPage++;
                            }
                          });
                        },
                        questionsWithTypes: currentQuestions,
                        buttonLabel: isLastPage ? '제출' : '다음',
                      ),
                    ),

                  ],
                ],

                // 로딩 표시
                if (isSaving)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ),

                // 날짜 및 메뉴 버튼
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(6, 0, 6, 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(6, 0, 6, 0),
                        child: Text(
                          DateFormat('yyyy년 MM월 dd일 HH:mm')
                              .format(DateTime.parse(widget.diaryContent.date)),
                        ),
                      ),
                      PopupMenuButton(
                        onSelected: (String result) {
                          if (result == 'delete') {
                            _deleteDiary(widget.diaryContent);
                          }
                        },
                        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                              value: 'delete', child: Text("삭제")),
                        ],
                        icon: const Icon(Icons.more_horiz),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

}