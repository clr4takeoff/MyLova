import 'package:emo_diary_project/screens/profile_setting_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/loading_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' as fln;

final fln.FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = fln.FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeFirebase();
  RemoteMessage? initialMessage = await _initializeMessaging();
  await _initializeLocalNotifications();

  runApp(MyApp(initialMessage: initialMessage));
}

/// Initializes Firebase, checking if it’s already initialized.
Future<void> _initializeFirebase() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
    print("Firebase initialized.");
  }
}

/// Retrieves the initial message if the app was launched by a notification.
Future<RemoteMessage?> _initializeMessaging() async {
  return await FirebaseMessaging.instance.getInitialMessage();
}

/// Sets up Flutter Local Notifications for handling foreground messages.
Future<void> _initializeLocalNotifications() async {
  const initializationSettingsAndroid = fln.AndroidInitializationSettings('@mipmap/ic_launcher');
  final initializationSettings = fln.InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (fln.NotificationResponse notificationResponse) async {
      print("Notification clicked. App opened.");
    },
  );
}

class MyApp extends StatefulWidget {
  final RemoteMessage? initialMessage;
  const MyApp({super.key, this.initialMessage});

  @override
  State<MyApp> createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  bool isDataSaved = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  /// Initializes app components and handles initial notification if present.
  Future<void> _initializeApp() async {
    await _requestNotificationPermission();
    await _loadUserData();
    _setupFirebaseMessaging();
    _handleInitialNotification();
  }

  /// Handles any notification that launched the app.
  void _handleInitialNotification() {
    if (widget.initialMessage != null) {
      print("Handling initial message: ${widget.initialMessage!.messageId}");
    }
  }

  /// Requests notification permissions from the user.
  Future<void> _requestNotificationPermission() async {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    switch (settings.authorizationStatus) {
      case AuthorizationStatus.authorized:
        print('User granted permission');
        break;
      case AuthorizationStatus.provisional:
        print('User granted provisional permission');
        break;
      case AuthorizationStatus.denied:
      default:
        print('User declined or has not accepted permission');
        break;
    }
  }

  /// Loads user data, setting `isDataSaved` state.
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDataSaved = prefs.getBool('isDataSaved') ?? false;
      print("Data loaded, isDataSaved: $isDataSaved");
    });
  }

  /// Configures Firebase Messaging for foreground notifications.
  void _setupFirebaseMessaging() {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Foreground message received: ${message.messageId}");

      final title = message.data['title'] ?? "새 댓글 알림!";
      final body = message.data['body'] ?? "당신의 일기에 새로운 댓글이 달렸습니다.";

      flutterLocalNotificationsPlugin.show(
        message.hashCode,
        title,
        body,
        const fln.NotificationDetails(
          android: fln.AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            importance: fln.Importance.max,
            priority: fln.Priority.high,
            showWhen: true,
          ),
        ),
      );
      print("Notification shown in foreground.");
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text("Diary", style: TextStyle(fontSize: 24)),
          centerTitle: true,
          backgroundColor: const Color(0xFFFEF7FF),
        ),
        body: isDataSaved ? const LoadingScreen() : const ProfileSettingScreen(),
      ),
    );
  }
}
