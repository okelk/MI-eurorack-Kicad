# Convert-EagleToV7.ps1
#
# For every *-unmodified folder found under RootPath, converts the .brd file
# inside to EAGLE v7 XML format, saving the result in a sibling *-eagle7 folder.
#
# Example result:
#   pcb\ripples_v40-unmodified\ripples_v40.brd
#   --> pcb\ripples_v40-eagle7\ripples_v40.brd  (v7 XML)
#   --> pcb\ripples_v40-eagle7\ripples_v40.sch  (v7 XML)
#
# Usage:
#   .\Convert-EagleToV7.ps1 -RootPath "C:\path\to\MI-eurorack-Kicad"
#   .\Convert-EagleToV7.ps1 -RootPath "C:\path\to\MI-eurorack-Kicad" -WhatIf
#
# Requirements: EAGLE 9.6 installed at the default path below, or override with -EaglePath.

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$RootPath,

    [string]$EaglePath = "C:\Program Files\EAGLE 9.6.2\eagle.exe",

    # Temporary .scr file location (auto-cleaned up after each run)
    [string]$TempScr = "$env:TEMP\eagle_convert.scr"
)

# Verify EAGLE exists
if (-not (Test-Path $EaglePath)) {
    Write-Error "EAGLE not found at: $EaglePath`nUse -EaglePath to specify the correct path."
    exit 1
}

# Find all .brd files inside *-unmodified folders
$brdFiles = Get-ChildItem -Path $RootPath -Recurse -Filter "*.brd" |
            Where-Object { $_.Directory.Name -like "*-unmodified" }

if (-not $brdFiles) {
    Write-Host "No .brd files found inside '*-unmodified' folders under: $RootPath"
    exit
}

$total   = @($brdFiles).Count
$current = 0

foreach ($brd in $brdFiles) {
    $current++
    $stem      = $brd.BaseName                              # e.g. ripples_v40
    $pcbDir    = $brd.Directory.Parent.FullName             # e.g. ...\pcb
    $eagle7Dir = Join-Path $pcbDir "$stem-eagle7"           # e.g. ...\pcb\ripples_v40-eagle7
    $outStem   = ($eagle7Dir + "\" + $stem) -replace "\\","/"  # forward slashes for EAGLE

    Write-Host ""
    Write-Host "[$current/$total] $stem"
    Write-Host "  Source : $($brd.FullName)"
    Write-Host "  Output : $eagle7Dir"

    if ($PSCmdlet.ShouldProcess($brd.FullName, "Convert to EAGLE v7 in $eagle7Dir")) {

        # Create output dir
        New-Item -ItemType Directory -Path $eagle7Dir -Force | Out-Null

        # Write the per-file EAGLE script
        @"
SET CONFIRM YES;
WRITE 7 '$outStem';
"@ | Set-Content -Path $TempScr -Encoding ASCII

        # Run EAGLE with the script and the source .brd
        $proc = Start-Process `
            -FilePath $EaglePath `
            -ArgumentList "-S `"$TempScr`"", "`"$($brd.FullName)`"" `
            -PassThru `
            -Wait

        # Check output
        $outBrd = Join-Path $eagle7Dir "$stem.brd"
        $outSch = Join-Path $eagle7Dir "$stem.sch"

        if (Test-Path $outBrd) {
            # Clean up EAGLE backup files (*b#1, *.s#1, etc.)
            Get-ChildItem -Path $eagle7Dir | Where-Object { $_.Name -match '\.[bs]#\d+$' } | Remove-Item -Force
            Write-Host "  OK: $stem.brd + $stem.sch" -ForegroundColor Green
        } else {
            Write-Host "  WARNING: Expected output not found - EAGLE may have shown a dialog" -ForegroundColor Yellow
        }
    }
}

# Clean up temp script
if (Test-Path $TempScr) { Remove-Item $TempScr -Force }

Write-Host ""
Write-Host "Done. Converted $total file(s)."
