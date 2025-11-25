import 'package:flutter/material.dart';
import '../services/auth_state_manager.dart';

class SessionPersistentWrapper extends StatefulWidget {
  final Widget child;
  
  const SessionPersistentWrapper({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  _SessionPersistentWrapperState createState() => _SessionPersistentWrapperState();
}

class _SessionPersistentWrapperState extends State<SessionPersistentWrapper> 
    with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAuthState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initializeAuthState() async {
    // เริ่มต้น auth state เมื่อ app เริ่มทำงาน
    await AuthStateManager().initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // เมื่อ app กลับมาเป็น active (เช่น refresh หรือกลับมาจาก background)
    if (state == AppLifecycleState.resumed) {
      print('SessionPersistentWrapper: App resumed, refreshing auth state');
      if (!mounted) return;
      AuthStateManager().refreshAuthState();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}