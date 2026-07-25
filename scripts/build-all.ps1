#!/usr/bin/env pwsh
# Build all 6 petclinic microservice images with git metadata labels

$ErrorActionPreference = "Stop"

$repoRoot = git rev-parse --show-toplevel
Set-Location $repoRoot

$services = @(
    "discovery-server",
    "config-server",
    "api-gateway",
    "customers-service",
    "vets-service",
    "visits-service"
)

$gitCommitApp = git -C app rev-parse --short HEAD
$gitCommitDevops = git rev-parse --short HEAD
$buildDate = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"

Write-Host "GIT_COMMIT_APP:    $gitCommitApp"
Write-Host "GIT_COMMIT_DEVOPS: $gitCommitDevops"
Write-Host "BUILD_DATE:        $buildDate"
Write-Host ""

foreach ($service in $services) {
    Write-Host "=== Building $service ===" -ForegroundColor Cyan

    docker build `
        --build-arg GIT_COMMIT_APP=$gitCommitApp `
        --build-arg GIT_COMMIT_DEVOPS=$gitCommitDevops `
        --build-arg BUILD_DATE=$buildDate `
        -f "docker/$service/Dockerfile" `
        -t "petclinic/${service}:local" `
        -t "petclinic/${service}:$gitCommitApp" `
        .

    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAILED: $service" -ForegroundColor Red
        exit 1
    }

    Write-Host "OK: $service`n" -ForegroundColor Green
}

Write-Host "All 6 images built successfully." -ForegroundColor Green
docker images --filter "reference=petclinic/*"