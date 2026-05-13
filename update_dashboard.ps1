param(
    [string]$DashboardDir = "D:\RS- Projects\Home-based Worker Follow Up Survey\DASHBOARD"
)

Set-Location $DashboardDir

Write-Host "=== HBW Dashboard Daily Update Script ===" -ForegroundColor Cyan
Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Gray
Write-Host ""

# Checks
if (-not (Test-Path "$DashboardDir\Pak HBW Survey - Husband - Endline.dta")) { 
    Write-Host "ERROR: Husband DTA not found" -ForegroundColor Red; exit 1 
}
if (-not (Test-Path "$DashboardDir\Pak HBW Survey - Wife - Endline.dta")) { 
    Write-Host "ERROR: Wife DTA not found" -ForegroundColor Red; exit 1 
}

Write-Host "✅ DTA files found." -ForegroundColor Green

# Run Python Script
Write-Host "Updating dashboard..." -ForegroundColor Yellow
python update_data.py $DashboardDir

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Update failed" -ForegroundColor Red
    exit 1
}

# Git Push
Write-Host "Pushing to GitHub..." -ForegroundColor Yellow
$today = Get-Date -Format 'yyyy-MM-dd'
git add index.html
git commit -m "Daily update: $today"
git push origin main

Write-Host "✅ Done! Dashboard live at: https://homebased.rs.org.pk" -ForegroundColor Cyan