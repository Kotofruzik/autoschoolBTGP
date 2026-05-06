import 'package:autoschool_btgp/notification_service.dart';
import 'package:autoschool_btgp/services/users_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:provider/provider.dart';
import 'package:autoschool_btgp/services/login_page.dart';
import 'package:autoschool_btgp/services/register_page.dart';
import 'package:autoschool_btgp/services/photo_upload_page.dart';
import 'package:autoschool_btgp/services/auth_service.dart';
import 'package:autoschool_btgp/student/student_home_page.dart';
import 'package:autoschool_btgp/instructor/instructor_home_page.dart';
import 'package:autoschool_btgp/admin/admin_home_page.dart';
import 'package:autoschool_btgp/instructor/create_lesson_page.dart';
import 'package:autoschool_btgp/services/phone_page.dart';
import 'dart:convert';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {

  await Firebase.initializeApp();

  await _showBackgroundNotification(message);
}

Future<void> _showBackgroundNotification(RemoteMessage message) async {
  String title = message.notification?.title ?? 'Новое уведомление';
  String body = message.notification?.body ?? '';

  if (message.data.isNotEmpty) {
    try {
      if (message.data.containsKey('data')) {
        var innerData = jsonDecode(message.data['data']);
        if (innerData['title'] != null) title = innerData['title'];
        if (innerData['body'] != null) body = innerData['body'];
      } else if (message.data.containsKey('title')) {
        title = message.data['title'];
        body = message.data['body'] ?? '';
      }
    } catch (e) {
      print('Ошибка: $e');
    }
  }

  if (body.isEmpty) body = "Нажмите для просмотра";

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  try {
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  } catch (_) {}

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'lesson_channel',
    'Уроки и уведомления',
    channelDescription: 'Критические уведомления',
    importance: Importance.max,
    priority: Priority.max,
    fullScreenIntent: true,
    category: AndroidNotificationCategory.message,
    visibility: NotificationVisibility.public,
    playSound: true,
    enableVibration: true,
    icon: '@mipmap/ic_launcher',
    autoCancel: true,
  );

  const NotificationDetails details = NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch.remainder(100000),
    title,
    body,
    details,
    payload: jsonEncode(message.data),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const keyApplicationId = 'qCxbZic6eqme0pvScG5jLoCxDUxztB9FGuiXhEiy';
  const keyClientKey = '50yEotCNReUkwSd7nhVmhYnoZspmLcbizp1GJC3v';
  const keyServerUrl = 'https://parseapi.back4app.com';

  await Parse().initialize(
    keyApplicationId,
    keyServerUrl,
    clientKey: keyClientKey,
    autoSendSessionId: true,
    debug: true,
    liveQueryUrl: 'wss://parseapi.back4app.com',
  );

  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await NotificationService.setupPush();

  final token = NotificationService.getCurrentToken();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => UsersProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Автошкола',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => AuthWrapper(),
          '/login': (context) => LoginPage(),
          '/register': (context) => RegisterPage(),
          '/photo-upload': (context) => PhotoUploadPage(),
          '/student-home' : (context) => StudentHomePage(),
          '/create-lesson': (context) {
            final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
            ParseUser? student;
            if (args != null && args.containsKey('student')) {
              final studentData = args['student'];
              if (studentData is ParseUser) {
                student = studentData;
              } else if (studentData is Map<String, dynamic>) {
                student = ParseUser.forQuery()
                    ..objectId = studentData['id']
                    ..set('surname', studentData['surname'] ?? '')
                    ..set('firstname', studentData['firstname'] ?? '')
                    ..set('patronymic', studentData['patronymic'] ?? '')
                    ..set('phone', studentData['phone'] ?? '')
                    ..set('email', studentData['email'] ?? '')
                    ..set('photo', studentData['photo'] ?? '');
              }
            }
            DateTime? selectedDate;
            if (args != null && args.containsKey('selectedDate')) {
              final dataObj = args['selectedDate'];
              if (dataObj is DateTime) {
                selectedDate = dataObj;
              } else if (dataObj is String) {
                selectedDate = DateTime.tryParse(dataObj);
              }
            }
            return CreateLessonPage(
              student: student,
              selectedDate: selectedDate,
              skipDateStep: args?['skipDateStep'] == true,
              skipStudentStep: args?['skipStudentStep'] == true,
            );
          },
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late Future<void> _initializationFuture;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthService>(context, listen: false);
    _initializationFuture = auth.ensureInitialized();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final auth = Provider.of<AuthService>(context);

        if (auth.currentUser != null && auth.currentUser!.sessionToken != null) {
          final role = auth.currentUser!.get('role') ?? 'student';
          switch (role) {
            case 'admin':
              return AdminHomePage();
            case 'instructor':
              return InstructorHomePage();
            case 'student':
            default:
              return StudentHomePage();
          }
        }
        return LoginPage();
      },
    );
  }
}
