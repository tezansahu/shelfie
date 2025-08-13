@echo off
echo Starting Shelfie Phase 1 Setup...
echo.

echo 1. Setting up Flutter dependencies...
cd flutter-app
call flutter pub get
if %errorlevel% neq 0 (
    echo Error: Flutter pub get failed
    pause
    exit /b 1
)

echo 2. Running code generation...
call flutter pub run build_runner build
if %errorlevel% neq 0 (
    echo Error: Code generation failed
    pause
    exit /b 1
)

echo 3. Building for Windows...
call flutter build windows --release
if %errorlevel% neq 0 (
    echo Error: Windows build failed
    pause
    exit /b 1
)

cd ..

echo.
echo ✅ Phase 1 setup complete!
echo.
echo Next steps:
echo 1. Set up your Supabase project using the SQL migration
echo 2. Deploy the Edge Function: supabase functions deploy save-url
echo 3. Configure the browser extension with your Supabase credentials
echo 4. Update flutter-app/lib/main.dart with your Supabase settings
echo.
echo The Windows app is built in: flutter-app/build/windows/x64/runner/Release/
echo.
pause
