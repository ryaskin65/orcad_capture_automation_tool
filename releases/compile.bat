@echo off
set csc="C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe"
if exist %csc% (
    %csc% /target:exe /out:LayoutSwitcher.exe LayoutSwitcher.cs
    echo Compiled successfully!
) else (
    echo .NET Framework not found!
)