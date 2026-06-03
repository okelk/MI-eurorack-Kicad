# Reorganize-EaglePCB.ps1
#
# Moves each .brd and .sch file inside a "pcb" folder into its own
# subfolder named "<filename-without-extension>-unmodified".
#
# Example:
#   pcb\ripples_v40.brd  -->  pcb\ripples_v40-unmodified\ripples_v40.brd
#   pcb\ripples_v40.sch  -->  pcb\ripples_v40-unmodified\ripples_v40.sch
#
# Usage:
#   .\Reorganize-EaglePCB.ps1 -RootPath "C:\path\to\MI-eurorack-Kicad"
#   .\Reorganize-EaglePCB.ps1 -RootPath "C:\path\to\MI-eurorack-Kicad" -WhatIf
#
# Add -WhatIf to preview all moves without touching anything.

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$RootPath
)

# Find every .brd and .sch whose immediate parent folder is named "pcb"
$files = Get-ChildItem -Path $RootPath -Recurse -Include "*.brd","*.sch" |
         Where-Object { $_.Directory.Name -eq "pcb" }

if (-not $files) {
    Write-Host "No .brd or .sch files found inside 'pcb' folders under: $RootPath"
    exit
}

# Group by stem (filename without extension) so .brd and .sch pairs are
# reported together, then move each file into its own subfolder.
$grouped = $files | Group-Object { $_.BaseName }

foreach ($group in $grouped) {
    $stem      = $group.Name                          # e.g. ripples_v40
    $targetDir = Join-Path $group.Group[0].Directory.FullName "$stem-unmodified"

    Write-Host "`n[$stem]"
    Write-Host "  -> $targetDir"

    foreach ($file in $group.Group) {
        $dest = Join-Path $targetDir $file.Name
        if ($PSCmdlet.ShouldProcess($file.FullName, "Move to $dest")) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            Move-Item -Path $file.FullName -Destination $dest
            Write-Host "     Moved: $($file.Name)"
        } else {
            # -WhatIf path
            Write-Host "     WhatIf: would move $($file.Name)"
        }
    }
}

Write-Host "`nDone."
