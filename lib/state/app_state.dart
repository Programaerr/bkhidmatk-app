import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/language.dart';
import '../data/database.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../data/repository_local.dart';
import '../data/repository_supabase.dart';
import '../data/supabase_services.dart';

/// حالة التطبيق — تعمل بالكامل محلياً على الجهاز (SQLite).
class AppState extends ChangeNotifier {
  AppState({Repository? repository, this.cloudServices})
      : repo = repository ??
            (cloudServices == null
                ? LocalRepository()
                : SupabaseRepository(cloudServices.client));

  final Repository repo;
  final SupabaseServices? cloudServices;

  bool get usesCloudAuth => cloudServices != null;

  AppUser? user;
  bool booting = true;
  ThemeMode themeMode = ThemeMode.light;

  /// لغة التطبيق كله: الإنجليزية أو العربية.
  bool get english => appEnglish;

  bool get isLoggedIn => user != null;
  bool get isAdmin => user?.isAdmin ?? false;

  /// موظف بالتوضيف: يظهر له فقط ما تسمح به الإدارة (أعمالنا + حسابه).
  bool get isWorker => user?.isWorker ?? false;

  Future<void> boot() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('theme');
    themeMode = savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
    appEnglish = prefs.getBool('english') ?? false;

    if (cloudServices != null) {
      if (cloudServices!.isSignedIn) {
        // انتظار السيرفر لا يؤخر فتح التطبيق: تظهر شاشة البداية حتى يصل الحساب.
        unawaited(_restoreCloudSession());
        return;
      }
      booting = false;
      notifyListeners();
      return;
    }

    try {
      final userId = prefs.getInt('user_id');
      if (userId != null) user = await repo.userById(userId);
    } catch (_) {
      user = null;
    }

    booting = false;
    notifyListeners();
  }

  Future<void> _restoreCloudSession() async {
    try {
      user = await cloudServices!.currentProfile();
    } catch (error, stackTrace) {
      debugPrint('Failed to restore Supabase session: $error');
      debugPrintStack(stackTrace: stackTrace);
      await cloudServices!.signOut();
    } finally {
      booting = false;
      notifyListeners();
    }
  }

  Future<String?> login(String phone, String password) async {
    if (cloudServices != null) {
      try {
        user = await cloudServices!.signInWithPassword(phone, password);
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('user_id');
        notifyListeners();
        return null;
      } on CloudAuthException catch (error) {
        return error.message;
      } catch (error, stackTrace) {
        debugPrint('Supabase login failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        return tr('تعذر الاتصال بقاعدة البيانات. تحقق من الإنترنت وحاول مجدداً.', "Couldn't reach the database. Check your internet and try again.");
      }
    }

    final found = await repo.findUserByPhone(phone);
    if (found == null) return tr('لا يوجد حساب مسجل بهذا الرقم', 'No account is registered with this number');
    if (found.passwordHash != hashPassword(password)) {
      return tr('كلمة المرور غير صحيحة', 'Incorrect password');
    }
    user = found;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', found.id!);
    notifyListeners();
    return null;
  }

  Future<String?> register({
    required String name,
    required String phone,
    required String password,
    String? city,
    String? address,
  }) async {
    if (cloudServices != null) {
      try {
        user = await cloudServices!.signUpWithPassword(
          phone: phone,
          password: password,
          name: name,
          city: city,
          address: address,
        );
        notifyListeners();
        return null;
      } on CloudAuthException catch (error) {
        return error.message;
      } catch (error, stackTrace) {
        debugPrint('Supabase registration failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        return tr('تعذر إنشاء الحساب. تحقق من الاتصال وإعدادات Supabase.', "Couldn't create the account. Check the connection and the Supabase settings.");
      }
    }

    if (await repo.phoneExists(phone)) return tr('رقم الهاتف مستخدم مسبقاً', 'This phone number is already in use');
    // الرقم المُضاف من الإدارة للتوظيف → الحساب يُسجّل كـ (حرفي).
    final hired = await repo.isHiredPhone(phone);
    final role = hired ? 'worker' : 'customer';
    final newUser = AppUser(
      name: name.trim(),
      phone: phone,
      passwordHash: hashPassword(password),
      role: role,
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
      role: role,
      city: city,
      address: address,
      createdAt: newUser.createdAt,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', id);
    notifyListeners();
    return null;
  }

  Future<void> updateProfile(AppUser updated) async {
    await repo.updateUser(updated);
    user = updated;
    notifyListeners();
  }

  Future<void> setTheme(bool dark) async {
    themeMode = dark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', dark ? 'dark' : 'light');
    notifyListeners();
  }

  Future<void> setEnglish(bool value) async {
    appEnglish = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('english', value);
    notifyListeners();
    // الصفحات المحفوظة خلف غيرها تُبنى من جديد أيضاً، فلا يبقى فيها نص بلغة سابقة.
    rebuildForLanguage();
  }

  Future<void> logout() async {
    if (cloudServices != null) await cloudServices!.signOut();
    user = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
  }

  /// إعادة تحميل بيانات المستخدم الحالي.
  Future<void> refreshUser() async {
    if (user?.id == null) return;
    try {
      user = await repo.userById(user!.id!);
      notifyListeners();
    } catch (error, stackTrace) {
      debugPrint('Failed to refresh current user: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  void dispose() {
    repo.close();
    super.dispose();
  }
}
