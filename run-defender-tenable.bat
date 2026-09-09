@echo off
title Defender-Tenable Security Automation

powershell.exe -ExecutionPolicy Bypass -File "%~dp0src\defender-tenable-scanner.ps1"

pause