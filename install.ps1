$ErrorActionPreference = "Stop"

Write-Host "[gfd] Compiling release build with Odin..."
odin build . -out:gfd.exe -opt:3

$InstallDir = "$HOME\.local\bin"
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir | Out-Null
}

Move-Item -Force gfd.exe "$InstallDir\gfd.exe"
Write-Host "[gfd] Installed binary to $InstallDir\gfd.exe"

# Automatically append to User PATH if not present
$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($UserPath -notlike "*$InstallDir*") {
    Write-Host "[gfd] Adding $InstallDir to User PATH..."
    [Environment]::SetEnvironmentVariable("Path", "$UserPath;$InstallDir", "User")
    Write-Host "[gfd] PATH updated. Please restart your terminal."
} else {
    Write-Host "[gfd] Installation complete! You can now run 'gfd' anywhere."
}
