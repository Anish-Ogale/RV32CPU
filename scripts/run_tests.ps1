param(
    [string]$Module = ''
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$rtlDirectory = Join-Path $projectRoot 'rtl'
$tbDirectory = Join-Path $projectRoot 'tb'
$rtlFiles = @(Get-ChildItem -LiteralPath $rtlDirectory -Filter '*.v' | Sort-Object Name)

foreach ($toolName in @('iverilog', 'vvp')) {
    if (-not (Get-Command $toolName -ErrorAction SilentlyContinue)) {
        throw "Required simulator tool is not on PATH: $toolName"
    }
}

if ($Module) {
    $targets = @($rtlFiles | Where-Object BaseName -EQ $Module)
    if ($targets.Count -ne 1) { throw "Unknown RTL module: $Module" }
} else {
    $targets = $rtlFiles
}

# Simulator artifacts stay outside the source tree, in a unique temp directory.
$runDirectory = Join-Path ([IO.Path]::GetTempPath()) ('riscvmcu-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $runDirectory | Out-Null
$sourcePaths = @($rtlFiles | ForEach-Object FullName)
$failed = 0

foreach ($target in $targets) {
    $name = $target.BaseName
    $testbench = Join-Path $tbDirectory ($name + '_tb.v')
    if (-not (Test-Path -LiteralPath $testbench)) {
        Write-Output "FAIL: $name - missing dedicated testbench"
        $failed++
        continue
    }

    $compiledPath = Join-Path $runDirectory ($name + '.vvp')
    $compileOutput = & iverilog -g2001 -Wall -s ($name + '_tb') -o $compiledPath @sourcePaths $testbench 2>&1
    $compileExit = $LASTEXITCODE
    if ($compileExit -ne 0) {
        Write-Output "FAIL: $name - compilation"
        $compileOutput | ForEach-Object { Write-Output $_ }
        $failed++
        continue
    }
    if ($compileOutput) { $compileOutput | ForEach-Object { Write-Output $_ } }

    $simulationOutput = & vvp $compiledPath 2>&1
    $simulationExit = $LASTEXITCODE
    $simulationText = $simulationOutput -join "`n"
    # Verilog-2001 has no portable $fatal. Require an explicit PASS marker,
    # and treat any FAIL marker (including watchdog timeout) as a failure.
    if ($simulationExit -ne 0 -or $simulationText -match 'FAIL:' -or $simulationText -notmatch 'PASS:') {
        Write-Output "FAIL: $name - simulation"
        $simulationOutput | ForEach-Object { Write-Output $_ }
        $failed++
    } else {
        Write-Output "PASS: $name"
        $simulationOutput | Where-Object { "$_" -match '^PASS:' } | ForEach-Object { Write-Output "  $_" }
    }
}

Write-Output "$($targets.Count - $failed)/$($targets.Count) testbenches passed."
Write-Output "Simulator artifacts: $runDirectory"
if ($failed -gt 0) { exit 1 }
