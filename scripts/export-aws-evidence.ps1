param(
    [string]$CredentialsFile = "docs\LAB 2.txt",
    [string]$OutputDirectory = "docs\evidencias_aws_2026-10-30",
    [string]$Region = "us-east-1",
    [string]$ClusterName = "ekstogglemaster"
)

$ErrorActionPreference = "Stop"
$awsPath = Join-Path $env:LOCALAPPDATA "Programs\Amazon\AWSCLIV2\aws.exe"
$awsDir = Split-Path -Parent $awsPath
$env:PATH = "$awsDir;$env:PATH"

$credentialLines = Get-Content -LiteralPath $CredentialsFile
$env:AWS_ACCESS_KEY_ID = (($credentialLines | Where-Object { $_ -match '^aws_access_key_id=' }) -split '=', 2)[1]
$env:AWS_SECRET_ACCESS_KEY = (($credentialLines | Where-Object { $_ -match '^aws_secret_access_key=' }) -split '=', 2)[1]
$env:AWS_SESSION_TOKEN = (($credentialLines | Where-Object { $_ -match '^aws_session_token=' }) -split '=', 2)[1]

$outputPath = [IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputDirectory))
[IO.Directory]::CreateDirectory($outputPath) | Out-Null
$kubeconfigPath = Join-Path $env:TEMP "togglemaster-evidence-kubeconfig"
$generated = New-Object System.Collections.Generic.List[object]

