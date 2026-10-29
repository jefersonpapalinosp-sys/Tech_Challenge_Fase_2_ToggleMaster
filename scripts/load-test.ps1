param(
    [int]$Requests = 500,
    [int]$Concurrency = 20,
    [string]$FlagName = 'load-test-flag'
)

$ErrorActionPreference = 'Stop'

if ($Requests -lt 1 -or $Concurrency -lt 1) {
    throw 'Requests e Concurrency devem ser maiores que zero.'
}

$client = [System.Net.Http.HttpClient]::new()
$client.Timeout = [TimeSpan]::FromSeconds(15)
$completed = 0
$failed = 0
$watch = [Diagnostics.Stopwatch]::StartNew()

try {
    while ($completed + $failed -lt $Requests) {
        $batchSize = [Math]::Min($Concurrency, $Requests - $completed - $failed)
        $tasks = for ($i = 0; $i -lt $batchSize; $i++) {
            $userId = "load-$($completed + $failed + $i)"
            $uri = "http://localhost:18004/evaluate?user_id=$userId&flag_name=$FlagName"
            $client.GetAsync($uri)
        }
        [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]$tasks)
        foreach ($task in $tasks) {
            if ($task.Result.IsSuccessStatusCode) { $completed++ } else { $failed++ }
            $task.Result.Dispose()
        }
        Write-Progress -Activity 'Gerando carga' -Status "$completed concluídas, $failed falhas" -PercentComplete ((($completed + $failed) / $Requests) * 100)
    }
} finally {
    $watch.Stop()
    $client.Dispose()
}

$rate = if ($watch.Elapsed.TotalSeconds -gt 0) { $completed / $watch.Elapsed.TotalSeconds } else { 0 }
Write-Host ("Concluídas: {0}; falhas: {1}; duração: {2:N2}s; taxa: {3:N2} req/s" -f $completed, $failed, $watch.Elapsed.TotalSeconds, $rate)
