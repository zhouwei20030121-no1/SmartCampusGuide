param(
    [switch]$InstallPythonDeps,
    [switch]$Restart,
    [switch]$NoFlutter
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$root      = Split-Path -Parent $MyInvocation.MyCommand.Path
$javaDir   = Join-Path $root "3_Backend_Java"
$aiDir     = Join-Path $root "4_AIService_Python"
$vueDir    = Join-Path $root "2_AdminWeb_Vue"
$flutterDir = Join-Path $root "1_CampusApp_Flutter"
$script:children = @()
$script:stopping = $false

# ── helpers ──────────────────────────────────────────────────────────────────

function Get-ListenPids {
    param([int]$Port)
    $lines = netstat -ano | Select-String ":$Port\s+.*LISTENING"
    foreach ($line in $lines) {
        $parts = ($line.Line -split "\s+") | Where-Object { $_ }
        if ($parts.Count -gt 0) {
            $pidText = $parts[$parts.Count - 1]
            $pidValue = 0
            if ([int]::TryParse($pidText, [ref]$pidValue)) { $pidValue }
        }
    }
}

function Stop-Port {
    param([int]$Port)
    $pids = @(Get-ListenPids -Port $Port | Select-Object -Unique)
    foreach ($pidValue in $pids) {
        try {
            Write-Host "[BOOT] stopping process $pidValue on port $Port"
            Stop-Process -Id $pidValue -Force -ErrorAction Stop
        } catch {
            Write-Host "[BOOT] failed to stop $pidValue on port ${Port}: $($_.Exception.Message)"
        }
    }
}

function Wait-PortFree {
    param([int]$Port, [int]$TimeoutSeconds = 15)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (@(Get-ListenPids -Port $Port | Select-Object -Unique).Count -eq 0) { return }
        Start-Sleep -Milliseconds 500
    }
    $remaining = @(Get-ListenPids -Port $Port | Select-Object -Unique) -join ", "
    throw "Port $Port still in use by PID $remaining after cleanup."
}

function Assert-PortFree {
    param([int]$Port)
    $pids = @(Get-ListenPids -Port $Port | Select-Object -Unique)
    if ($pids.Count -gt 0) {
        throw "Port $Port already in use by PID $($pids -join ', '). Run with -Restart to force."
    }
}

function Resolve-Executable {
    param([string[]]$Candidates, [string]$Description, [switch]$Optional)
    foreach ($candidate in $Candidates) {
        if (Test-Path $candidate) { return (Resolve-Path $candidate).Path }
        $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    if ($Optional) { return $null }
    throw "$Description not found in PATH."
}

function Start-LoggedProcess {
    param([string]$Name, [string]$FileName, [string]$Arguments, [string]$WorkingDirectory)

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $FileName
    $psi.Arguments = $Arguments
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding  = [System.Text.Encoding]::UTF8

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $psi
    $process.EnableRaisingEvents = $true

    Register-ObjectEvent -InputObject $process -EventName OutputDataReceived -MessageData $Name -Action {
        if ($EventArgs.Data) { Write-Host "[$($Event.MessageData)] $($EventArgs.Data)" }
    } | Out-Null
    Register-ObjectEvent -InputObject $process -EventName ErrorDataReceived -MessageData $Name -Action {
        if ($EventArgs.Data) { Write-Host "[$($Event.MessageData)] $($EventArgs.Data)" }
    } | Out-Null

    if (-not $process.Start()) { throw "Failed to start $Name." }
    $process.BeginOutputReadLine()
    $process.BeginErrorReadLine()
    $script:children += $process
    Write-Host "[BOOT] $Name started  PID=$($process.Id)"
}

function Stop-Children {
    foreach ($process in $script:children) {
        if ($process -and -not $process.HasExited) {
            try { $process.Kill($true) } catch { try { $process.Kill() } catch {} }
            Write-Host "[BOOT] stopped PID=$($process.Id)"
        }
    }
}

function Wait-EmulatorReady {
    param([int]$TimeoutSeconds = 120)
    Write-Host "[BOOT] waiting for emulator to boot (up to ${TimeoutSeconds}s)..."
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $output = & adb shell getprop sys.boot_completed 2>$null
        if ($output -and $output.Trim() -eq "1") {
            Write-Host "[BOOT] emulator is ready."
            return $true
        }
        Start-Sleep -Seconds 3
    }
    Write-Host "[BOOT] WARNING: emulator did not finish booting within ${TimeoutSeconds}s, continuing anyway."
    return $false
}

# ── port / restart handling ───────────────────────────────────────────────────

if ($Restart) {
    Stop-Port -Port 8080
    Stop-Port -Port 5000
    Stop-Port -Port 3000
    Wait-PortFree -Port 8080
    Wait-PortFree -Port 5000
    Wait-PortFree -Port 3000
} else {
    Assert-PortFree -Port 8080
    Assert-PortFree -Port 5000
    Assert-PortFree -Port 3000
}

# ── optional: install Python deps ─────────────────────────────────────────────

if ($InstallPythonDeps) {
    $pythonForInstall = Resolve-Executable -Candidates @((Join-Path $aiDir ".venv\Scripts\python.exe"), "python", "py") -Description "Python"
    Write-Host "[BOOT] installing Python dependencies"
    & $pythonForInstall -m pip install -r (Join-Path $aiDir "requirements.txt")
    if ($LASTEXITCODE -ne 0) { throw "Python dependency installation failed." }
}

