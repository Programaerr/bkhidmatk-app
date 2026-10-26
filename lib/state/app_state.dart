import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database.dart';
import '../data/models.dart';
import '../data/repository.dart';

class AppState extends ChangeNotifier {
  final Repository repo = Repository();

  AppUser? user;
  bool booting = true;
  ThemeMode themeMode = ThemeMode.light;

  bool get isLoggedIn => user != null;
  bool get isAdmin => user?.isAdmin ?? false;

  Future<void> boot() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('theme');
    themeMode = savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
    final userId = prefs.getInt('user_id');
    if (userId != null) {
      user = await repo.userById(userId);
    }
    booting = false;
    notifyListeners();
  }

  Future<String?> login(String phone, String password) async {
    final found = await repo.findUserByPhone(phone);
    if (found == null) return 'لا يوجد حساب مسجل بهذا الرقم';
    if (found.passwordHash != hashPassword(password)) return 'كلمة المرور غير صحيحة';
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
    if (await repo.phoneExists(phone)) return 'رقم الهاتف مستخدم مسبقاً';
    final newUser = AppUser(
      name: name.trim(),
      phone: phone,
      passwordHash: hashPassword(password),
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

  Future<void> logout() async {
    user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    notifyListeners();
  }

  Future<void> refreshUser() async {
    if (user?.id == null) return;
    user = await repo.userById(user!.id!);
    notifyListeners();
  }
}
