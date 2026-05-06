import 'dart:async';
import 'dart:io';
import 'package:autoschool_btgp/admin/admin_home_page.dart';
import 'package:autoschool_btgp/instructor/instructor_home_page.dart';
import 'package:autoschool_btgp/student/student_home_page.dart';
import 'package:flutter/material.dart';
import 'package:minio/io.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:minio/minio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:autoschool_btgp/main.dart';
import 'package:autoschool_btgp/services/phone_page.dart';
import 'package:autoschool_btgp/notification_service.dart';

class AuthService extends ChangeNotifier {
  ParseUser? _currentUser;
  bool _isLoading = false;
  Timer? _pollingTimer;
  Future<void>? _initializationComplete;

  ParseUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;

  AuthService() {
    _initializationComplete = _loadCurrentUser();
  }

  Future<void> ensureInitialized() async {
    await _initializationComplete;
  }

  void setCurrentUser(ParseUser user) {
    _currentUser = user;
    _startPolling();
    notifyListeners();
  }

  Future<void> _loadCurrentUser() async {
    _currentUser = await ParseUser.currentUser() as ParseUser?;
    if (_currentUser != null && _currentUser!.sessionToken != null) {
      final valid = await isSessionValid();
      if (!valid) {
        await _forcedLogout();
        _currentUser = null;
      } else {
        await _refreshCurrentUser();
        _startPolling();
      }
    } else {
      _currentUser = null;
    }
    notifyListeners();
  }

  Future<void> _forcedLogout() async {
    _stopPolling();
    await _currentUser?.logout();
    final GoogleSignIn googleSignIn = GoogleSignIn();
    if (await googleSignIn.isSignedIn()) {
      await googleSignIn.signOut();
    }
    _currentUser = null;
  }

  Future<ParseUser?> getCurrentUser() async {
    return await ParseUser.currentUser() as ParseUser?;
  }

