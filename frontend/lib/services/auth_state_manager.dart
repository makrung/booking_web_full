import 'dart:async';
import 'package:flutter/material.dart';
import 'auth_service.dart';

class AuthStateManager extends ChangeNotifier {
  static final AuthStateManager _instance = AuthStateManager._internal();
  factory AuthStateManager() => _instance;
  AuthStateManager._internal();

  bool _isLoggedIn = false;
  bool _isAdmin = false;
  bool _isLoading = true;
  Map<String, dynamic>? _currentUser;
  Timer? _authCheckTimer;
  bool _checking = false;
  DateTime? _lastValidAt;

  bool get isLoggedIn => _isLoggedIn;
  bool get isAdmin => _isAdmin;
  bool get isLoading => _isLoading;
  Map<String, dynamic>? get currentUser => _currentUser;

  // เริ่มต้นตรวจสอบ auth state
  Future<void> initialize() async {
    await _checkAuthState();
    _startPeriodicCheck();
  }

  // ตรวจสอบ auth state
  Future<void> _checkAuthState() async {
    try {
      if (_checking) return; // prevent overlapping checks
      _checking = true;
      _isLoading = true;
      notifyListeners();

      final isLoggedIn = await AuthService.isLoggedIn();
      Map<String, dynamic>? currentUser;
      bool isAdmin = false;
      if (isLoggedIn) {
        // try to get user; if connection error, keep last known state briefly
        try {
          currentUser = await AuthService.getCurrentUser();
          isAdmin = (currentUser?['role'] == 'admin');
          _lastValidAt = DateTime.now();
        } catch (_) {
          // tolerate brief outages for up to 60s
          if (_lastValidAt != null && DateTime.now().difference(_lastValidAt!).inSeconds < 60) {
            currentUser = _currentUser;
            isAdmin = _isAdmin;
          } else {
            isAdmin = await AuthService.isAdmin();
          }
        }
      }

      _isLoggedIn = isLoggedIn;
      _isAdmin = isAdmin;
      _currentUser = currentUser;
      _isLoading = false;

      notifyListeners();
      print('AuthStateManager: Updated state - logged in: $_isLoggedIn, admin: $_isAdmin');
    } catch (e) {
      print('AuthStateManager: Error checking auth state: $e');
      _isLoggedIn = false;
      _isAdmin = false;
      _currentUser = null;
      _isLoading = false;
      notifyListeners();
    } finally {
      _checking = false;
    }
  }

  // เริ่มต้นการตรวจสอบแบบ periodic
  void _startPeriodicCheck() {
    _authCheckTimer?.cancel();
    _authCheckTimer = Timer.periodic(const Duration(minutes: 10), (_) => _checkAuthState());
  }

  // หยุดการตรวจสอบ periodic
  void stopPeriodicCheck() {
    _authCheckTimer?.cancel();
  }

  // อัปเดต auth state หลังจาก login
  Future<void> updateAfterLogin() async {
    await _checkAuthState();
  }

  // อัปเดต auth state หลังจาก logout
  Future<void> updateAfterLogout() async {
    _isLoggedIn = false;
    _isAdmin = false;
    _currentUser = null;
    _isLoading = false;
    notifyListeners();
  }

  // ล้างข้อมูลเมื่อ app ถูกปิด
  @override
  void dispose() {
    _authCheckTimer?.cancel();
    super.dispose();
  }

  // Force refresh auth state
  Future<void> refreshAuthState() async {
    // Debounce refresh if a check is running
    if (_checking) return;
    await _checkAuthState();
  }
}