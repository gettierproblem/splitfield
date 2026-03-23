@echo off
echo Building C# project...
dotnet build
if errorlevel 1 (
    echo Build failed!
    pause
    exit /b 1
)

echo Exporting for Web...
"C:\Users\Verit\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine.Mono_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64_console.exe" --headless --export-release "Web" "build/web/index.html" --path "C:\Users\Verit\barrack"
if errorlevel 1 (
    echo Export failed!
    pause
    exit /b 1
)

echo.
echo Export complete! Files are in build\web\
echo To test locally, run: npx serve build\web
pause
