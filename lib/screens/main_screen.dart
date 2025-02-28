import 'package:emo_diary_project/models/diary_content_model.dart';
import 'package:flutter/material.dart';
import '../widgets/diary_list_widget.dart';
import '../widgets/writing_widget.dart';
import '../widgets/emotion_input_widget.dart';

bool isRetroMode = false;
late DiaryContent target;

class MainPage extends StatefulWidget {
  final Map profileData;

  const MainPage({super.key, required this.profileData});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final GlobalKey<DiaryListState> _listKey = GlobalKey();
  int timeDelay = 0;

  @override
  void initState() {
    super.initState();
    // timeDelay 값을 초기화. 예: 10초
    timeDelay = 21600; // timeDelay 수정 1
  }

  // DiaryList에서 timeDelay를 업데이트할 수 있는 메서드
  void updateTimeDelay(int newTimeDelay) {
    setState(() {
      timeDelay = newTimeDelay;
    });
  }

  void showEmotionInputBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return EmotionInputWidget(
          onNextPressed: (selectedEmotion) {
            Navigator.pop(context); // 감정 선택 후 닫기
            String emotionString = selectedEmotion.toString(); // int를 String으로 변환
            showWritingInputBottomSheet(context, emotionString); // 감정 전달
          },
        );
      },
    );
  }


  void showWritingInputBottomSheet(BuildContext context, String selectedEmotion) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 키보드 입력 시 스크롤 가능하게 설정
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9, // 세로 길이 60%로 줄임
          child: WritingSectionWidget(
            onRefreshRequested: () {
              _listKey.currentState?.refreshItemList();
            },
            timeDelay: 21600, // timeDelay 수정 2
            selectedEmotion: selectedEmotion,
          ),
        );
      },
    );
  }

  void showPostDiaryEmotionInput(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return EmotionInputWidget(
          onNextPressed: (emotion) {
            Navigator.pop(context);
            // 추가 감정 입력 처리
          },
          prompt: "일기 작성 후, 다시 한번 기분을 입력해주세요.",
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 일기 목록 위젯 표시
                DiaryList(
                  key: _listKey,
                  onRefresh: () => _listKey.currentState?.refreshItemList(),
                  timeDelay: timeDelay,
                ),
              ],
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showEmotionInputBottomSheet(context); // 감정 입력 BottomSheet부터 표시
        },
        child: const Icon(Icons.edit),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
