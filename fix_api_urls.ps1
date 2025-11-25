# Fix all hardcoded localhost:3000 URLs in Dart files

$files = @(
    "frontend\lib\services\penalty_service.dart",
    "frontend\lib\services\booking_service.dart",
    "frontend\lib\services\api_service.dart",
    "frontend\lib\services\court_management_service.dart",
    "frontend\lib\services\admin_service.dart",
    "frontend\lib\services\admin_auth_service.dart",
    "frontend\lib\services\activity_service.dart"
)

foreach ($file in $files) {
    $fullPath = Join-Path $PSScriptRoot $file
    if (Test-Path $fullPath) {
        $content = Get-Content $fullPath -Raw
        
        # Add import if not exists
        if ($content -notmatch "import.*app_config\.dart") {
            $content = $content -replace "(import.*\n)", "`$1import '../config/app_config.dart';`n"
        }
        
        # Replace const baseUrl with getter
        $content = $content -replace "static const String baseUrl = 'http://localhost:3000/api';", "static String get baseUrl => AppConfig.apiBaseUrl;"
        
        Set-Content $fullPath -Value $content -NoNewline
        Write-Host "Fixed: $file"
    }
}

Write-Host "Done!"
