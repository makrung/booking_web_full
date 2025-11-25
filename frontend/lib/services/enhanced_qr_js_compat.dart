// Conditional export: use web implementation on Flutter Web, stub elsewhere
export 'enhanced_qr_js_compat_stub.dart'
  if (dart.library.html) 'enhanced_qr_js_compat_web.dart';
