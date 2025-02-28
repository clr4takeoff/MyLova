import 'package:flutter/material.dart';

class EmotionInputWidget extends StatefulWidget {
  final ValueChanged<int> onNextPressed;
  final String prompt; // 감정 입력에 대한 사용자 정의 메시지

  const EmotionInputWidget({super.key, required this.onNextPressed, this.prompt = '지금 기분이 어떠신가요?'});

  @override
  State<EmotionInputWidget> createState() => _EmotionInputWidgetState();
}

class _EmotionInputWidgetState extends State<EmotionInputWidget> {
  int? _selectedScore;

  void _selectScore(int score) {
    setState(() {
      _selectedScore = score;
    });
  }

  @override
  Widget build(BuildContext context) {
    final labels = ["매우 나쁨", "나쁨", "보통", "좋음", "매우 좋음"];

    return Container(
      padding: const EdgeInsets.all(20),
      height: 300,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.prompt,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (index) {
              return Flexible(
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => _selectScore(index + 1),
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        backgroundColor: _selectedScore == index + 1
                            ? const Color(0xffdfcdf3)
                            : const Color(0xffeaeaea),
                      ),
                      child: Text('${index + 1}', style: const TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(height: 4),
                    Text(labels[index], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _selectedScore != null
                ? () => widget.onNextPressed(_selectedScore!)
                : null,
            child: const Text('입력 완료'),
          ),
        ],
      ),
    );
  }
}
