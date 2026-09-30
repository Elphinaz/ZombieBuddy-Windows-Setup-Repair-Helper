<#
ZombieBuddy Windows Setup / Repair Helper (UNOFFICIAL)
For Project Zomboid Build 42 / Windows / Steam

THIS HELPER WAS CREATED INDEPENDENTLY AS A COMMUNITY TOOL.

OFFICIAL / ORIGINAL ZOMBIEBUDDY
Author: Zed
Workshop ID: 3619862853

Files located and copied by this helper:
- ZombieBuddy.jar
- zbNative.dll

TEMPORARY B42.21 COMPATIBILITY PATCH
Author: Kaoeutsu
Workshop ID: 3809837933

File located and copied by this helper:
- patched ZombieBuddy.jar

This patch does NOT replace zbNative.dll.

PROJECT ZOMBOID GAME FOLDER
This is the destination folder where ZombieBuddy files are installed.

Example:
D:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid

WHAT THIS HELPER DOES
- DOES NOT download anything from the internet.
- DOES NOT redistribute ZombieBuddy or any compatibility patch.
- DOES NOT contain ZombieBuddy.jar, zbNative.dll, or Kaoeutsu's patched JAR.
- DOES NOT claim ownership of ZombieBuddy or the B42.21 patch.
- Uses files already downloaded by Steam Workshop.
- Reads the Windows registry only to help locate Steam.
- Can diagnose, install/repair ZombieBuddy, and apply the B42.21 temporary patch.
- Creates backups before replacing files.
- Verifies copied files with SHA-256.
- Does NOT delete game folders.
- Does NOT modify projectzomboid.jar.
- Does NOT automatically edit Steam launch options or your save/mod list.

OWNERSHIP / ATTRIBUTION
ZombieBuddy is created by Zed.
The temporary B42.21 compatibility patch is created by Kaoeutsu.
Project Zomboid is created by The Indie Stone.

This script does not contain, redistribute, or claim ownership
of either author's files.

It does not alter the contents of their files.
It only locates, backs up, and copies files already downloaded
by Steam Workshop.

This helper is NOT affiliated with, endorsed by, or an official release from:
- Zed
- Kaoeutsu
- The Indie Stone

INSTALLATION LOGIC
STEP 1 - ZED'S ZOMBIEBUDDY
Installing:
- ZombieBuddy.jar
- zbNative.dll

STEP 2 - KAOEUTSU'S B42.21 PATCH
Replacing:
- ZombieBuddy.jar ONLY

Not changing:
- zbNative.dll
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# -----------------------------
# Configuration
# -----------------------------
$PZAppId             = "108600"
$ZombieBuddyWorkshop = "3619862853"
$PatchWorkshop       = "3809837933"

$RequiredLaunchOption = "-agentlib:zbNative --"

$UserZomboidDir = Join-Path $env:USERPROFILE "Zomboid"
$ApprovalsPath  = Join-Path $env:USERPROFILE ".zombie_buddy\mod_approvals.json"
$ConsolePath    = Join-Path $UserZomboidDir "console.txt"

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logPath = Join-Path $env:TEMP "ZombieBuddyHelper-$timestamp.log"

function Write-Log {
    param(
        [Parameter(Mandatory=$true)][string]$Message,
        [ValidateSet("INFO","OK","WARN","ERROR","STEP")][string]$Level = "INFO"
    )

    $prefix = switch ($Level) {
        "OK"    { "[OK]   " }
        "WARN"  { "[WARN] " }
        "ERROR" { "[ERR]  " }
        "STEP"  { "[STEP] " }
        default { "[INFO] " }
    }

    $line = "$prefix$Message"
    Write-Host $line
    Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
}

