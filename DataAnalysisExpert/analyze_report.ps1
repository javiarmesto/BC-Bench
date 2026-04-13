param(
    [string]$ReportPath = $(
        Join-Path $PSScriptRoot "..\notebooks\result\bug-fix\report-BCApps-4699__BCApps-4766__BCApps-4822-2026-04-11.md"
    )
)

$lines = Get-Content -Path $ReportPath
$content = $lines -join "`n"

$instancesMatch = [regex]::Match($content, "\*\*Instances:\*\*\s*(.+)")
$declaredInstances = @()
if ($instancesMatch.Success) {
    $declaredInstances = $instancesMatch.Groups[1].Value.Split(',').ForEach({
        $_.Trim() -replace '^microsoft__', ''
    }) | Where-Object { $_ }
}

$rows = foreach ($line in $lines) {
    if ($line -notmatch '^\| BCApps-') {
        continue
    }

    $parts = $line.Trim('|').Split('|').ForEach({ $_.Trim() })
    if ($parts.Count -lt 8) {
        continue
    }

    [pscustomobject]@{
        Instance = $parts[0]
        Agent = $parts[1]
        Scenario = $parts[2]
        Resolved = $parts[3] -eq '✅'
        Build = $parts[4] -eq '✅'
        Turns = [int]$parts[5]
        TimeSeconds = [int]($parts[6] -replace 's$', '')
        TokensK = [int]($parts[7] -replace 'K$', '')
    }
}

$uniqueInstancesInRows = $rows.Instance | Sort-Object -Unique
$missingDeclaredInstances = $declaredInstances | Where-Object { $_ -notin $uniqueInstancesInRows }

$overall = [pscustomobject]@{
    DeclaredInstances = $declaredInstances
    InstancesWithRows = $uniqueInstancesInRows
    MissingDeclaredInstances = $missingDeclaredInstances
    RunCount = $rows.Count
    ResolvedCount = @($rows | Where-Object Resolved).Count
    BuildSuccessCount = @($rows | Where-Object Build).Count
    ResolveRate = if ($rows.Count) { [math]::Round((@($rows | Where-Object Resolved).Count / $rows.Count) * 100, 1) } else { 0 }
    AvgTimeSeconds = if ($rows.Count) { [math]::Round((($rows | Measure-Object -Property TimeSeconds -Average).Average), 1) } else { 0 }
    AvgTurns = if ($rows.Count) { [math]::Round((($rows | Measure-Object -Property Turns -Average).Average), 1) } else { 0 }
    AvgTokensK = if ($rows.Count) { [math]::Round((($rows | Measure-Object -Property TokensK -Average).Average), 1) } else { 0 }
}

$byAgent = $rows |
    Group-Object Agent |
    ForEach-Object {
        $groupRows = $_.Group
        $resolved = @($groupRows | Where-Object Resolved).Count
        [pscustomobject]@{
            Agent = $_.Name
            Runs = $groupRows.Count
            Resolved = $resolved
            ResolveRate = [math]::Round(($resolved / $groupRows.Count) * 100, 1)
            AvgTimeSeconds = [math]::Round((($groupRows | Measure-Object -Property TimeSeconds -Average).Average), 1)
            AvgTurns = [math]::Round((($groupRows | Measure-Object -Property Turns -Average).Average), 1)
            AvgTokensK = [math]::Round((($groupRows | Measure-Object -Property TokensK -Average).Average), 1)
        }
    } |
    Sort-Object Agent

$byScenario = $rows |
    Group-Object Scenario |
    ForEach-Object {
        $groupRows = $_.Group
        $resolved = @($groupRows | Where-Object Resolved).Count
        [pscustomobject]@{
            Scenario = $_.Name
            Runs = $groupRows.Count
            Resolved = $resolved
            ResolveRate = [math]::Round(($resolved / $groupRows.Count) * 100, 1)
            AvgTimeSeconds = [math]::Round((($groupRows | Measure-Object -Property TimeSeconds -Average).Average), 1)
            AvgTurns = [math]::Round((($groupRows | Measure-Object -Property Turns -Average).Average), 1)
            AvgTokensK = [math]::Round((($groupRows | Measure-Object -Property TokensK -Average).Average), 1)
        }
    } |
    Sort-Object Scenario

$byAgentScenario = $rows |
    Group-Object Agent, Scenario |
    ForEach-Object {
        $groupRows = $_.Group
        $resolved = @($groupRows | Where-Object Resolved).Count
        [pscustomobject]@{
            Agent = $groupRows[0].Agent
            Scenario = $groupRows[0].Scenario
            Runs = $groupRows.Count
            Resolved = $resolved
            ResolveRate = [math]::Round(($resolved / $groupRows.Count) * 100, 1)
            AvgTimeSeconds = [math]::Round((($groupRows | Measure-Object -Property TimeSeconds -Average).Average), 1)
            AvgTurns = [math]::Round((($groupRows | Measure-Object -Property Turns -Average).Average), 1)
            AvgTokensK = [math]::Round((($groupRows | Measure-Object -Property TokensK -Average).Average), 1)
        }
    } |
    Sort-Object Agent, Scenario

$bestResolvedPerInstance = $rows |
    Where-Object Resolved |
    Group-Object Instance |
    ForEach-Object {
        $_.Group |
            Sort-Object TimeSeconds, Turns, TokensK |
            Select-Object -First 1 |
            Select-Object Instance, Agent, Scenario, TimeSeconds, Turns, TokensK
    } |
    Sort-Object Instance

$fastestResolved = $rows |
    Where-Object Resolved |
    Sort-Object TimeSeconds, Turns, TokensK |
    Select-Object -First 1 Instance, Agent, Scenario, TimeSeconds, Turns, TokensK

$slowestResolved = $rows |
    Where-Object Resolved |
    Sort-Object TimeSeconds, Turns, TokensK -Descending |
    Select-Object -First 1 Instance, Agent, Scenario, TimeSeconds, Turns, TokensK

$result = [pscustomobject]@{
    Overall = $overall
    ByAgent = $byAgent
    ByScenario = $byScenario
    ByAgentScenario = $byAgentScenario
    BestResolvedPerInstance = $bestResolvedPerInstance
    FastestResolved = $fastestResolved
    SlowestResolved = $slowestResolved
}

$result | ConvertTo-Json -Depth 6