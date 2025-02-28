import 'package:emo_diary_project/screens/loading_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileSettingScreen extends StatefulWidget {
  const ProfileSettingScreen({super.key});

  @override
  State<ProfileSettingScreen> createState() => _ProfileSettingScreenState();
}

class _ProfileSettingScreenState extends State<ProfileSettingScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isButtonEnabled = false;

  TextEditingController nameController = TextEditingController();

  Future<void> _saveData() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('name', nameController.text);
      await prefs.setBool('isDataSaved', true);
    }
  }

  void _updateButtonState() {
    setState(() {
      _isButtonEnabled = nameController.text.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(
          key: _formKey,
          child: SingleChildScrollView(
              padding: EdgeInsetsDirectional.all(8),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(8, 16, 8, 16),
                    child: TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(labelText: '이름'),
                      onChanged: (value) => _updateButtonState(),
                    ),
                  ),
                  // Expanded(flex: 1, child: Container()),
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(8, 16, 8, 18),
                    child: ElevatedButton(
                      onPressed: _isButtonEnabled
                          ? () async {
                              _saveData();
                              Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => MaterialApp(
                                            home: Scaffold(
                                              appBar: AppBar(
                                                title: const Center(
                                                  child: Text("Diary"),
                                                ),
                                                backgroundColor:
                                                    const Color(0xFFFEF7FF),
                                              ),
                                              body: const LoadingScreen(),
                                            ),
                                          )));
                              // Navigator.pop(context);
                            }
                          : null,
                      child: Text('설정 완료'),
                    ),
                  )
                ],
              ))),
    );
  }
}
