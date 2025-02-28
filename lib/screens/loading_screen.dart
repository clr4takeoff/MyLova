import 'package:emo_diary_project/firebase_options.dart';
import 'package:emo_diary_project/models/gpt_response_model.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import './main_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});
  static const platform = MethodChannel("com.example.emo_diary_spinoff/data");

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  late Map profileData;
  late String journalingPrompt = "no prompt";

  Future<void> _loadData() async {
    profileData = await _getProfileData();
    await _firebaseInit();

    print('---- app 사용 log 기록 ---');
    print("name: ${profileData['name']}");
    print("---------------------------");
  }

  Future<void> _firebaseInit() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  Future<Map> _getProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    Map data = {};
    data['name'] = prefs.get('name');
    return data;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _loadData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return MainPage(
              profileData: profileData,
            );
          } else {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text("AI 에이전트가 분주히 움직이는 중입니다..."))
                ],
              ),
            );
          }
        });
  }
}