function Write-Header {
    Clear-Host
    Write-Host ""
    Write-Host "============================================================"
    Write-Host " ZombieBuddy Windows Setup / Repair Helper"
    Write-Host " UNOFFICIAL COMMUNITY TOOL"
    Write-Host "============================================================"
    Write-Host ""
    Write-Host "OFFICIAL / ORIGINAL ZOMBIEBUDDY"
    Write-Host "  Author      : Zed"
    Write-Host "  Workshop ID : 3619862853"
    Write-Host "  Files located and copied by this helper:"
    Write-Host "  - ZombieBuddy.jar"
    Write-Host "  - zbNative.dll"
    Write-Host ""
    Write-Host "TEMPORARY B42.21 COMPATIBILITY PATCH"
    Write-Host "  Author      : Kaoeutsu"
    Write-Host "  Workshop ID : 3809837933"
    Write-Host "  File located and copied by this helper:"
    Write-Host "  - patched ZombieBuddy.jar"
    Write-Host "  NOTE        : This patch does NOT replace zbNative.dll."
    Write-Host ""
    Write-Host "This helper was created independently as a community tool."
    Write-Host "It does not contain, redistribute, modify, or claim ownership"
    Write-Host "of ZombieBuddy or the B42.21 compatibility patch."
    Write-Host "It only locates and copies files already downloaded by Steam Workshop."
    Write-Host ""
    Write-Host "Not affiliated with or endorsed by Zed, Kaoeutsu, or The Indie Stone."
    Write-Host ""
}

function Test-IsAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

function Get-SteamRoots {
    $roots = New-Object System.Collections.Generic.List[string]

    $registryPaths = @(
        "HKCU:\Software\Valve\Steam",
        "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam",
        "HKLM:\SOFTWARE\Valve\Steam"
    )

    foreach ($reg in $registryPaths) {
        try {
            $p = Get-ItemProperty -Path $reg -ErrorAction Stop
            foreach ($candidate in @($p.SteamPath, $p.InstallPath)) {
                if ($candidate -and (Test-Path -LiteralPath $candidate)) {
                    $roots.Add((Resolve-Path -LiteralPath $candidate).Path)
                }
            }
        } catch {}
    }

    foreach ($fallback in @(
        "${env:ProgramFiles(x86)}\Steam",
        "$env:ProgramFiles\Steam",
        "C:\Steam",
        "D:\Steam",
        "D:\Program Files (x86)\Steam"
    )) {
        if ($fallback -and (Test-Path -LiteralPath $fallback)) {
            $roots.Add((Resolve-Path -LiteralPath $fallback).Path)
        }
    }

    return $roots | Sort-Object -Unique
}

function Get-SteamLibraryRoots {
    param([string[]]$SteamRoots)

    $libraries = New-Object System.Collections.Generic.List[string]

    foreach ($steamRoot in $SteamRoots) {
        if (Test-Path -LiteralPath $steamRoot) {
            $libraries.Add($steamRoot)
        }

        $vdf = Join-Path $steamRoot "steamapps\libraryfolders.vdf"
        if (-not (Test-Path -LiteralPath $vdf)) {
            continue
        }

        try {
            $content = Get-Content -LiteralPath $vdf -Raw
            $matches = [regex]::Matches($content, '"path"\s+"([^"]+)"')
            foreach ($m in $matches) {
                $path = $m.Groups[1].Value -replace '\\\\','\'
                if (Test-Path -LiteralPath $path) {
                    $libraries.Add((Resolve-Path -LiteralPath $path).Path)
                }
            }
        } catch {
            Write-Log "Could not parse libraryfolders.vdf at $vdf" "WARN"
        }
    }

    return $libraries | Sort-Object -Unique
}

