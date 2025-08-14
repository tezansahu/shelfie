@echo off
echo ========================================
echo Shelfie Phase 3 Setup - Analytics System
echo ========================================
echo.

echo Step 1: Installing Flutter dependencies...
cd flutter-app
call flutter pub get
if %errorlevel% neq 0 (
    echo Error: Failed to install Flutter dependencies
    pause
    exit /b 1
)

echo.
echo Step 2: Generating code files...
call dart run build_runner build
if %errorlevel% neq 0 (
    echo Error: Failed to generate code files
    pause
    exit /b 1
)

echo.
echo Step 3: Database Migration...
echo Please run the following SQL migration in your Supabase dashboard:
echo File: backend/supabase/migrations/20250814000003_add_analytics_system.sql
echo.
echo This migration adds:
echo - Events table for analytics tracking
echo - Auto-logging triggers for all item actions
echo - analytics_summary() RPC function
echo - Historical data backfill
echo.

echo Step 4: Verification...
echo.
echo To verify Phase 3 setup:
echo 1. Check that the Analytics tab appears in the app
echo 2. Navigate to Analytics tab and verify metrics load
echo 3. Test date range selector functionality
echo 4. Verify charts display correctly
echo 5. Add/complete items and watch analytics update
echo.

echo ========================================
echo Phase 3 Setup Complete!
echo ========================================
echo.
echo Phase 3 Features:
echo ✓ Comprehensive analytics dashboard
echo ✓ Interactive charts with fl_chart
echo ✓ Metrics tiles (pending, completed, rates)
echo ✓ Weekly completion trends
echo ✓ Top tags and domains analysis
echo ✓ Backlog age distribution
echo ✓ Streak tracking and motivation
echo ✓ Configurable date ranges
echo ✓ Automatic event logging
echo ✓ Real-time data updates
echo.
echo Next: Run your app and check the Analytics tab!
echo.
pause
