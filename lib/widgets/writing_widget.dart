import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../sqflite/db_helper.dart';
import '../models/diary_content_model.dart';
import '../models/gpt_response_model.dart';
import '../widgets/emotion_input_widget.dart';


class WritingSectionWidget extends StatefulWidget {
  final VoidCallback onRefreshRequested;
  final int timeDelay;
  final String selectedEmotion;

  const WritingSectionWidget({
    super.key,
    required this.onRefreshRequested,
    required this.timeDelay,
    required this.selectedEmotion,
  });

  @override
  State<WritingSectionWidget> createState() => _WritingSectionWidgetState();
}

class _WritingSectionWidgetState extends State<WritingSectionWidget> {
  final contentEditController = TextEditingController();
  bool _isButtonEnabled = false;
  bool isSending = false;
  bool isDelayed = false;

  @override
  void initState() {
    super.initState();
    // timeDelay를 사용해 isDelayed 값을 설정
    isDelayed = widget.timeDelay > 0;
  }

  final dbHelper = DBHelper();

  void _updateButtonState() {
    setState(() {
      _isButtonEnabled = contentEditController.text.isNotEmpty;
    });
  }

  int _countWords(String content) {
    List<String> list = content.split(" ");
    return list.length;
  }

  Future<void> _saveDiaryContent() async {
    setState(() {
      isSending = true;
    });

    try {
      DateTime date = DateTime.now();
      String? userName = (await SharedPreferences.getInstance()).getString('name') ?? "tester";
      String diaryId = DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
      String refDir = 'test/$userName/$diaryId';

      // Retrieve the FCM token
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      String? token = await messaging.getToken();

      if (token == null) {
        print("Error: Unable to retrieve FCM token.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('FCM 토큰을 가져올 수 없습니다. 다시 시도하세요.')),
        );
        return;
      }

      print("FCM Token Retrieved: $token");

      // Get GPT comment response
      String comment = await GPTResponse().fetchGPTCommentResponse(contentEditController.text);

      isDelayed = widget.timeDelay > 0;

      // Save to SQLite DB
      await dbHelper.insert(DiaryContent(
        id: diaryId,
        date: date.toString(),
        showComment: 0,
        content: contentEditController.text,
        comment: comment,
      ));

      // Save to Firebase Realtime Database
      DatabaseReference ref = FirebaseDatabase.instance.ref(refDir);
      await ref.set({
        'date': diaryId,
        'content': _countWords(contentEditController.text),
        'comment': comment,
        'isCommented': false,
        'isDelayed': isDelayed,
        '1_emotion_bw': int.parse(widget.selectedEmotion),
        '2_emotion_aw': "", // Post-writing emotion to be updated later
        'deviceToken': token,
        'isRated': false,
      });

      widget.onRefreshRequested();
      Navigator.pop(context);

      // Show BottomSheet for post-writing emotion input
      Future.delayed(Duration.zero, () {
        _showEmotionBottomSheet(context, refDir);
      });

    } catch (e) {
      print("Error saving diary content: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 중 오류가 발생했습니다. 다시 시도하세요.')),
      );
    } finally {
      setState(() {
        isSending = false;
      });
    }
  }

  void _showEmotionBottomSheet(BuildContext context, String refDir) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return EmotionInputWidget(
          onNextPressed: (emotion) async {
            Navigator.pop(context);

            try {
              // Update the 2_emotion_aw field in Firebase
              DatabaseReference ref = FirebaseDatabase.instance.ref(refDir);
              await ref.update({'2_emotion_aw': emotion});
              print("Post-writing emotion updated: $emotion");
            } catch (e) {
              print("Error updating post-writing emotion: $e");
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('감정 데이터를 저장하는 중 오류가 발생했습니다.')),
              );
            }
          },
          prompt: "일기를 작성한 지금, 기분은 어떤가요?",
        );
      },
    );
  }


  Widget _sendingScreen() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  void _promptEmotionInputAfterWriting(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return EmotionInputWidget(
          onNextPressed: (emotion) {
            Navigator.pop(context); // 입력 완료 후 닫기
            // Firebase에 후속 감정 저장
            _saveEmotionPostWriting(emotion);
          },
          prompt: "일기를 작성한 직후, 기분은 어떤가요?",
        );
      },
    );
  }

  Future<void> _saveEmotionPostWriting(int emotion) async {
    String userName = (await SharedPreferences.getInstance()).getString('name') ?? "tester";
    String refDir = 'test/$userName/${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}';
    DatabaseReference ref = FirebaseDatabase.instance.ref(refDir);

    await ref.update({'postWritingEmotion': emotion});
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFEF7FF),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: isSending
              ? _sendingScreen()
              : Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 0, 0),
                    child: Text(
                      DateFormat('yyyy/MM/dd').format(DateTime.now()),
                      style: const TextStyle(fontSize: 20), // 날짜 텍스트 크기 증가
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.all(4),
                    child: IconButton(
                      icon: const Icon(Icons.cancel),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: TextField(
                    controller: contentEditController,
                    onChanged: (value) => _updateButtonState(),
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    keyboardType: TextInputType.multiline,
                    style: const TextStyle(fontSize: 16), // 텍스트 필드의 입력 텍스트 크기 증가
                    decoration: const InputDecoration(
                      hintText: '일기를 작성해주세요.',
                      hintStyle: TextStyle(fontSize: 16), // 힌트 텍스트 크기 증가
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(30, 0, 30, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end, // 버튼을 오른쪽으로 정렬
                  children: [
                    ElevatedButton(
                      onPressed: _isButtonEnabled ? _saveDiaryContent : null,
                      child: const Text(
                        "작성 완료",
                        style: TextStyle(fontSize: 20), // 버튼 텍스트 크기 증가
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
