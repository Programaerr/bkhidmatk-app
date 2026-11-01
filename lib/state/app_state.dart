import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils.dart';
import '../data/database.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../data/repository_local.dart';
import '../data/repository_supabase.dart';
import '../data/supabase_services.dart';

/// جلسة التطبيق والإعدادات؛ مصادقة الهاتف اختيارية عبر Supabase.
class AppState extends ChangeNotifier {
  AppState({
    Repository? repository,
    this.cloudServices,
    this.developmentAdminPreview = false,
  }) : repo = repository ??
            (cloudServices == null
                ? LocalRepository()
                : SupabaseRepository(cloudServices.client));

  final Repository repo;
  final SupabaseServices? cloudServices;
  final bool developmentAdminPreview;

  bool get usesCloudAuth => cloudServices != null;

  AppUser? user;
  bool booting = true;
  ThemeMode themeMode = ThemeMode.light;

  /// لغة الشاشة الأولى؛ بقية الشاشات عربية حالياً.
  bool english = false;

  bool get isLoggedIn => user != null;
  bool get isAdmin => user?.isAdmin ?? false;

  /// موظف بالتوضيف: يظهر له فقط ما تسمح به الإدارة (أعمالنا + حسابه).
  bool get isWorker => user?.isWorker ?? false;

  Future<void> boot() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('theme');
    themeMode = savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
    english = prefs.getBool('english') ?? false;

    if (developmentAdminPreview) {
      user = AppUser(
        id: 1,
        name: 'أحمد سعد',
        phone: '07701234567',
        passwordHash: '',
        role: 'customer',
        city: 'بغداد',
        createdAt: DateTime.utc(2026),
      );
      booting = false;
      notifyListeners();
      return;
    }

    if (cloudServices != null) {
      if (cloudServices!.isSignedIn) {
        try {
          await cloudServices!.claimAdminRole();
          user = await cloudServices!.currentProfile();
        } catch (error) {
          debugPrint('Failed to restore the Supabase session: $error');
          await cloudServices!.signOut();
          user = null;
        }
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

  Future<String?> login(String phone, String password) async {
    final cloud = cloudServices;
    if (cloud != null) {
      try {
        user = await cloud.signInWithPassword(normalizePhone(phone), password);
        notifyListeners();
        return null;
      } catch (error) {
        return error.toString();
      }
    }
    final found = await repo.findUserByPhone(phone);
    if (found == null) return 'لا يوجد حساب مسجل بهذا الرقم';
    if (found.passwordHash != hashPassword(password)) {
      return 'كلمة المرور غير صحيحة';
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
    final cloud = cloudServices;
    if (cloud != null) {
      try {
        user = await cloud.signUpWithPassword(
          phone: normalizePhone(phone),
          password: password,
          name: name,
          city: city,
          address: address,
        );
        notifyListeners();
        return null;
      } catch (error) {
        return error.toString();
      }
    }
    if (await repo.phoneExists(phone)) return 'رقم الهاتف مستخدم مسبقاً';
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

  void openDevelopmentAdmin() {
    if (!developmentAdminPreview) return;
    final current = user;
    if (current == null) return;
    user = AppUser(
      id: current.id,
      name: 'مدير جايك',
      phone: current.phone,
      passwordHash: current.passwordHash,
      role: 'admin',
      city: current.city,
      address: current.address,
      avatarPath: current.avatarPath,
      createdAt: current.createdAt,
    );
    notifyListeners();
  }

  void returnToDevelopmentCustomer() {
    if (!developmentAdminPreview) return;
    final current = user;
    if (current == null) return;
    user = AppUser(
      id: current.id,
      name: 'أحمد سعد',
      phone: current.phone,
      passwordHash: current.passwordHash,
      role: 'customer',
      city: current.city,
      address: current.address,
      avatarPath: current.avatarPath,
      createdAt: current.createdAt,
    );
    notifyListeners();
  }

  Future<void> setTheme(bool dark) async {
    themeMode = dark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', dark ? 'dark' : 'light');
    notifyListeners();
  }

  Future<void> setEnglish(bool value) async {
    english = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('english', value);
    notifyListeners();
  }

  Future<void> logout() async {
    await cloudServices?.signOut();
    user = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
  }

  /// إعادة تحميل بيانات المستخدم الحالي.
  Future<void> refreshUser() async {
    if (user?.id == null) return;
    try {
      if (cloudServices != null && cloudServices!.isSignedIn) {
        await cloudServices!.claimAdminRole();
        user = await cloudServices!.currentProfile();
      } else {
        user = await repo.userById(user!.id!);
      }
      notifyListeners();
    } catch (error) {
      debugPrint('Failed to refresh the current user: $error');
    }
  }

  @override
  void dispose() {
    repo.close();
    super.dispose();
  }
}
