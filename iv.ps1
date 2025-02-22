<#
.SYNOPSIS
Converts a file to Base64, translates it to Morse code, and signals it via Caps Lock LED.

.DESCRIPTION
This script reads a file, converts its content to a Base64 string, translates each character to Morse code, and uses the Caps Lock LED to signal each Morse code character with specified timing.

.PARAMETER FilePath
The path to the target file.

.PARAMETER UnitDuration
The duration of one time unit in milliseconds (default is 200ms).

.EXAMPLE
PS> .\MorseCodeSignaler.ps1 -FilePath "C:\example.txt" -UnitDuration 200
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath,
    [int]$UnitDuration = 200
)

# Add C# code to toggle Caps Lock
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class KeyboardSend {
    [DllImport("user32.dll")]
    private static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
    public static void ToggleCapsLock() {
        keybd_event(0x14, 0x45, 0x1, (UIntPtr)0);
        keybd_event(0x14, 0x45, 0x1 | 0x2, (UIntPtr)0);
    }
}
"@

# Morse code lookup table
$morseTable = @{
    'A' = '.-';    'B' = '-...';  'C' = '-.-.';  'D' = '-..';   'E' = '.';     'F' = '..-.';
    'G' = '--.';   'H' = '....';  'I' = '..';    'J' = '.---';  'K' = '-.-';   'L' = '.-..';
    'M' = '--';    'N' = '-.';    'O' = '---';   'P' = '.--.';  'Q' = '--.-';  'R' = '.-.';
    'S' = '...';   'T' = '-';     'U' = '..-';   'V' = '...-';  'W' = '.--';   'X' = '-..-';
    'Y' = '-.--';  'Z' = '--..';  '0' = '-----'; '1' = '.----'; '2' = '..---'; '3' = '...--';
    '4' = '....-'; '5' = '.....'; '6' = '-....'; '7' = '--...'; '8' = '---..'; '9' = '----.';
    '+' = '.-.-.'; '/' = '-..-.'; '=' = '-...-'
}

# Read and convert file to Base64
try {
    $fileBytes = [IO.File]::ReadAllBytes($FilePath)
    $base64String = [Convert]::ToBase64String($fileBytes)
}
catch {
    Write-Error "Failed to read or convert file: $_"
    exit 1
}

# Caps Lock control functions
$initialCaps = [Console]::CapsLock
$script:CapsState = $initialCaps

function Set-CapsLock($state) {
    if ($state -eq $script:CapsState) { return }
    [KeyboardSend]::ToggleCapsLock()
    $script:CapsState = -not $script:CapsState
}

# Ensure Caps Lock is initially Off
try {
    while ([Console]::CapsLock) {
        [KeyboardSend]::ToggleCapsLock()
    }
    $script:CapsState = $false

    # Process each character in Base64 string
    foreach ($char in $base64String.ToUpperInvariant().ToCharArray()) {
        if (-not $morseTable.ContainsKey($char)) {
            Write-Warning "Skipping unsupported character: $char"
            continue
        }

        $morseCode = $morseTable[$char]
        $elements = $morseCode.ToCharArray() | Where-Object { $_ -eq '.' -or $_ -eq '-' }
        $elementCount = $elements.Count

        for ($i = 0; $i -lt $elementCount; $i++) {
            $element = $elements[$i]
            $duration = if ($element -eq '.') { $UnitDuration } else { 3 * $UnitDuration }

            # Signal the element
            Set-CapsLock $true
            Start-Sleep -Milliseconds $duration
            Set-CapsLock $false

            # Pause between elements or characters
            if ($i -lt ($elementCount - 1)) {
                Start-Sleep -Milliseconds $UnitDuration
            } else {
                Start-Sleep -Milliseconds (3 * $UnitDuration)
            }
        }
    }
}
finally {
    # Restore initial Caps Lock state
    if ($script:CapsState -ne $initialCaps) {
        [KeyboardSend]::ToggleCapsLock()
    }
}