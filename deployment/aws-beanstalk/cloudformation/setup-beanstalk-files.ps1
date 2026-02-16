# setup-beanstalk-files.ps1 - Create Elastic Beanstalk required files
Write-Host "=== Creating Elastic Beanstalk Files ===" -ForegroundColor Green
Write-Host ""

$ProjectRoot = "..\..\..\"
Push-Location $ProjectRoot

Write-Host "Working directory: $((Get-Location).Path)" -ForegroundColor Cyan
Write-Host ""

# Create application.py (Beanstalk entry point)
Write-Host "Creating application.py..." -ForegroundColor Cyan
$applicationContent = @"
# application.py - Elastic Beanstalk entry point
from app.main import app

# Elastic Beanstalk expects 'application' variable
application = app

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(application, host="0.0.0.0", port=8000)
"@

$applicationContent | Out-File -FilePath "application.py" -Encoding utf8
Write-Host "  application.py created" -ForegroundColor Green

# Create Procfile
Write-Host "Creating Procfile..." -ForegroundColor Cyan
$procfileContent = "web: uvicorn application:application --host 0.0.0.0 --port 8000"
$procfileContent | Out-File -FilePath "Procfile" -Encoding utf8 -NoNewline
Write-Host "  Procfile created" -ForegroundColor Green

# Create .ebextensions directory
Write-Host "Creating .ebextensions/..." -ForegroundColor Cyan
if (-not (Test-Path ".ebextensions")) {
    New-Item -ItemType Directory -Path ".ebextensions" | Out-Null
}

# Create Python configuration
$ebConfigContent = @"
option_settings:
  aws:elasticbeanstalk:container:python:
    WSGIPath: application:application
  aws:elasticbeanstalk:application:environment:
    PYTHONPATH: "/var/app/current:`$PYTHONPATH"
  aws:elasticbeanstalk:environment:process:default:
    HealthCheckPath: /health
    Port: '8000'
"@

$ebConfigContent | Out-File -FilePath ".ebextensions/01_python.config" -Encoding utf8
Write-Host "  .ebextensions/01_python.config created" -ForegroundColor Green

# Verify files
Write-Host ""
Write-Host "Verifying files..." -ForegroundColor Cyan
$files = @{
    "application.py" = (Test-Path 'application.py')
    "Procfile" = (Test-Path 'Procfile')
    ".ebextensions" = (Test-Path '.ebextensions')
    "requirements.txt" = (Test-Path 'requirements.txt')
    "app/" = (Test-Path 'app')
}

foreach ($file in $files.GetEnumerator()) {
    if ($file.Value) {
        Write-Host "  $($file.Key): OK" -ForegroundColor Green
    } else {
        Write-Host "  $($file.Key): Missing" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "All files created successfully!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Review the created files" -ForegroundColor Gray
Write-Host "2. Run deploy-beanstalk.ps1 to deploy" -ForegroundColor Gray

Pop-Location

Write-Host ""
pause