function Get-PZInstall {
    param([string[]]$Libraries)

    foreach ($lib in $Libraries) {
        $manifest = Join-Path $lib "steamapps\appmanifest_$PZAppId.acf"
        if (-not (Test-Path -LiteralPath $manifest)) {
            continue
        }

        try {
            $content = Get-Content -LiteralPath $manifest -Raw
            $m = [regex]::Match($content, '"installdir"\s+"([^"]+)"')
            if ($m.Success) {
                $installDir = Join-Path $lib ("steamapps\common\" + $m.Groups[1].Value)
                if (Test-Path -LiteralPath $installDir) {
                    return [PSCustomObject]@{
                        LibraryRoot = $lib
                        Manifest    = $manifest
                        InstallDir  = (Resolve-Path -LiteralPath $installDir).Path
                    }
                }
            }
        } catch {}
    }

    return $null
}

function Get-WorkshopItemPath {
    param(
        [string[]]$Libraries,
        [string]$WorkshopId
    )

    foreach ($lib in $Libraries) {
        $candidate = Join-Path $lib "steamapps\workshop\content\$PZAppId\$WorkshopId"
        if (Test-Path -LiteralPath $candidate) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    return $null
}

function Find-PreferredFile {
    param(
        [Parameter(Mandatory=$true)][string]$Root,
        [Parameter(Mandatory=$true)][string]$LeafName,
        [string[]]$PreferredPathFragments = @()
    )

    if (-not (Test-Path -LiteralPath $Root)) {
        return $null
    }

    $matches = @(Get-ChildItem -LiteralPath $Root -Recurse -File -Filter $LeafName -ErrorAction SilentlyContinue)
    if ($matches.Count -eq 0) {
        return $null
    }

    foreach ($fragment in $PreferredPathFragments) {
        $preferred = $matches | Where-Object {
            $_.FullName -like "*$fragment*"
        } | Select-Object -First 1

        if ($preferred) {
            return $preferred.FullName
        }
    }

    return ($matches | Select-Object -First 1).FullName
}

function Get-FileHashSafe {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Backup-File {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    $backup = "$Path.backup-$timestamp"
    Copy-Item -LiteralPath $Path -Destination $backup -Force
    return $backup
}

function Copy-And-Verify {
    param(
        [Parameter(Mandatory=$true)][string]$Source,
        [Parameter(Mandatory=$true)][string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        throw "Source file not found: $Source"
    }

    $sourceHash = Get-FileHashSafe $Source
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
    $destHash = Get-FileHashSafe $Destination

    if (-not $sourceHash -or -not $destHash -or $sourceHash -ne $destHash) {
        throw "SHA-256 verification failed for $Destination"
    }

    Write-Log "Verified: $Destination" "OK"
}

function Get-PZVersionFromConsole {
    if (-not (Test-Path -LiteralPath $ConsolePath)) {
        return $null
    }

    try {
        $content = Get-Content -LiteralPath $ConsolePath
        $versionLines = @($content | Where-Object { $_ -match 'version=([0-9]+\.[0-9]+(?:\.[0-9]+)?)' })
        if ($versionLines.Count -gt 0) {
            $last = $versionLines[-1]
            $m = [regex]::Match($last, 'version=([0-9]+\.[0-9]+(?:\.[0-9]+)?)')
            if ($m.Success) {
                return $m.Groups[1].Value
            }
        }
    } catch {}

    return $null
}

function Get-LaunchOptionStatus {
    param([string[]]$SteamRoots)

    $foundConfig = $false
    $foundExact = $false
    $foundAgentlib = $false
    $locations = New-Object System.Collections.Generic.List[string]

    foreach ($steamRoot in $SteamRoots) {
        $userdata = Join-Path $steamRoot "userdata"
        if (-not (Test-Path -LiteralPath $userdata)) {
            continue
        }

        $configs = @(Get-ChildItem -LiteralPath $userdata -Directory -ErrorAction SilentlyContinue |
            ForEach-Object {
                Join-Path $_.FullName "config\localconfig.vdf"
            } |
            Where-Object { Test-Path -LiteralPath $_ })

        foreach ($cfg in $configs) {
            try {
                $text = Get-Content -LiteralPath $cfg -Raw
                if ($text -match '"108600"') {
                    $foundConfig = $true
                    $locations.Add($cfg)
                }

                if ($text -like "*$RequiredLaunchOption*") {
                    $foundExact = $true
                } elseif ($text -match '-agentlib:zbNative') {
                    $foundAgentlib = $true
                }
            } catch {}
        }
    }

    return [PSCustomObject]@{
        FoundConfig  = $foundConfig
        FoundExact   = $foundExact
        FoundAgentlib= $foundAgentlib
        Locations    = ($locations | Sort-Object -Unique)
    }
}

function Show-Diagnostics {
    param(
        $PZ,
        [string]$ZBWorkshopPath,
        [string]$PatchWorkshopPath,
        [string]$BaseJar,
        [string]$BaseDll,
        [string]$PatchJar,
        $LaunchStatus
    )

    Write-Host ""
    Write-Host "==================== DIAGNOSTICS ===================="
    Write-Host ""

    Write-Host "[ZED / ZOMBIEBUDDY]"
    Write-Host "Author: Zed"
    Write-Host "Workshop ID: $ZombieBuddyWorkshop"

    if ($ZBWorkshopPath) {
        Write-Log "ZombieBuddy Workshop item: FOUND - $ZBWorkshopPath" "OK"
    } else {
        Write-Log "ZombieBuddy Workshop item: MISSING (Workshop ID $ZombieBuddyWorkshop)" "WARN"
    }

    if ($BaseJar) {
        Write-Log "ZombieBuddy.jar: FOUND - $BaseJar" "OK"
    } else {
        Write-Log "ZombieBuddy.jar: MISSING from Zed's ZombieBuddy Workshop item." "WARN"
    }

    if ($BaseDll) {
        Write-Log "zbNative.dll: FOUND - $BaseDll" "OK"
    } else {
        Write-Log "zbNative.dll: MISSING from Zed's ZombieBuddy Workshop item." "WARN"
    }

    Write-Host ""
    Write-Host "[KAOEUTSU / B42.21 PATCH]"
    Write-Host "Author: Kaoeutsu"
    Write-Host "Workshop ID: $PatchWorkshop"

    if ($PatchWorkshopPath) {
        Write-Log "Patch Workshop item: FOUND - $PatchWorkshopPath" "OK"
    } else {
        Write-Log "Patch Workshop item: MISSING (Workshop ID $PatchWorkshop)" "INFO"
    }

    if ($PatchJar) {
        Write-Log "Patched ZombieBuddy.jar: FOUND - $PatchJar" "OK"
    } elseif ($PatchWorkshopPath) {
        Write-Log "Patched ZombieBuddy.jar: MISSING inside the patch Workshop item." "WARN"
    } else {
        Write-Log "Patched ZombieBuddy.jar: NOT CHECKED because the patch Workshop item was not found." "INFO"
    }

    Write-Host ""
    Write-Host "[PROJECT ZOMBOID]"

    if ($PZ) {
        Write-Log "Game installation: FOUND - $($PZ.InstallDir)" "OK"
        Write-Host "This is the destination folder where ZombieBuddy files are installed."
    } else {
        Write-Log "Game installation: NOT FOUND automatically." "ERROR"
    }

    $version = Get-PZVersionFromConsole
    if ($version) {
        Write-Log "Game version: $version" "INFO"
    } else {
        Write-Log "Game version: UNKNOWN (could not determine from console.txt)." "INFO"
    }

    if ($PZ) {
        $rootJar = Join-Path $PZ.InstallDir "ZombieBuddy.jar"
        $rootDll = Join-Path $PZ.InstallDir "zbNative.dll"

        if (Test-Path -LiteralPath $rootJar) {
            Write-Log "Installed ZombieBuddy.jar in game folder: FOUND" "OK"
        } else {
            Write-Log "Installed ZombieBuddy.jar in game folder: MISSING" "WARN"
        }

        if (Test-Path -LiteralPath $rootDll) {
            Write-Log "Installed zbNative.dll in game folder: FOUND" "OK"
        } else {
            Write-Log "Installed zbNative.dll in game folder: MISSING" "WARN"
        }
    }

    Write-Host ""
    Write-Host "[STEAM CONFIGURATION]"
    Write-Host "Required launch option:"
    Write-Host "  $RequiredLaunchOption"

    if ($LaunchStatus.FoundExact) {
        Write-Log "Launch option check: FOUND / appears to match exactly." "OK"
    } elseif ($LaunchStatus.FoundAgentlib) {
        Write-Log "Launch option check: zbNative was found, but the exact required form could not be confirmed." "WARN"
    } else {
        Write-Log "Launch option check: NOT CONFIRMED." "WARN"
        Write-Host ""
        Write-Host "Set it here:"
        Write-Host "Steam -> Library -> Project Zomboid -> Properties -> General -> Launch Options"
        Write-Host ""
        Write-Host "  $RequiredLaunchOption"
    }

    Write-Host ""
    Write-Host "[JAVA MOD APPROVALS]"

    if (Test-Path -LiteralPath $ApprovalsPath) {
        Write-Log "mod_approvals.json: FOUND - $ApprovalsPath" "OK"
    } else {
        Write-Log "mod_approvals.json: NOT FOUND" "INFO"
    }

    Write-Host "mod_approvals.json only stores previous allow / deny decisions."
    Write-Host "It does NOT make ZombieBuddy detect a JAR that the loader cannot see."

    Write-Host ""
    Write-Host "====================================================="
    Write-Host ""
}

function Require-PZ {
    param($PZ)

    if (-not $PZ) {
        Write-Log "Cannot continue because Project Zomboid was not found." "ERROR"
        Write-Host ""
        Write-Host "Make sure Project Zomboid is installed through Steam, then run this helper again."
        return $false
    }
    return $true
}

function Require-AdminForWrite {
    if (Test-IsAdministrator) {
        return $true
    }

    Write-Log "This action writes to the Project Zomboid installation folder." "WARN"
    Write-Log "PowerShell is not currently running as Administrator." "WARN"
    Write-Host ""
    Write-Host "Close this window, right-click PowerShell -> Run as administrator,"
    Write-Host "then run the helper again."
    return $false
}

function Install-BaseZombieBuddy {
    param(
        $PZ,
        [string]$BaseJar,
        [string]$BaseDll
    )

    if (-not (Require-PZ $PZ)) { return }
    if (-not (Require-AdminForWrite)) { return }

    if (-not $BaseJar -or -not $BaseDll) {
        Write-Log "ZombieBuddy source files could not be found in Workshop item $ZombieBuddyWorkshop." "ERROR"
        Write-Host ""
        Write-Host "Subscribe to ZombieBuddy in Steam Workshop and allow Steam to finish downloading it."
        return
    }

    $destJar = Join-Path $PZ.InstallDir "ZombieBuddy.jar"
    $destDll = Join-Path $PZ.InstallDir "zbNative.dll"

    Write-Host ""
    Write-Host "STEP 1 - ZED'S ZOMBIEBUDDY"
    Write-Host "BASE ZOMBIEBUDDY INSTALL / REPAIR"
    Write-Host "Author: Zed"
    Write-Host "Workshop ID: $ZombieBuddyWorkshop"
    Write-Host ""
    Write-Host "Installing:"
    Write-Host "- ZombieBuddy.jar"
    Write-Host "- zbNative.dll"
    Write-Host ""
    Write-Host "Source JAR : $BaseJar"
    Write-Host "Dest. JAR  : $destJar"
    Write-Host ""
    Write-Host "Source DLL : $BaseDll"
    Write-Host "Dest. DLL  : $destDll"
    Write-Host ""
    Write-Host "Backups will be created before replacing existing files."
    Write-Host "No changes have been made yet."
    Write-Host ""

    $answer = Read-Host "Continue? [Y/N]"
    if ($answer -notmatch '^(?i)y(es)?$') {
        Write-Log "Cancelled by user. No base files changed." "INFO"
        return
    }

    try {
        if (Test-Path -LiteralPath $destJar) {
            $backup = Backup-File $destJar
            Write-Log "Backed up existing ZombieBuddy.jar to: $backup" "OK"
        }

        if (Test-Path -LiteralPath $destDll) {
            $backup = Backup-File $destDll
            Write-Log "Backed up existing zbNative.dll to: $backup" "OK"
        }

        Copy-And-Verify -Source $BaseJar -Destination $destJar
        Copy-And-Verify -Source $BaseDll -Destination $destDll

        Write-Log "Base ZombieBuddy files installed/repaired successfully." "OK"
        Write-Host ""
        Write-Host "IMPORTANT:"
        Write-Host "Steam launch option should be exactly:"
        Write-Host ""
        Write-Host "    $RequiredLaunchOption"
        Write-Host ""
    } catch {
        Write-Log $_.Exception.Message "ERROR"
        Write-Log "A backup may exist, but this helper does NOT automatically roll files back." "WARN"
    }
}

function Apply-B421Patch {
    param(
        $PZ,
        [string]$PatchJar
    )

    if (-not (Require-PZ $PZ)) { return }
    if (-not (Require-AdminForWrite)) { return }

    if (-not $PatchJar) {
        Write-Log "The B42.21 patch JAR was not found in Workshop item $PatchWorkshop." "ERROR"
        Write-Host ""
        Write-Host "Subscribe to the temporary B42.21 patch first and let Steam finish downloading it."
        Write-Host "This helper will not download or redistribute the patch."
        return
    }

    $destJar = Join-Path $PZ.InstallDir "ZombieBuddy.jar"

    if (-not (Test-Path -LiteralPath $destJar)) {
        Write-Log "ZombieBuddy.jar is missing from the ProjectZomboid root." "ERROR"
        Write-Host "Install/repair base ZombieBuddy first (menu option 2), then apply the patch."
        return
    }

    Write-Host ""
    Write-Host "STEP 2 - KAOEUTSU'S B42.21 PATCH"
    Write-Host "TEMPORARY B42.21 COMPATIBILITY PATCH"
    Write-Host "Author: Kaoeutsu"
    Write-Host "Workshop ID: $PatchWorkshop"
    Write-Host ""
    Write-Host "Replacing:"
    Write-Host "- ZombieBuddy.jar ONLY"
    Write-Host ""
    Write-Host "Not changing:"
    Write-Host "- zbNative.dll"
    Write-Host ""
    Write-Host "Source patched JAR : $PatchJar"
    Write-Host "Destination        : $destJar"
    Write-Host ""
    Write-Host "zbNative.dll will NOT be changed."
    Write-Host "A backup of the current ZombieBuddy.jar will be created."
    Write-Host "No changes have been made yet."
    Write-Host ""

    $answer = Read-Host "Continue? [Y/N]"
    if ($answer -notmatch '^(?i)y(es)?$') {
        Write-Log "Cancelled by user. No patch files changed." "INFO"
        return
    }

    try {
        $backup = Backup-File $destJar
        Write-Log "Backed up current ZombieBuddy.jar to: $backup" "OK"

        Copy-And-Verify -Source $PatchJar -Destination $destJar
        Write-Log "B42.21 patched ZombieBuddy.jar installed successfully." "OK"

        Write-Host ""
        Write-Host "IMPORTANT B42.21 CHECKLIST:"
        Write-Host "1. Keep the original ZombieBuddy Workshop item subscribed."
        Write-Host "2. Keep the temporary B42.21 patch subscribed."
        Write-Host "3. Enable the patch mod in Mod Manager / the save's mod list."
        Write-Host "4. Keep Steam launch option:"
        Write-Host "   $RequiredLaunchOption"
        Write-Host "5. Do NOT replace zbNative.dll with anything from the patch."
        Write-Host "6. If needed, hold Shift while the game starts to force the Java-mod approval dialog."
        Write-Host ""
    } catch {
        Write-Log $_.Exception.Message "ERROR"
        Write-Log "A backup exists, but this helper does NOT automatically roll files back." "WARN"
    }
}

function Full-Setup {
    param(
        $PZ,
        [string]$BaseJar,
        [string]$BaseDll,
        [string]$PatchJar
    )

    if (-not (Require-PZ $PZ)) { return }
    if (-not (Require-AdminForWrite)) { return }

    if (-not $BaseJar -or -not $BaseDll) {
        Write-Log "Base ZombieBuddy source files were not found." "ERROR"
        return
    }

    if (-not $PatchJar) {
        Write-Log "B42.21 patch JAR was not found." "ERROR"
        Write-Host "Subscribe to the patch first, or use menu option 2 for base ZombieBuddy only."
        return
    }

    $destJar = Join-Path $PZ.InstallDir "ZombieBuddy.jar"
    $destDll = Join-Path $PZ.InstallDir "zbNative.dll"

    Write-Host ""
    Write-Host "FULL SETUP: ZED'S ZOMBIEBUDDY + KAOEUTSU'S B42.21 PATCH"
    Write-Host ""
    Write-Host "STEP 1 - ZED'S ZOMBIEBUDDY"
    Write-Host "Author: Zed"
    Write-Host "Workshop ID: $ZombieBuddyWorkshop"
    Write-Host "Installing:"
    Write-Host "- ZombieBuddy.jar"
    Write-Host "- zbNative.dll"
    Write-Host ""
    Write-Host "STEP 2 - KAOEUTSU'S B42.21 PATCH"
    Write-Host "Author: Kaoeutsu"
    Write-Host "Workshop ID: $PatchWorkshop"
    Write-Host "Replacing:"
    Write-Host "- ZombieBuddy.jar ONLY"
    Write-Host ""
    Write-Host "Not changing:"
    Write-Host "- zbNative.dll"
    Write-Host ""
    Write-Host "Project Zomboid : $($PZ.InstallDir)"
    Write-Host ""
    Write-Host "Base JAR         : $BaseJar"
    Write-Host "Base DLL         : $BaseDll"
    Write-Host "Patch JAR        : $PatchJar"
    Write-Host ""
    Write-Host "This will:"
    Write-Host "1. Back up existing root ZombieBuddy.jar / zbNative.dll if present."
    Write-Host "2. Install the official Workshop copies of ZombieBuddy.jar + zbNative.dll."
    Write-Host "3. Back up the freshly installed base JAR."
    Write-Host "4. Replace ONLY ZombieBuddy.jar with the temporary B42.21 patched JAR."
    Write-Host "5. SHA-256 verify every copied file."
    Write-Host ""
    Write-Host "No changes have been made yet."
    Write-Host ""

    $answer = Read-Host "Continue? [Y/N]"
    if ($answer -notmatch '^(?i)y(es)?$') {
        Write-Log "Cancelled by user. No files changed." "INFO"
        return
    }

    try {
        if (Test-Path -LiteralPath $destJar) {
            $backup = Backup-File $destJar
            Write-Log "Backed up existing root ZombieBuddy.jar to: $backup" "OK"
        }

        if (Test-Path -LiteralPath $destDll) {
            $backup = Backup-File $destDll
            Write-Log "Backed up existing root zbNative.dll to: $backup" "OK"
        }

        Write-Log "Installing base ZombieBuddy files..." "STEP"
        Copy-And-Verify -Source $BaseJar -Destination $destJar
        Copy-And-Verify -Source $BaseDll -Destination $destDll

        $baseBackup = Backup-File $destJar
        Write-Log "Backed up clean base ZombieBuddy.jar to: $baseBackup" "OK"

        Write-Log "Applying B42.21 patched JAR..." "STEP"
        Copy-And-Verify -Source $PatchJar -Destination $destJar

        Write-Host ""
        Write-Host "============================================================"
        Write-Host " FULL SETUP COMPLETED"
        Write-Host "============================================================"
        Write-Host ""
        Write-Host "Remaining manual checks:"
        Write-Host ""
        Write-Host "1. Steam -> Project Zomboid -> Properties -> General"
        Write-Host "   Launch Options:"
        Write-Host "   $RequiredLaunchOption"
        Write-Host ""
        Write-Host "2. In Project Zomboid Mod Manager / your save mod list:"
        Write-Host "   Enable the temporary B42.21 patch."
        Write-Host ""
        Write-Host "3. Start Project Zomboid."
        Write-Host "   If the Java approval window does not appear, hold Shift while starting."
        Write-Host ""
        Write-Host "4. A working B42.21 setup should no longer simply show:"
        Write-Host '   "ZombieBuddy loaded / no active Java mods"'
        Write-Host "   when compatible Java mods are enabled."
        Write-Host ""
        Write-Host "Helper log:"
        Write-Host "   $logPath"
        Write-Host ""
    } catch {
        Write-Log $_.Exception.Message "ERROR"
        Write-Log "One or more backups may exist, but this helper does NOT automatically roll files back." "WARN"
    }
}

# -----------------------------
# Discovery
# -----------------------------
Write-Header
Write-Log "Starting discovery..." "STEP"

$steamRoots = @(Get-SteamRoots)
if ($steamRoots.Count -eq 0) {
    Write-Log "Steam installation was not found automatically." "ERROR"
    Write-Host ""
    Write-Host "The helper cannot continue automatically."
    Write-Host "Log: $logPath"
    Read-Host "Press Enter to finish"
    exit 1
}

foreach ($root in $steamRoots) {
    Write-Log "Steam root candidate: $root" "INFO"
}

$libraries = @(Get-SteamLibraryRoots -SteamRoots $steamRoots)
foreach ($lib in $libraries) {
    Write-Log "Steam library: $lib" "INFO"
}

$pz = Get-PZInstall -Libraries $libraries

$zbWorkshopPath = Get-WorkshopItemPath -Libraries $libraries -WorkshopId $ZombieBuddyWorkshop
$patchWorkshopPath = Get-WorkshopItemPath -Libraries $libraries -WorkshopId $PatchWorkshop

$baseJar = $null
$baseDll = $null
$patchJar = $null

if ($zbWorkshopPath) {
    $baseJar = Find-PreferredFile `
        -Root $zbWorkshopPath `
        -LeafName "ZombieBuddy.jar" `
        -PreferredPathFragments @(
            "\mods\ZombieBuddy\libs\",
            "\ZombieBuddy\libs\",
            "\libs\"
        )

    $baseDll = Find-PreferredFile `
        -Root $zbWorkshopPath `
        -LeafName "zbNative.dll" `
        -PreferredPathFragments @(
            "\mods\ZombieBuddy\libs\",
            "\ZombieBuddy\libs\",
            "\libs\"
        )
}

if ($patchWorkshopPath) {
    $patchJar = Find-PreferredFile `
        -Root $patchWorkshopPath `
        -LeafName "ZombieBuddy.jar" `
        -PreferredPathFragments @(
            "\mods\ZombieBuddyFix\libs\",
            "\ZombieBuddyFix\libs\",
            "\libs\"
        )
}

$launchStatus = Get-LaunchOptionStatus -SteamRoots $steamRoots

# -----------------------------
# Menu
# -----------------------------
while ($true) {
    Write-Header

    if ($pz) {
        Write-Host "Project Zomboid:"
        Write-Host "  $($pz.InstallDir)"
    } else {
        Write-Host "Project Zomboid:"
        Write-Host "  NOT FOUND"
    }

    Write-Host ""
    Write-Host "COMPONENTS:"
    Write-Host "  Zed      -> original ZombieBuddy (Workshop ID 3619862853)"
    Write-Host "  Kaoeutsu -> temporary B42.21 patch (Workshop ID 3809837933)"
    Write-Host ""
    Write-Host "Choose an option:"
    Write-Host ""
    Write-Host "  1 - Diagnose installation only (NO CHANGES)"
    Write-Host "  2 - Install / repair base ZombieBuddy"
    Write-Host "  3 - Apply temporary B42.21 patch"
    Write-Host "  4 - Full setup: base ZombieBuddy + B42.21 patch"
    Write-Host "  5 - Show required launch option / final checklist"
    Write-Host "  0 - Exit"
    Write-Host ""

    $choice = Read-Host "Selection"

    switch ($choice) {
        "1" {
            Show-Diagnostics `
                -PZ $pz `
                -ZBWorkshopPath $zbWorkshopPath `
                -PatchWorkshopPath $patchWorkshopPath `
                -BaseJar $baseJar `
                -BaseDll $baseDll `
                -PatchJar $patchJar `
                -LaunchStatus $launchStatus

            Read-Host "Press Enter to return to the menu"
        }

        "2" {
            Install-BaseZombieBuddy -PZ $pz -BaseJar $baseJar -BaseDll $baseDll
            Read-Host "Press Enter to return to the menu"
        }

        "3" {
            Apply-B421Patch -PZ $pz -PatchJar $patchJar
            Read-Host "Press Enter to return to the menu"
        }

        "4" {
            Full-Setup -PZ $pz -BaseJar $baseJar -BaseDll $baseDll -PatchJar $patchJar
            Read-Host "Press Enter to return to the menu"
        }

        "5" {
            Write-Host ""
            Write-Host "STEAM LAUNCH OPTION"
            Write-Host ""
            Write-Host "Project Zomboid -> Properties -> General -> Launch Options"
            Write-Host ""
            Write-Host "    $RequiredLaunchOption"
            Write-Host ""
            Write-Host "OWNERSHIP / COMPONENTS"
            Write-Host "- ZombieBuddy is created by Zed."
            Write-Host "- The temporary B42.21 patch is created by Kaoeutsu."
            Write-Host "- This helper is an independent unofficial community tool."
            Write-Host "- It does not contain or redistribute either author's files."
            Write-Host ""
            Write-Host "B42.21:"
            Write-Host "- Keep Zed's ZombieBuddy subscribed (Workshop ID 3619862853)."
            Write-Host "- Keep Kaoeutsu's temporary patch subscribed (Workshop ID 3809837933)."
            Write-Host "- Enable the patch in Mod Manager / the save's mod list."
            Write-Host "- The patch replaces ZombieBuddy.jar only."
            Write-Host "- Do NOT replace zbNative.dll with a patch file."
            Write-Host "- Hold Shift during startup only if you need to force the Java-mod approval dialog."
            Write-Host ""
            Write-Host "mod_approvals.json stores previous allow/deny decisions."
            Write-Host "It does NOT make ZombieBuddy detect a JAR that the loader cannot see."
            Write-Host ""
            Read-Host "Press Enter to return to the menu"
        }

        "0" {
            Write-Host ""
            Write-Host "Log saved to:"
            Write-Host "  $logPath"
            Write-Host ""
            break
        }

        default {
            Write-Host ""
            Write-Host "Invalid selection."
            Start-Sleep -Seconds 1
        }
    }

    if ($choice -eq "0") {
        break
    }
}
