' Starts taskbar-startup.ps1 without showing any window (used by the autostart entry).
CreateObject("WScript.Shell").Run "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{{GLZR_WIN}}\taskbar-startup.ps1""", 0, False