function Save-Evidence {
    param(
        [string]$Number,
        [string]$Slug,
        [string]$Title,
        [string]$Command,
        [scriptblock]$Collect
    )

    $captured = & $Collect 2>&1 | Out-String -Width 220
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"
    $content = @"
TOGGLEMASTER - EVIDÊNCIA AWS CLI / KUBERNETES
Conta: 533267349027 | Região: $Region | Data: $timestamp

$Title
$('=' * $Title.Length)

Comando equivalente:
$Command

Saída:
$($captured.TrimEnd())

Observação: nenhum valor de senha, token, MASTER_KEY ou API key foi exibido.
"@

    $baseName = "$Number`_$Slug"
    $textPath = Join-Path $outputPath "$baseName.txt"
    $htmlPath = Join-Path $outputPath "$baseName.html"
    $pngPath = Join-Path $outputPath "$baseName.png"
    [IO.File]::WriteAllText($textPath, $content, (New-Object Text.UTF8Encoding($false)))

    $encoded = [Net.WebUtility]::HtmlEncode($content)
    $html = @"
<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<style>
  html, body { margin: 0; background: #0f172a; color: #e5e7eb; }
  body { padding: 34px; font-family: Consolas, "Cascadia Mono", monospace; }
  .frame { border: 1px solid #334155; border-radius: 14px; overflow: hidden; box-shadow: 0 14px 36px rgba(0,0,0,.35); }
  .bar { background: #172033; padding: 16px 22px; color: #ffb347; font: 700 20px Arial, sans-serif; border-bottom: 1px solid #334155; }
  pre { margin: 0; padding: 24px; white-space: pre-wrap; overflow-wrap: anywhere; font-size: 16px; line-height: 1.38; }
</style>
</head>
<body><div class="frame"><div class="bar">AWS • ToggleMaster • Evidência técnica</div><pre>$encoded</pre></div></body>
</html>
"@
    [IO.File]::WriteAllText($htmlPath, $html, (New-Object Text.UTF8Encoding($false)))
    $generated.Add([pscustomobject]@{ Number=$Number; Title=$Title; BaseName=$baseName; Text=$textPath; Html=$htmlPath; Png=$pngPath })
}

try {
    $identity = & $awsPath sts get-caller-identity --region $Region --output json | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0 -or $identity.Account -ne "533267349027") {
        throw "Credenciais inválidas ou conta inesperada."
    }

    & $awsPath eks update-kubeconfig --name $ClusterName --region $Region --kubeconfig $kubeconfigPath | Out-Null
    $env:KUBECONFIG = $kubeconfigPath

    Save-Evidence "01" "identidade" "Identidade AWS e contexto da coleta" `
        "aws sts get-caller-identity" {
            & $awsPath sts get-caller-identity --region $Region --output table
        }

    Save-Evidence "02" "eks_nodegroup" "EKS e Managed Node Group" `
        "aws eks describe-cluster / describe-nodegroup" {
            & $awsPath eks describe-cluster --name $ClusterName --region $Region `
                --query 'cluster.{Name:name,Status:status,Version:version,EndpointPublic:resourcesVpcConfig.endpointPublicAccess,VpcId:resourcesVpcConfig.vpcId,ClusterSG:resourcesVpcConfig.clusterSecurityGroupId}' --output table
            & $awsPath eks describe-nodegroup --cluster-name $ClusterName --nodegroup-name tgmnodegroup --region $Region `
                --query 'nodegroup.{Name:nodegroupName,Status:status,InstanceTypes:instanceTypes,Min:scalingConfig.minSize,Desired:scalingConfig.desiredSize,Max:scalingConfig.maxSize,CapacityType:capacityType}' --output table
            kubectl get nodes -o wide
        }

    Save-Evidence "03" "ecr" "Repositórios e imagens no Amazon ECR" `
        "aws ecr describe-repositories / describe-images" {
            & $awsPath ecr describe-repositories --region $Region `
                --query "repositories[?starts_with(repositoryName, 'namespace/')].{Repository:repositoryName,Mutability:imageTagMutability,ScanOnPush:imageScanningConfiguration.scanOnPush}" --output table
            foreach ($repository in @('namespace/auth-service','namespace/lag-service','namespace/targeting-service','namespace/evaluation-service','namespace/analytics-service')) {
                & $awsPath ecr describe-images --repository-name $repository --region $Region `
                    --query "imageDetails[].{Repository:'$repository',Tags:to_string(imageTags),Pushed:imagePushedAt,SizeBytes:imageSizeInBytes}" --output table
            }
        }

    Save-Evidence "04" "rds" "Três bancos PostgreSQL no Amazon RDS" `
        "aws rds describe-db-instances" {
            & $awsPath rds describe-db-instances --region $Region `
                --query "DBInstances[?contains(['db-authservice','dbflags','dbtargeting'],DBInstanceIdentifier)].{DB:DBInstanceIdentifier,Status:DBInstanceStatus,Engine:Engine,Version:EngineVersion,Class:DBInstanceClass,Endpoint:Endpoint.Address,Port:Endpoint.Port,Public:PubliclyAccessible,Encrypted:StorageEncrypted}" --output table
        }

    Save-Evidence "05" "elasticache" "ElastiCache Redis com TLS e autenticação" `
        "aws elasticache describe-replication-groups" {
            & $awsPath elasticache describe-replication-groups --replication-group-id redisevaluation --region $Region `
                --query 'ReplicationGroups[0].{Id:ReplicationGroupId,Status:Status,ClusterEnabled:ClusterEnabled,Endpoint:ConfigurationEndpoint.Address,Port:ConfigurationEndpoint.Port,TransitEncryption:TransitEncryptionEnabled,AtRestEncryption:AtRestEncryptionEnabled,AuthTokenEnabled:AuthTokenEnabled,Shards:length(NodeGroups)}' --output table
        }

    Save-Evidence "06" "sqs" "Fila SQS tgmqueue" `
        "aws sqs get-queue-attributes" {
            & $awsPath sqs get-queue-attributes `
                --queue-url 'https://sqs.us-east-1.amazonaws.com/533267349027/tgmqueue' `
                --attribute-names QueueArn SqsManagedSseEnabled ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible CreatedTimestamp `
                --region $Region --query Attributes --output table
        }

    Save-Evidence "07" "dynamodb" "Tabela DynamoDB ToggleMasterAnalytics" `
        "aws dynamodb describe-table" {
            & $awsPath dynamodb describe-table --table-name ToggleMasterAnalytics --region $Region `
                --query 'Table.{Name:TableName,Status:TableStatus,BillingMode:BillingModeSummary.BillingMode,ItemCount:ItemCount,SizeBytes:TableSizeBytes,KeySchema:KeySchema,Encryption:SSEDescription.Status,Arn:TableArn}' --output json
            $valuesPath = Join-Path $env:TEMP "togglemaster-evidence-ddb-values.json"
            try {
                [IO.File]::WriteAllText($valuesPath, '{":flag":{"S":"load-postman-fiap"}}', (New-Object Text.UTF8Encoding($false)))
                & $awsPath dynamodb scan --table-name ToggleMasterAnalytics --region $Region `
                    --filter-expression 'flag_name = :flag' --expression-attribute-values "file://$valuesPath" `
                    --select COUNT --query '{Flag:`load-postman-fiap`,MatchingItems:Count,Scanned:ScannedCount}' --output table
            }
            finally {
                Remove-Item -LiteralPath $valuesPath -Force -ErrorAction SilentlyContinue
            }
        }

    Save-Evidence "08" "security_groups" "Security Groups: EKS para RDS e Redis" `
        "aws ec2 describe-security-groups" {
            foreach ($group in @('sg-079be737f17db5c6b','sg-040bd24ce7d5d78c9','sg-0992b8d82f96040eb','sg-0c7417910e3b14dc4','sg-05eb72e24a646803e')) {
                & $awsPath ec2 describe-security-groups --group-ids $group --region $Region `
                    --query 'SecurityGroups[0].{Id:GroupId,Name:GroupName,Vpc:VpcId,Ingress:IpPermissions[].{Protocol:IpProtocol,From:FromPort,To:ToPort,SourceSG:UserIdGroupPairs[].GroupId,IPv4:IpRanges[].CidrIp}}' --output json
            }
        }

    Save-Evidence "09" "kubernetes" "Workloads, pods, serviços, Ingress e HPA" `
        "kubectl get deployments,pods,services,ingress,hpa -A" {
            kubectl get deployments -A -l app.kubernetes.io/part-of=togglemaster
            kubectl get pods -A -l app.kubernetes.io/part-of=togglemaster
            kubectl get ingress -A
            kubectl get hpa -A
        }

    Save-Evidence "10" "external_secrets" "External Secrets sincronizados" `
        "kubectl get clustersecretstore,externalsecret -A" {
            kubectl get clustersecretstore
            kubectl get externalsecret -A
            kubectl get pods -n external-secrets
        }

    Save-Evidence "11" "load_balancer" "Load Balancer do ingress-nginx" `
        "aws elb describe-load-balancers / describe-instance-health" {
            & $awsPath elb describe-load-balancers --region $Region `
                --query 'LoadBalancerDescriptions[].{Name:LoadBalancerName,DNSName:DNSName,Scheme:Scheme,VpcId:VPCId,Ports:ListenerDescriptions[].Listener.LoadBalancerPort,Instances:Instances[].InstanceId,SecurityGroups:SecurityGroups}' --output json
            $loadBalancerName = (& $awsPath elb describe-load-balancers --region $Region --query 'LoadBalancerDescriptions[0].LoadBalancerName' --output text).Trim()
            & $awsPath elb describe-instance-health --load-balancer-name $loadBalancerName --region $Region --output table
            kubectl get service my-release-ingress-nginx-controller -n ingress-nginx -o wide
        }

    Save-Evidence "12" "secrets_names" "AWS Secrets Manager: nomes e datas, sem valores" `
        "aws secretsmanager list-secrets" {
            & $awsPath secretsmanager list-secrets --region $Region `
                --query "SecretList[?starts_with(Name, 'togglemaster/')].{Name:Name,LastChanged:LastChangedDate,RotationEnabled:RotationEnabled,ARN:ARN}" --output table
        }

    $chromeCandidates = @(
        "C:\Program Files\Google\Chrome\Application\chrome.exe",
        "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
        "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
    )
    $browser = $chromeCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $browser) {
        throw "Chrome/Edge não encontrado para gerar os PNGs. Os TXT/HTML foram criados."
    }

    foreach ($item in $generated) {
        $uri = [uri]$item.Html
        $lineCount = @(Get-Content -LiteralPath $item.Text).Count
        $screenshotHeight = [Math]::Max(1200, [Math]::Min(8000, ($lineCount * 24) + 260))
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        & $browser --headless=new --disable-gpu --hide-scrollbars --window-size=1800,$screenshotHeight `
            --screenshot=$($item.Png) $uri.AbsoluteUri 2>$null | Out-Null
        $browserExitCode = $LASTEXITCODE
        $ErrorActionPreference = $previousErrorActionPreference
        if ($browserExitCode -ne 0) {
            throw "Falha do navegador ao renderizar $($item.Html) (exit code $browserExitCode)"
        }
        if (-not (Test-Path -LiteralPath $item.Png)) {
            throw "Falha ao gerar $($item.Png)"
        }
    }

    $indexLines = @(
        "# Evidencias AWS - ToggleMaster - 2026-10-30",
        "",
        "Capturas geradas de consultas somente leitura na conta `533267349027`, região `us-east-1`.",
        "Nenhuma senha, token, MASTER_KEY ou API key foi incluída.",
        ""
    )
    foreach ($item in $generated) {
        $indexLines += "- [$($item.Title)]($($item.BaseName).png)"
    }
    [IO.File]::WriteAllLines((Join-Path $outputPath "README.md"), $indexLines, (New-Object Text.UTF8Encoding($false)))

    Write-Output ([pscustomobject]@{
        OutputDirectory = $outputPath
        EvidenceCount = $generated.Count
        PngCount = @(Get-ChildItem -LiteralPath $outputPath -Filter '*.png').Count
        SecretsExposed = $false
    })
}
finally {
    Remove-Item -LiteralPath $kubeconfigPath -Force -ErrorAction SilentlyContinue
}
