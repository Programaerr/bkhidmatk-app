import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/database.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../data/repository_cloud.dart';
import '../data/repository_local.dart';
import '../data/supabase_config.dart';

class AppState extends ChangeNotifier {
  AppState()
      : isCloud = SupabaseConfig.isConfigured,
        repo = SupabaseConfig.isConfigured
            ? CloudRepository()
            : LocalRepository();

  /// هل التطبيق متصل بقاعدة البيانات المشتركة (Supabase)؟
  final bool isCloud;

  final Repository repo;

  AppUser? user;
  bool booting = true;
  ThemeMode themeMode = ThemeMode.light;

  bool get isLoggedIn => user != null;
  bool get isAdmin => user?.isAdmin ?? false;

  SupabaseClient get _auth => Supabase.instance.client;

  Future<void> boot() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('theme');
    themeMode = savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;

    try {
      if (isCloud) {
        final authUser = _auth.auth.currentUser;
        if (authUser != null) {
          user = await repo.userByAuthId(authUser.id);
          if (user == null) await _auth.auth.signOut();
        }
      } else {
        final userId = prefs.getInt('user_id');
        if (userId != null) user = await repo.userById(userId);
      }
    } catch (_) {
      user = null;
    }

    booting = false;
    notifyListeners();
  }

  Future<String?> login(String phone, String password) async {
    if (isCloud) return _cloudLogin(phone, password);

    final found = await repo.findUserByPhone(phone);
    if (found == null) return 'لا يوجد حساب مسجل بهذا الرقم';
    if (found.passwordHash != _localHash(password)) return 'كلمة المرور غير صحيحة';
    user = found;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', found.id!);
    notifyListeners();
    return null;
  }

  Future<String?> _cloudLogin(String phone, String password) async {
    try {
      final result = await _auth.auth.signInWithPassword(
        email: SupabaseConfig.emailForPhone(phone),
        password: password,
      );
      final authUser = result.user;
      if (authUser == null) return 'تعذر تسجيل الدخول، حاول مرة أخرى';
      final profile = await repo.userByAuthId(authUser.id);
      if (profile == null) {
        await _auth.auth.signOut();
        return 'هذا الحساب غير مكتمل، تواصل مع الدعم';
      }
      user = profile;
      notifyListeners();
      return null;
    } on AuthException catch (e) {
      return _authError(e);
    } catch (_) {
      return 'تعذر الاتصال بالإنترنت، تحقق من الشبكة وحاول مرة أخرى';
    }
  }

  Future<String?> register({
    required String name,
    required String phone,
    required String password,
    String? city,
    String? address,
  }) async {
    if (isCloud) {
      return _cloudRegister(
        name: name,
        phone: phone,
        password: password,
        city: city,
        address: address,
      );
    }

    if (await repo.phoneExists(phone)) return 'رقم الهاتف مستخدم مسبقاً';
    final newUser = AppUser(
      name: name.trim(),
      phone: phone,
      passwordHash: _localHash(password),
      role: 'customer',
      city: city,
      address: address,
      createdAt: DateTime.now(),
    );
    final id = await repo.createUser(newUser);
    user = AppUser(
      id: id,
      name: newUser.name,
      phone: newUser.phone,
      passwordHash: newUser.passwordHash,
      role: 'customer',
      city: city,
      address: address,
      createdAt: newUser.createdAt,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', id);
    notifyListeners();
    return null;
  }

  Future<String?> _cloudRegister({
    required String name,
    required String phone,
    required String password,
    String? city,
    String? address,
  }) async {
    try {
      if (await repo.phoneExists(phone)) return 'رقم الهاتف مستخدم مسبقاً';

      final result = await _auth.auth.signUp(
        email: SupabaseConfig.emailForPhone(phone),
        password: password,
        data: {'name': name.trim(), 'phone': phone},
      );
      final authUser = result.user;
      if (authUser == null) return 'تعذر إنشاء الحساب، حاول مرة أخرى';
      if (result.session == null) {
        return 'تعذر إنشاء الجلسة. أوقف «تأكيد البريد» في إعدادات Supabase ثم أعد المحاولة';
      }

      final newUser = AppUser(
        name: name.trim(),
        phone: phone,
        passwordHash: '',
        role: 'customer',
        city: city,
        address: address,
        createdAt: DateTime.now(),
      );
      final id = await repo.createUser(newUser);
      user = AppUser(
        id: id,
        name: newUser.name,
        phone: newUser.phone,
        passwordHash: '',
        role: 'customer',
        city: city,
        address: address,
        createdAt: newUser.createdAt,
      );
      notifyListeners();
      return null;
    } on AuthException catch (e) {
      return _authError(e);
    } catch (_) {
      // لا نُبقي جلسة بلا ملف شخصي.
      try {
        await _auth.auth.signOut();
      } catch (_) {}
      return 'تعذر إكمال التسجيل، حاول مرة أخرى';
    }
  }

  Future<void> updateProfile(AppUser updated) async {
    final phoneChanged = updated.phone != user?.phone;
    await repo.updateUser(updated);
    user = updated;
    notifyListeners();

    // تغيير رقم الهاتف يجب أن يتبعه تغيير بريد الدخول الصناعي.
    if (isCloud && phoneChanged) {
      try {
        await _auth.auth.updateUser(
          UserAttributes(email: SupabaseConfig.emailForPhone(updated.phone)),
        );
      } catch (_) {
        // نبقى مسجلين؛ يمكن تعديل الرقم من لوحة Supabase عند الحاجة.
      }
    }
  }

  Future<void> setTheme(bool dark) async {
    themeMode = dark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', dark ? 'dark' : 'light');
    notifyListeners();
  }

  Future<void> logout() async {
    user = null;
    notifyListeners();
    if (isCloud) {
      try {
        await _auth.auth.signOut();
      } catch (_) {}
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
    }
  }

  Future<void> refreshUser() async {
    if (user == null) return;
    try {
      if (isCloud) {
        final authUser = _auth.auth.currentUser;
        if (authUser == null) return;
        user = await repo.userByAuthId(authUser.id);
      } else if (user!.id != null) {
        user = await repo.userById(user!.id!);
      }
      notifyListeners();
    } catch (_) {}
  }

  String _localHash(String password) => hashPassword(password);

  String _authError(AuthException e) {
    final code = e.code ?? '';
    final msg = e.message.toLowerCase();
    if (code == 'invalid_credentials' || msg.contains('invalid login credentials')) {
      return 'رقم الهاتف أو كلمة المرور غير صحيحة';
    }
    if (code == 'user_already_exists' ||
        msg.contains('already registered') ||
        msg.contains('already exists')) {
      return 'رقم الهاتف مستخدم مسبقاً';
    }
    if (code == 'weak_password' || msg.contains('password should be')) {
      return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    }
    if (code == 'email_not_confirmed' || msg.contains('not confirmed')) {
      return 'الحساب غير مؤكد. أوقف «تأكيد البريد» في إعدادات Supabase';
    }
    if (code == 'over_email_send_rate_limit' || msg.contains('rate limit')) {
      return 'محاولات كثيرة، انتظر قليلاً ثم أعد المحاولة';
    }
    if (msg.contains('socket') || msg.contains('connection')) {
      return 'تعذر الاتصال بالإنترنت، تحقق من الشبكة';
    }
    return 'تعذر إكمال العملية، حاول مرة أخرى';
  }

  @override
  void dispose() {
    repo.close();
    super.dispose();
  }
}
