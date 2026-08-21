# JSDesk Local Compiler Script
$ErrorActionPreference = "Stop"

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "       JSDESK - COMPILADOR NATIVO LOCAL      " -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# 1. Configurar Entorno y Paths
$env:PATH = "C:\laragon\bin\python\python-3.10;C:\tools\cmake\bin;C:\tools\ninja;C:\Program Files\LLVM\bin;$env:USERPROFILE\.cargo\bin;C:\src\flutter\bin;$env:PATH"
$env:LIBCLANG_PATH = "C:\Program Files\LLVM\bin"

Set-Location "C:\laragon\www\jsdesk"

# 2. Generar Bridge de Flutter-Rust si no existe
if (-not (Test-Path "flutter\lib\generated_bridge.dart")) {
    Write-Host "[1/5] Generando enlaces Flutter-Rust Bridge..." -ForegroundColor Yellow
    & "$env:USERPROFILE\.cargo\bin\flutter_rust_bridge_codegen.exe" --rust-input ./src/flutter_ffi.rs --dart-output ./flutter/lib/generated_bridge.dart --c-output ./flutter/macos/Runner/bridge_generated.h
} else {
    Write-Host "[1/5] Flutter-Rust Bridge verificado." -ForegroundColor Green
}

# 3. Compilar Virtual Display dylib si no existe
Write-Host "[2/5] Compilando Virtual Display..." -ForegroundColor Yellow
Set-Location "libs\virtual_display\dylib"
& "$env:USERPROFILE\.cargo\bin\cargo.exe" build --release
Set-Location "..\..\.."

# 4. Compilar Motor y Ejecutable de Flutter Windows
Write-Host "[3/5] Compilando motor de Flutter Windows..." -ForegroundColor Yellow
Set-Location "flutter"
& "C:\src\flutter\bin\flutter.bat" pub get
& "C:\src\flutter\bin\flutter.bat" build windows --release
Set-Location ".."

# 5. Compilar librustdesk.dll y rustdesk.exe con características flutter
Write-Host "[4/5] Compilando librustdesk.dll y binario Rust/C++..." -ForegroundColor Yellow
& "$env:USERPROFILE\.cargo\bin\cargo.exe" build --release --features flutter --lib
& "$env:USERPROFILE\.cargo\bin\cargo.exe" build --release --features flutter

$flutterReleaseDir = "flutter\build\windows\x64\runner\Release"
Copy-Item -Path "target\release\librustdesk.dll" -Destination "$flutterReleaseDir\librustdesk.dll" -Force
if (Test-Path "target\release\rustdesk.exe") {
    Copy-Item -Path "target\release\rustdesk.exe" -Destination "$flutterReleaseDir\rustdesk.exe" -Force
}
if (Test-Path "target\release\deps\dylib_virtual_display.dll") {
    Copy-Item -Path "target\release\deps\dylib_virtual_display.dll" -Destination "$flutterReleaseDir\dylib_virtual_display.dll" -Force
}

# 6. Empaquetar Ejecutable Portátil Standalone (Single .EXE)
Write-Host "[5/5] Generando ejecutable standalone portátil JSDesk.exe..." -ForegroundColor Yellow
$rootDir = (Get-Item .).FullName
Set-Location "$rootDir\libs\portable"
C:\laragon\bin\python\python-3.10\python.exe .\generate.py -f "$rootDir\$flutterReleaseDir" -o . -e JSDesk.exe
& "$env:USERPROFILE\.cargo\bin\cargo.exe" build --release
Set-Location $rootDir

$possiblePackers = @(
    "$rootDir\target\release\rustdesk-portable-packer.exe",
    "$rootDir\libs\portable\target\release\rustdesk-portable-packer.exe",
    "$rootDir\target\release\portable.exe"
)

$packerExe = $possiblePackers | Where-Object { Test-Path $_ } | Select-Object -First 1
$distExe = "$env:USERPROFILE\Desktop\JSDesk.exe"

if ($packerExe) {
    Copy-Item -Path $packerExe -Destination $distExe -Force
    Write-Host "=============================================" -ForegroundColor Green
    Write-Host "  ¡COMPILACION COMPLETADA CON EXITO!         " -ForegroundColor Green
    Write-Host "  Archivo generado: $distExe                 " -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Green
} else {
    Write-Host "Compilación finalizada." -ForegroundColor Yellow
}
