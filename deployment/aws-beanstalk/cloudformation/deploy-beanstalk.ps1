# deploy-beanstalk.ps1
Write-Host "=== FastAPI Elastic Beanstalk Deployment ===" -ForegroundColor Green
Write-Host ""

# Configuration
$StackName = "fastapi-beanstalk-infrastructure"
$TemplateFile = "beanstalk-infrastructure.yaml"
$ParametersFile = "beanstalk-parameters.json"
$Region = "ap-south-1"
$ProjectRoot = "..\..\..\"
$AppZipFile = "fastapi-app-v1.0.0.zip"

# Check AWS CLI
try {
    aws --version | Out-Null
    Write-Host "AWS CLI: OK" -ForegroundColor Green
} catch {
    Write-Host "ERROR: AWS CLI not found!" -ForegroundColor Red
    pause
    exit 1
}

Write-Host ""

# Change to project root
Push-Location $ProjectRoot

Write-Host "Working directory: $((Get-Location).Path)" -ForegroundColor Cyan
Write-Host ""

# Check required files
Write-Host "Checking required files..." -ForegroundColor Cyan
$requiredFiles = @("app", "requirements.txt", "application.py", "Procfile", ".ebextensions")
$allFound = $true

foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "  OK: $file" -ForegroundColor Green
    } else {
        Write-Host "  MISSING: $file" -ForegroundColor Red
        $allFound = $false
    }
}

if (-not $allFound) {
    Write-Host ""
    Write-Host "ERROR: Missing required files!" -ForegroundColor Red
    Write-Host "Run setup-beanstalk-files.ps1 first" -ForegroundColor Yellow
    Pop-Location
    pause
    exit 1
}

Write-Host ""

# Package application
Write-Host "Packaging application..." -ForegroundColor Cyan

# Remove old package
if (Test-Path $AppZipFile) {
    Remove-Item $AppZipFile
}

# Create ZIP
Write-Host "Creating ZIP package..." -ForegroundColor Gray

$tempDir = "eb-package-temp"
if (Test-Path $tempDir) {
    Remove-Item -Recurse -Force $tempDir
}
New-Item -ItemType Directory -Path $tempDir | Out-Null

# Copy files
Copy-Item -Recurse "app" "$tempDir\app"
Copy-Item "requirements.txt" "$tempDir\"
Copy-Item "application.py" "$tempDir\"
Copy-Item "Procfile" "$tempDir\"
Copy-Item -Recurse ".ebextensions" "$tempDir\.ebextensions"

# Create ZIP
Compress-Archive -Path "$tempDir\*" -DestinationPath $AppZipFile -Force

# Clean up temp
Remove-Item -Recurse -Force $tempDir

if (Test-Path $AppZipFile) {
    $zipSize = [math]::Round((Get-Item $AppZipFile).Length / 1MB, 2)
    Write-Host "Package created: $AppZipFile" -ForegroundColor Green
    Write-Host "Size: $zipSize MB" -ForegroundColor Gray
} else {
    Write-Host "Failed to create package!" -ForegroundColor Red
    Pop-Location
    pause
    exit 1
}

Write-Host ""

# Upload to S3
Write-Host "Preparing S3 bucket..." -ForegroundColor Cyan

# Get account ID
$accountId = aws sts get-caller-identity --query Account --output text

$bucketName = "fastapi-app-versions-$accountId"

# Check if bucket exists
$bucketExists = aws s3 ls "s3://$bucketName" 2>$null

if (-not $bucketExists) {
    Write-Host "Creating S3 bucket: $bucketName" -ForegroundColor Yellow
    aws s3 mb "s3://$bucketName" --region $Region 2>&1 | Out-Null
}

# Upload ZIP
Write-Host "Uploading application to S3..." -ForegroundColor Gray
aws s3 cp $AppZipFile "s3://$bucketName/fastapi-app-v1.0.0.zip" --region $Region 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "Application uploaded to S3" -ForegroundColor Green
} else {
    Write-Host "S3 upload failed!" -ForegroundColor Red
    Pop-Location
    pause
    exit 1
}

Pop-Location

Write-Host ""

# Deploy CloudFormation
Write-Host "Deploying CloudFormation stack..." -ForegroundColor Cyan
Write-Host "This may take 5-10 minutes..." -ForegroundColor Yellow
Write-Host ""

cd (Split-Path -Parent $MyInvocation.MyCommand.Path)

aws cloudformation deploy `
    --template-file $TemplateFile `
    --stack-name $StackName `
    --parameter-overrides file://$ParametersFile `
    --capabilities CAPABILITY_NAMED_IAM `
    --region $Region

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host "DEPLOYMENT COMPLETE!" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host ""
    
    # Get outputs
    aws cloudformation describe-stacks `
        --stack-name $StackName `
        --region $Region `
        --query "Stacks[0].Outputs[*].[OutputKey,OutputValue]" `
        --output table
    
    Write-Host ""
    
    # Get URL
    $appUrl = aws cloudformation describe-stacks `
        --stack-name $StackName `
        --region $Region `
        --query "Stacks[0].Outputs[?OutputKey=='ApplicationURL'].OutputValue" `
        --output text
    
    Write-Host "Your application is deploying at:" -ForegroundColor Cyan
    Write-Host "  $appUrl" -ForegroundColor White
    Write-Host ""
    Write-Host "Note: Environment initialization takes 5-10 minutes" -ForegroundColor Yellow
    
} else {
    Write-Host ""
    Write-Host "Stack deployment failed!" -ForegroundColor Red
    Write-Host "Check errors above" -ForegroundColor Yellow
}

Write-Host ""
pause