  void _startPolling() {
    _stopPolling();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      await _refreshCurrentUser();
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _refreshCurrentUser() async {
    if (_currentUser == null) return;
    try {
      final query = QueryBuilder<ParseUser>(ParseUser.forQuery())
        ..whereEqualTo('objectId', _currentUser!.objectId);
      final response = await query.query();
      if (response.success && response.results != null && response.results!.isNotEmpty) {
        final updatedUser = response.results!.first as ParseUser;
        if (updatedUser.get('role') != _currentUser!.get('role')) {
          _currentUser!.set('role', updatedUser.get('role'));
          notifyListeners();
        }
      } else if (response.error?.code == 209) {
        await _forcedLogout();
        notifyListeners();
      }
    } catch (e) {
      print('Ошибка при опросе: $e');
    }
  }

  Future<String?> registerWithEmail({
    required String email,
    required String password,
    required String surname,
    required String firstname,
    required String patronymic,
    required String phone,
  }) async {
    _setLoading(true);
    try {
      var user = ParseUser(email, password, email);
      user.set('surname', surname);
      user.set('firstname', firstname);
      user.set('patronymic', patronymic);
      user.set('phone', phone);
      user.set('role', 'student');

      var response = await user.signUp();
      if (response.success) {
        _currentUser = response.result;
        _startPolling();
        notifyListeners();
        return null;
      } else {
        return response.error!.message;
      }
    } catch (e) {
      return 'Ошибка: $e';
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> loginWithEmail(String email, String password) async {
    _setLoading(true);
    try {
      var user = ParseUser(email, password, email);
      var response = await user.login();
      if (response.success) {
        _currentUser = response.result;
        await _refreshCurrentUser();
        _startPolling();
        notifyListeners();
        
        await NotificationService.resendTokenIfLoggedIn();
        
        return null;
      } else {
        return response.error!.message;
      }
    } catch (e) {
      return 'Ошибка: $e';
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> loginWithGoogle() async {
    _setLoading(true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return 'CANCELLED';

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final response = await ParseUser.loginWith('google',{'id': googleUser.id,'id_token': googleAuth.idToken});

      if(response.success) {
        _currentUser = response.result;

        final currentUser = _currentUser!;
        bool needsUpdate = false;

        if (currentUser.get('email') == null && googleUser.email != null) {
          currentUser.set('email', googleUser.email);
          needsUpdate = true;
        }

        if (currentUser.get('surname') == null && currentUser.get('firstame') == null) {
          final displayName = googleUser.displayName ?? '';
          final parts = displayName.trim().split(RegExp(r'\s+'));
          if (parts.isNotEmpty) {
            if (parts.length >=2) {
              currentUser.set('firstname', parts[0]);
              currentUser.set('surname', parts.sublist(1).join(' '));
            } else {
              currentUser.set('firstname', displayName);
            }
            needsUpdate = true;
          }
        }

        if (currentUser.get('photo') == null && googleUser.photoUrl != null) {
          currentUser.set('photo', googleUser.photoUrl);
          needsUpdate = true;
        }

        if (currentUser.get('role') == null) {
          currentUser.set('role', 'student');
          needsUpdate = true;
        }

        if (needsUpdate) {
          await currentUser.save();
        }

        await _refreshCurrentUser();
        _startPolling();
        notifyListeners();

        final phoneNumber = _currentUser!.get('phone')?.toString();
        if (phoneNumber == null || phoneNumber.isEmpty) {
          if (navigatorKey.currentContext != null) {
            Future.delayed(const Duration(milliseconds: 300), () {
              navigatorKey.currentState!.pushReplacement(
                MaterialPageRoute(
                  builder: (context) => PhonePage(
                    user: currentUser!,
                    onPhoneSaved: () {
                      final role = _currentUser!.get('role') ?? 'student';
                      Widget destination;
                      switch (role) {
                        case 'admin':
                          destination = AdminHomePage();
                          break;
                        case 'instructor':
                          destination = InstructorHomePage();
                          break;
                        default:
                          destination = StudentHomePage();
                      }
                      navigatorKey.currentState!.pushReplacement(
                        MaterialPageRoute(builder: (_) => destination),
                      );
                    },
                  ),
                ),
              );
            });
          }
          return null;
        }

        await NotificationService.resendTokenIfLoggedIn();

        return null;
      } else {
        return response.error!.message;
      }
    } catch (e) {
      return 'Ошибка входа через Google: $e';
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> uploadProfilePhoto(XFile image) async {
    if (_currentUser == null) return 'Пользователь не авторизован';
    try {
      final file = File(image.path);
      final userId = _currentUser!.objectId!;

      const accessKey = 'YCAJEyTjVJ5hPHjDHwCdRFvqu';
      const secretKey = 'YCPsjstQHgXYSe0ZwRRl-fKFUCSnKMAj5WtyGJ4W';
      const bucket = 'autoschoolbtgp';
      const region = 'ru-central1';
      const endpoint = 'storage.yandexcloud.net';

      final minio = Minio(
        endPoint: endpoint,
        port: 443,
        useSSL: true,
        accessKey: accessKey,
        secretKey: secretKey,
        region: region,
      );

      final key = 'users/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';

      await minio.fPutObject(
        bucket,
        key,
        file.path,
        metadata: {'Content-Type': 'image/jpeg'},
      );

      final photoUrl = 'https://$endpoint/$bucket/$key';

      _currentUser!.set('photo', photoUrl);
      await _currentUser!.save();
      notifyListeners();
      return null;
    } catch (e) {
      return 'Ошибка загрузки фото: $e';
    }
  }

  Future<void> signOut() async {
    _stopPolling();
    if (_currentUser != null) {
      await _currentUser!.logout();
      _currentUser = null;
      final GoogleSignIn googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }
      notifyListeners();
    }
  }

  Future<String?> deleteAccount() async {
    if (_currentUser == null) return 'Пользователь не авторизован';
    _setLoading(true);
    try {
      final response = await _currentUser!.delete();
      if (response.success) {
        final GoogleSignIn googleSignIn = GoogleSignIn();
        if (await googleSignIn.isSignedIn()) {
          await googleSignIn.signOut();
        }

        await _currentUser!.logout();
        _currentUser = null;
        _stopPolling();
        notifyListeners();
        return null;
      } else {
        return response.error!.message;
      }
    } catch (e) {
      return 'Ошибка удаления: $e';
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> isSessionValid() async {
    if (_currentUser == null) return false;
    try {
      final query = QueryBuilder<ParseUser>(ParseUser.forQuery())
          ..whereEqualTo('objectId', _currentUser!.objectId);
      final response = await query.query();
      if (response.success && response.results != null && response.results!.isNotEmpty) {
        return true;
      } else if (response.error?.code == 209) {
        return false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();

  }
}
