/// Configuration constants for the application
/// Centralized configuration to avoid duplication across services
class AppConfig {
  // Prevent instantiation
  AppConfig._();

  // API Configuration
  // Use relative path for production (works on same domain)
  static const String apiBaseUrl = '/api';
  static const String frontendUrl = '';
  
  // Timeout Configuration
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration longApiTimeout = Duration(minutes: 2);
  
  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userDataKey = 'user_data';
  static const String isLoggedInKey = 'is_logged_in';
  
  // QR Upload Mode
  static const String qrUploadModeKey = 'qr_upload_mode_enabled';
  static const String adminBookingModeKey = 'admin_booking_mode_enabled';
  static const String testModeKey = 'test_mode_enabled';
  
  // Location Settings
  static const String isTestModeKey = 'location_test_mode';
  static const String testLocationLatKey = 'test_location_lat';
  static const String testLocationLngKey = 'test_location_lng';
  
  // Booking Rules
  static const int maxOutdoorBookingsPerDay = 1;
  static const int maxIndoorBookingsPerDay = 1;
  static const int advanceBookingDays = 7;
  static const int activityRequestExpireDays = 30;
  
  // Points Configuration
  static const int bookingCost = 2;
  static const int registrationBonus = 10;
  static const int penaltyPoints = 5;
  
  // Geolocation Configuration
  static const double maxCheckInDistance = 100.0; // meters
  
  // API Endpoints
  static String get authLogin => '$apiBaseUrl/auth/login';
  static String get authRegister => '$apiBaseUrl/auth/register';
  static String get authVerifyEmail => '$apiBaseUrl/auth/verify-email';
  static String get bookings => '$apiBaseUrl/bookings';
  static String get activities => '$apiBaseUrl/activities';
  static String get penalties => '$apiBaseUrl/penalties';
  static String get admin => '$apiBaseUrl/admin';
}
