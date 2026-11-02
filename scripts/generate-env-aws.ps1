param(
    [string]$CredentialsFile = "docs\LAB 2.txt",
    [string]$OutputFile = ".env.aws",
    [string]$Region = "us-east-1"
)

$ErrorActionPreference = "Stop"

$awsPath = Join-Path $env:LOCALAPPDATA "Programs\Amazon\AWSCLIV2\aws.exe"
if (-not (Test-Path -LiteralPath $awsPath)) {
    throw "AWS CLI não encontrada em $awsPath"
}
if (-not (Test-Path -LiteralPath $CredentialsFile)) {
    throw "Arquivo de credenciais não encontrado: $CredentialsFile"
}

function Get-LabCredential {
    param(
        [string[]]$Lines,
        [string]$Name
    )

    $line = $Lines | Where-Object { $_ -match "^$([regex]::Escape($Name))=" } | Select-Object -First 1
    if (-not $line) {
        throw "Credencial $Name não encontrada em $CredentialsFile"
    }
    return ($line -split "=", 2)[1].Trim()
}

function Get-AwsSecretObject {
    param([string]$SecretId)

    $secretString = & $awsPath secretsmanager get-secret-value `
        --secret-id $SecretId `
        --region $Region `
        --query SecretString `
        --output text
    if ($LASTEXITCODE -ne 0 -or -not $secretString) {
        throw "Falha ao recuperar $SecretId"
    }
    return $secretString | ConvertFrom-Json
}

function Assert-SingleLineValue {
    param(
        [string]$Name,
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "O valor de $Name está vazio."
    }
    if ($Value -match "[\r\n]") {
        throw "O valor de $Name contém quebra de linha e não pode ser gravado no .env."
    }
}

$credentialLines = Get-Content -LiteralPath $CredentialsFile
$accessKey = Get-LabCredential -Lines $credentialLines -Name "aws_access_key_id"
$secretKey = Get-LabCredential -Lines $credentialLines -Name "aws_secret_access_key"
$sessionToken = Get-LabCredential -Lines $credentialLines -Name "aws_session_token"

$env:AWS_ACCESS_KEY_ID = $accessKey
$env:AWS_SECRET_ACCESS_KEY = $secretKey
$env:AWS_SESSION_TOKEN = $sessionToken

$identity = & $awsPath sts get-caller-identity --region $Region --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or -not $identity.Account) {
    throw "As credenciais do AWS Academy não estão válidas."
}

$auth = Get-AwsSecretObject -SecretId "togglemaster/auth"
$flag = Get-AwsSecretObject -SecretId "togglemaster/flag"
$targeting = Get-AwsSecretObject -SecretId "togglemaster/targeting"
$evaluation = Get-AwsSecretObject -SecretId "togglemaster/evaluation"

$values = [ordered]@{
    AWS_ACCESS_KEY_ID      = $accessKey
    AWS_SECRET_ACCESS_KEY  = $secretKey
    AWS_SESSION_TOKEN      = $sessionToken
    AUTH_DATABASE_URL      = $auth.DATABASE_URL
    FLAGS_DATABASE_URL     = $flag.DATABASE_URL
    TARGETING_DATABASE_URL = $targeting.DATABASE_URL
    REDIS_URL              = $evaluation.REDIS_URL
    MASTER_KEY             = $auth.MASTER_KEY
    SERVICE_API_KEY        = $evaluation.SERVICE_API_KEY
    AUTH_PORT              = "8001"
    FLAG_PORT              = "8002"
    TARGETING_PORT         = "8003"
    EVALUATION_PORT        = "8004"
    ANALYTICS_PORT         = "8005"
}

foreach ($entry in $values.GetEnumerator()) {
    Assert-SingleLineValue -Name $entry.Key -Value ([string]$entry.Value)
}

$header = @(
    "# Gerado por scripts/generate-env-aws.ps1",
    "# Conta AWS: $($identity.Account) | Região: $Region",
    "# Contém segredos e credenciais temporárias. Não versionar nem compartilhar.",
    ""
)
$content = $header + @($values.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" })
$resolvedOutput = [IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputFile))
[IO.File]::WriteAllLines($resolvedOutput, $content, (New-Object Text.UTF8Encoding($false)))

Write-Output ([pscustomobject]@{
    File = $resolvedOutput
    Account = $identity.Account
    Region = $Region
    Variables = $values.Count
    SecretsPrinted = $false
})
