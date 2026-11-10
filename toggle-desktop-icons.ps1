# Blendet Desktop-Symbole aus/ein, ohne Explorer neu zu starten.
#   -Hide : ausblenden (Standard)   -Show : einblenden
# Mechanik: WM_COMMAND 0x7402 an SHELLDLL_DefView (entspricht "Ansicht > Desktopsymbole anzeigen").
param([switch]$Show)
$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class DeskIcons {
    [DllImport("user32.dll", SetLastError=true)] static extern IntPtr FindWindow(string c, string w);
    [DllImport("user32.dll", SetLastError=true)] static extern IntPtr FindWindowEx(IntPtr p, IntPtr a, string c, string w);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
    delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr l);

    static IntPtr FindDefView() {
        IntPtr v = FindWindowEx(FindWindow("Progman", null), IntPtr.Zero, "SHELLDLL_DefView", null);
        if (v != IntPtr.Zero) return v;
        IntPtr found = IntPtr.Zero;
        EnumWindows((h, l) => {
            IntPtr d = FindWindowEx(h, IntPtr.Zero, "SHELLDLL_DefView", null);
            if (d != IntPtr.Zero) { found = d; return false; }
            return true;
        }, IntPtr.Zero);
        return found;
    }
    public static int State() {
        IntPtr v = FindDefView();
        if (v == IntPtr.Zero) return -1;
        IntPtr lv = FindWindowEx(v, IntPtr.Zero, "SysListView32", null);
        return (lv != IntPtr.Zero && IsWindowVisible(lv)) ? 1 : 0;
    }
    public static void Toggle() {
        IntPtr v = FindDefView();
        if (v == IntPtr.Zero) throw new InvalidOperationException("SHELLDLL_DefView nicht gefunden");
        SendMessage(v, 0x0111, (IntPtr)0x7402, IntPtr.Zero);
    }
}
"@

$want = if ($Show) { 1 } else { 0 }
$state = [DeskIcons]::State()
if ($state -lt 0) { throw 'Desktop-Fenster nicht gefunden.' }
if ($state -ne $want) { [DeskIcons]::Toggle(); Start-Sleep -Milliseconds 400 }
$after = [DeskIcons]::State()
Write-Host ("Desktop-Symbole: vorher={0} nachher={1} (1=sichtbar)" -f $state, $after)
if ($after -ne $want) { throw "Umschalten fehlgeschlagen (Status $after)." }
