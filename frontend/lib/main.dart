import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'EmailVerificationSuccessPage.dart';
import 'widgets/route_handler.dart';
import 'widgets/session_persistent_wrapper.dart';
import 'services/auth_state_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'NewsPage.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('th_TH', null);
  
  // เริ่มต้น Auth State Manager
  await AuthStateManager().initialize();
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SessionPersistentWrapper(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(primarySwatch: Colors.teal),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        initialRoute: '/',
        onGenerateRoute: (settings) {
        // Handle routes with parameters
        if (settings.name == '/verification-success') {
          return MaterialPageRoute(
            builder: (context) => FutureBuilder<Map<String, String?>>(
              future: _getVerificationData(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final data = snapshot.data!;
                  return EmailVerificationSuccessPage(
                    token: _getTokenFromUrl(settings.arguments as String?),
                    email: data['email'],
                    password: data['password'],
                  );
                }
                return Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              },
            ),
          );
        }
        return null;
      },
        routes: {
          '/': (context) => RouteHandler(routeName: '/'),
          '/login': (context) => RouteHandler(routeName: '/login'),
          '/user-home': (context) => RouteHandler(routeName: '/user-home'),
          '/admin-dashboard': (context) => RouteHandler(routeName: '/admin-dashboard'),
          '/news': (context) => NewsPage(),
        },
      ),
    );
  }

  String? _getTokenFromUrl(String? arguments) {
    if (arguments == null) return null;
    final uri = Uri.parse(arguments);
    return uri.queryParameters['token'];
  }

  Future<Map<String, String?>> _getVerificationData() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('temp_email');
    final password = prefs.getString('temp_password');
    
    return {
      'email': email,
      'password': password,
    };
  }
}
