param(
    [switch]$InstallPythonDeps,
    [switch]$Restart
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$javaDir = Join-Path $root "3_Backend_Java"
$aiDir = Join-Path $root "4_AIService_Python"
$script:children = @()
$script:stopping = $false

function Get-ListenPids {
    param([int]$Port)

    $lines = netstat -ano | Select-String ":$Port\s+.*LISTENING"
    foreach ($line in $lines) {
        $parts = ($line.Line -split "\s+") | Where-Object { $_ }
        if ($parts.Count -gt 0) {
            $pidText = $parts[$parts.Count - 1]
            $pidValue = 0
            if ([int]::TryParse($pidText, [ref]$pidValue)) {
                $pidValue
            }
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
            Write-Host "[BOOT] failed to stop process $pidValue on port ${Port}: $($_.Exception.Message)"
            $children = @(Get-CimInstance Win32_Process | Where-Object {
                $_.ParentProcessId -eq $pidValue -or
                ($_.CommandLine -and $_.CommandLine.Contains("parent_pid=$pidValue"))
            })
            foreach ($child in $children) {
                try {
                    Write-Host "[BOOT] stopping child process $($child.ProcessId) from stale parent $pidValue"
                    Stop-Process -Id $child.ProcessId -Force -ErrorAction Stop
                } catch {
                    Write-Host "[BOOT] failed to stop child process $($child.ProcessId): $($_.Exception.Message)"
                }
            }
        }
    }
}

function Wait-PortFree {
    param(
        [int]$Port,
        [int]$TimeoutSeconds = 15
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $pids = @(Get-ListenPids -Port $Port | Select-Object -Unique)
        if ($pids.Count -eq 0) {
            return
        }
        Start-Sleep -Milliseconds 500
    }

    $remainingPids = @(Get-ListenPids -Port $Port | Select-Object -Unique) -join ", "
    throw "Port $Port is still in use by PID $remainingPids after cleanup."
}

function Assert-PortFree {
    param([int]$Port)

    $pids = @(Get-ListenPids -Port $Port | Select-Object -Unique)
    if ($pids.Count -gt 0) {
        $pidText = $pids -join ", "
        throw "Port $Port is already in use by PID $pidText. Stop it first or run: .\start-backend-all.ps1 -Restart"
    }
}

function Resolve-Executable {
    param(
        [string[]]$Candidates,
        [string]$Description
    )

    foreach ($candidate in $Candidates) {
        if (Test-Path $candidate) {
            return (Resolve-Path $candidate).Path
        }
        $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($cmd) {
            return $cmd.Source
        }
    }
    throw "$Description was not found in PATH."
}

function Start-LoggedProcess {
    param(
        [string]$Name,
        [string]$FileName,
        [string]$Arguments,
        [string]$WorkingDirectory
    )

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $FileName
    $psi.Arguments = $Arguments
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $psi
    $process.EnableRaisingEvents = $true

    Register-ObjectEvent -InputObject $process -EventName OutputDataReceived -MessageData $Name -Action {
        if ($EventArgs.Data) {
            Write-Host "[$($Event.MessageData)] $($EventArgs.Data)"
        }
    } | Out-Null
    Register-ObjectEvent -InputObject $process -EventName ErrorDataReceived -MessageData $Name -Action {
        if ($EventArgs.Data) {
            Write-Host "[$($Event.MessageData)] $($EventArgs.Data)"
        }
    } | Out-Null

    if (-not $process.Start()) {
        throw "Failed to start $Name."
    }
    $process.BeginOutputReadLine()
    $process.BeginErrorReadLine()
    $script:children += $process
    Write-Host "[BOOT] $Name started, PID=$($process.Id)"
}

function Stop-Children {
    foreach ($process in $script:children) {
        if ($process -and -not $process.HasExited) {
            try {
                Write-Host "[BOOT] stopping PID=$($process.Id)"
                $process.Kill($true)
            } catch {
                try { $process.Kill() } catch {}
            }
        }
    }
}

if ($Restart) {
    Stop-Port -Port 8080
    Stop-Port -Port 5000
    Wait-PortFree -Port 8080
    Wait-PortFree -Port 5000
} else {
    Assert-PortFree -Port 8080
    Assert-PortFree -Port 5000
}

if ($InstallPythonDeps) {
    $pythonForInstall = Resolve-Executable -Candidates @((Join-Path $aiDir ".venv\Scripts\python.exe"), "python", "py") -Description "Python"
    Write-Host "[BOOT] installing Python dependencies"
    & $pythonForInstall -m pip install -r (Join-Path $aiDir "requirements.txt")
    if ($LASTEXITCODE -ne 0) {
        throw "Python dependency installation failed."
    }
}

$maven = Resolve-Executable -Candidates @("mvn.cmd", "mvn") -Description "Maven"
$python = Resolve-Executable -Candidates @((Join-Path $aiDir ".venv\Scripts\python.exe"), "python", "py") -Description "Python"

try {
    Write-Host "[BOOT] starting backend services in one terminal"
    Start-LoggedProcess -Name "JAVA-8080" -FileName $maven -Arguments "spring-boot:run" -WorkingDirectory $javaDir
    Start-LoggedProcess -Name "AI-5000" -FileName $python -Arguments "-m uvicorn main:app --host 0.0.0.0 --port 5000" -WorkingDirectory $aiDir
    Write-Host "[BOOT] services are starting. Press Ctrl+C to stop all child processes."

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