# ── resolve executables ───────────────────────────────────────────────────────

$maven   = Resolve-Executable -Candidates @("mvn.cmd", "mvn")                                                          -Description "Maven"
$python  = Resolve-Executable -Candidates @((Join-Path $aiDir ".venv\Scripts\python.exe"), "python", "py")            -Description "Python"
$npm     = Resolve-Executable -Candidates @("npm.cmd", "npm")                                                          -Description "npm"
$flutter = Resolve-Executable -Candidates @("flutter.bat", "flutter") -Optional                                        -Description "Flutter"

# ── main ──────────────────────────────────────────────────────────────────────

try {
    # 1. Redis ─ start only if not already running
    $redis = Resolve-Executable -Candidates @("redis-server.exe", "redis-server") -Optional -Description "Redis"
    $redisPids = @(Get-ListenPids -Port 6379 | Select-Object -Unique)
    if ($redisPids.Count -gt 0) {
        Write-Host "[BOOT] Redis already running on port 6379 (PID=$($redisPids -join ','))"
    } elseif ($redis) {
        Start-LoggedProcess -Name "REDIS-6379" -FileName $redis -Arguments "" -WorkingDirectory $root
        Start-Sleep -Seconds 1
    } else {
        Write-Host "[BOOT] WARNING: redis-server not found in PATH, skipping."
    }

    # 2. Java Spring Boot
    Write-Host "[BOOT] starting Java backend (port 8080)..."
    Start-LoggedProcess -Name "JAVA-8080" -FileName $maven -Arguments "spring-boot:run" -WorkingDirectory $javaDir

    # 3. Python AI service
    Write-Host "[BOOT] starting Python AI service (port 5000)..."
    Start-LoggedProcess -Name "AI-5000" -FileName $python -Arguments "-m uvicorn main:app --host 0.0.0.0 --port 5000" -WorkingDirectory $aiDir

    # 4. Vue admin web — start Vite then open browser once port responds
    Write-Host "[BOOT] starting Vue admin web (port 3000)..."
    Start-LoggedProcess -Name "VUE-3000" -FileName $npm -Arguments "run dev" -WorkingDirectory $vueDir
    Start-Job -ScriptBlock {
        $deadline = (Get-Date).AddSeconds(30)
        while ((Get-Date) -lt $deadline) {
            try {
                $r = Invoke-WebRequest -Uri "http://localhost:3000" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
                if ($r.StatusCode -lt 500) { break }
            } catch {}
            Start-Sleep -Seconds 1
        }
        Start-Process "http://localhost:3000"
    } | Out-Null

    # 5. Flutter emulator + app
    # Open a dedicated window immediately; it handles boot-wait + flutter run internally.
    if (-not $NoFlutter) {
        if (-not $flutter) {
            Write-Host "[BOOT] WARNING: flutter not found in PATH, skipping Flutter."
        } else {
            $adbDevices = $false
            try { $adbDevices = (& adb devices 2>&1 | Out-String) -match "emulator" } catch {}
            if ($adbDevices) {
                Write-Host "[BOOT] emulator already running, launching flutter run in new window..."
            } else {
                Write-Host "[BOOT] launching emulator SmartCampus_API36..."
                Start-Process -FilePath $flutter -ArgumentList "emulators --launch SmartCampus_API36" -NoNewWindow -Wait
            }
            $flutterCmd = @"
Set-Location '$flutterDir'
Write-Host '[Flutter] waiting for emulator to boot...'
`$deadline = (Get-Date).AddSeconds(120)
while ((Get-Date) -lt `$deadline) {
    `$ready = & adb shell getprop sys.boot_completed 2>`$null
    if (`$ready -and `$ready.Trim() -eq '1') { break }
    Start-Sleep -Seconds 3
}
`$deviceId = (& adb devices 2>`$null | Select-String 'emulator-\d+\s+device').ToString().Trim().Split()[0]
if (-not `$deviceId) { `$deviceId = 'emulator-5554' }
Write-Host "[Flutter] emulator ready (device=`$deviceId), starting app..."
flutter run -d `$deviceId
"@
            Start-Process powershell -ArgumentList "-NoExit", "-NoProfile", "-Command", $flutterCmd
            Write-Host "[BOOT] Flutter window opened."
        }
    }

    Write-Host ""
    Write-Host "[BOOT] ========================================="
    Write-Host "[BOOT]   All services are starting up"
    Write-Host "[BOOT]   Java    -> http://localhost:8080"
    Write-Host "[BOOT]   Python  -> http://localhost:5000"
    Write-Host "[BOOT]   Vue     -> http://localhost:3000"
    Write-Host "[BOOT]   Redis   -> localhost:6379"
    if (-not $NoFlutter) {
        Write-Host "[BOOT]   Flutter -> see new terminal window"
    }
    Write-Host "[BOOT]   Press Ctrl+C to stop all services"
    Write-Host "[BOOT] ========================================="
    Write-Host ""

    while (-not $script:stopping) {
        Start-Sleep -Seconds 1
        $running = @($script:children | Where-Object { -not $_.HasExited })
        if ($running.Count -eq 0) {
            Write-Host "[BOOT] all services exited."
            break
        }
    }
} finally {
    Stop-Children
}
