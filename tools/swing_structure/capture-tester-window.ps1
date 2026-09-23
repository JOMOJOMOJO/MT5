param([Parameter(Mandatory=$true)][int]$TesterPid,[Parameter(Mandatory=$true)][string]$OutputPath)
$ErrorActionPreference='Stop'
$process=Get-Process -Id $TesterPid
if(-not $process.Path.StartsWith([IO.Path]::GetFullPath($env:TEMP),[StringComparison]::OrdinalIgnoreCase) -or
   $process.MainWindowTitle -notlike 'Strategy Tester Visualization*'){throw 'Only dedicated tester visualizer may be captured'}
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class TWCapture {
 [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L,T,R,B; }
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h,out RECT r);
 [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h,IntPtr dc,uint flags);
}
'@
$rect=New-Object TWCapture+RECT
$handle=$process.MainWindowHandle
if(-not [TWCapture]::GetWindowRect($handle,[ref]$rect)){throw 'Window size unavailable'}
$bitmap=New-Object Drawing.Bitmap(($rect.R-$rect.L),($rect.B-$rect.T))
$graphics=[Drawing.Graphics]::FromImage($bitmap)
$dc=$graphics.GetHdc()
try{$ok=[TWCapture]::PrintWindow($handle,$dc,2)}finally{$graphics.ReleaseHdc($dc)}
if(-not $ok){throw 'PrintWindow failed'}
$bitmap.Save([IO.Path]::GetFullPath($OutputPath),[Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose();$bitmap.Dispose()
Write-Output ('Captured dedicated tester PID='+$TesterPid)
