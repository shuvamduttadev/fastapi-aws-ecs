# destroy-beanstalk.ps1
Write-Host "=== Destroy Elastic Beanstalk Infrastructure ===" -ForegroundColor Red
Write-Host ""

$StackName = "fastapi-beanstalk-infrastructure"
$Region = "ap-south-1"

$confirm = Read-Host "Type 'destroy' to confirm"

if ($confirm -ne "destroy") {
    Write-Host "Cancelled" -ForegroundColor Yellow
    pause
    exit 0
}

Write-Host ""
Write-Host "Deleting stack..." -ForegroundColor Cyan

aws cloudformation delete-stack `
    --stack-name $StackName `
    --region $Region

Write-Host "Waiting for deletion..." -ForegroundColor Yellow

aws cloudformation wait stack-delete-complete `
    --stack-name $StackName `
    --region $Region

Write-Host ""
Write-Host "Stack deleted!" -ForegroundColor Green
pause