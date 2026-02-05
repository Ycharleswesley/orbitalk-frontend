@echo off
echo Setting up environment for OrbiTalk Frontend...
set "PATH=%PATH%;C:\src\flutter\bin;C:\Program Files\Git\cmd"
echo Starting Frontend...
echo Note: This requires an emulator or connected device.
flutter run
pause
