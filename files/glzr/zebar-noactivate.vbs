' Starts zebar-noactivate.ps1 without showing any window (called from GlazeWM startup_commands).
CreateObject("WScript.Shell").Run "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{{GLZR_WIN}}\zebar-noactivate.ps1""", 0, False
