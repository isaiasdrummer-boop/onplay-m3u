$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$raw = Join-Path $env:TEMP 'onplay_raw'
New-Item -ItemType Directory -Path $raw -Force | Out-Null

foreach ($i in 1..8) {
    $url = "https://listas.oneplayhd.com/lista0$i.txt"
    $dest = Join-Path $raw "lista0$i.txt"
    $ok = $false
    for ($t = 1; $t -le 3 -and -not $ok; $t++) {
        try {
            curl.exe -s -m 60 -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64)' -o $dest $url
            if ((Get-Item $dest).Length -gt 1000) { $ok = $true }
        } catch { Start-Sleep -Seconds 5 }
    }
    if (-not $ok) { throw "Falha ao baixar $url" }
    Write-Output "lista0$i.txt baixada ($((Get-Item $dest).Length) bytes)"
}

$ADULT_GROUPS = @('Canais | Adultos', 'Canais | XXX Adultos')
$ADULT_NAME = '(?i)(xxx|playboy|sex|sextreme|sexy|\+18|porn|erot|brazzers|bangbros|redtraffic|fap\s*tv|penthouse|hustler|dorcel|vivid|redlight|milf|mofos|anal|blowjob|gangbang|hardcore|interracial|fetiche|visit-x|private\s*tv|mulher\s*melao|hotwife)'

function Norm([string]$s) {
    if ([string]::IsNullOrEmpty($s)) { return '' }
    $d = $s.Normalize([System.Text.NormalizationForm]::FormD)
    return ([regex]::Replace($d, '\p{M}', '')).ToLowerInvariant()
}

function Test-Adult([string]$group, [string]$name) {
    if ($ADULT_GROUPS -contains ($group.Trim())) { return $true }
    $n = Norm $name
    if ($n -match 'adult' -and $n -notmatch 'adult swim') { return $true }
    if ($n -match $ADULT_NAME) { return $true }
    return $false
}

$MG_PATTERN = '(minas|alterosa|\bmg\b|candides)'
$MG_GROUP = 'canais | abertos'

$FOOT_GROUP_REMOVE = '(campeonato|copa do mundo|libertadores|sud-?americana|futsal|jogos do dia|sportynet)'
$FOOT_NAME_REMOVE = '(brasileirao|copinha|copa|campeonato|futebol|futsal|caze|onefootball|prime esportes|furacao|ge tv|globoplay|kings league|flamengo|manc?hester|mutv|barca|desimpedidos|sportynet|xsports|jogos do dia)'

$STATE_KEEP = '(minas|\bmg\b)'
$STATE_EXCLUDE = '(sapo nao lava|pe na cova|to de graca|rock to you|se rir|dani se|go go loser|880 am|paranaiba de uberlandia|paranaiba uberlandia)'
$STATE_WORDS = '(acre|alagoas|amapa|amazonas|bahia|ceara|distrito federal|espirito santo|goias|maranhao|mato grosso do sul|mato grosso|minas gerais|minas|paraiba|parana|pernambuco|piaui|rio de janeiro|rio grande do norte|rio grande do sul|rondonia|roraima|santa catarina|sao paulo|sergipe|tocantins|\bac\b|\bal\b|\bam\b|\bap\b|\bba\b|\bce\b|\bdf\b|\bes\b|\bgo\b|\bma\b|\bmg\b|\bms\b|\bmt\b|\bpa\b|\bpb\b|\bpe\b|\bpi\b|\bpr\b|\brj\b|\brn\b|\bro\b|\brr\b|\brs\b|\bsc\b|\bse\b|\bsp\b|\bto\b)'

function Test-Keep([string]$group, [string]$name) {
    $g = Norm $group
    $n = Norm $name
    if ($g -eq $MG_GROUP) {
        return ($n -match $MG_PATTERN)
    }
    if ($g -match $FOOT_GROUP_REMOVE) { return $false }
    if ($n -match $FOOT_NAME_REMOVE -and $n -notmatch '(premiere|sportv)') { return $false }
    if ($n -notmatch $STATE_EXCLUDE -and $n -match $STATE_WORDS) {
        return ($n -match $STATE_KEEP)
    }
    return $true
}

function Clean-Name([string]$n) {
    $n = $n.Trim()
    $prev = ''
    while ($n -ne $prev) {
        $prev = $n
        $n = [regex]::Replace($n, '^\s*\[[^\]]*\]\s*', '')
        $n = [regex]::Replace($n, '\s*\[[^\]]*\]\s*$', '')
        $n = $n.Trim()
    }
    $prev = ''
    while ($n -ne $prev) {
        $prev = $n
        $n = [regex]::Replace($n, '(?i)\s*[-–|:]\s*(4k|uhd|fhd|full\s*hd|fullhd|hd|sd|hevc|hdr|hdr10)\s*$', '')
        $n = [regex]::Replace($n, '(?i)\s+(4k|uhd|fhd|full\s*hd|fullhd|hevc|hdr|hdr10)\s*$', '')
        $n = $n.Trim()
    }
    $n = [regex]::Replace($n, '\s{2,}', ' ')
    if ([string]::IsNullOrWhiteSpace($n)) { return $null }
    return $n
}

function Clean-Group([string]$g) {
    $g = $g.Trim()
    $g = [regex]::Replace($g, '(?i)\s*[|]\s*(4k|uhd|fhd|full\s*hd|fullhd|hd|sd|hevc|hdr)\s*', '')
    $g = [regex]::Replace($g, '(?i)\s(4k|uhd|fhd|full\s*hd|fullhd|hevc|hdr)\s*$', '')
    $g = [regex]::Replace($g, '\s{2,}', ' ')
    return $g.Trim()
}

$all = New-Object 'System.Collections.Generic.List[object]'
$seenUrls = New-Object 'System.Collections.Generic.HashSet[string]'
$removed = 0
$data = Get-Date -Format 'yyyy-MM-dd HH:mm'

for ($i = 1; $i -le 8; $i++) {
    $lines = [System.IO.File]::ReadAllLines((Join-Path $raw "lista0$i.txt"))
    $tvgUrl = ''
    foreach ($line in $lines) {
        if ($line -match '^#EXTM3U' -and $line -match 'x-tvg-url="([^"]*)"') { $tvgUrl = $matches[1]; break }
    }
    $out = [System.Collections.Generic.List[string]]::new()
    if ($tvgUrl) { $out.Add("#EXTM3U x-tvg-url=`"$tvgUrl`"") } else { $out.Add('#EXTM3U') }
    $cnt = 0
    for ($n = 0; $n -lt $lines.Count; $n++) {
        $line = $lines[$n].Trim()
        if ($line -match '^#EXTINF') {
            $url = ''
            for ($m = $n + 1; $m -lt $lines.Count; $m++) {
                $cand = $lines[$m].Trim()
                if ($cand -match '^#') { continue }
                $url = $cand; $n = $m; break
            }
            if (-not $url) { continue }
            $name = $line.Split(',')[-1].Trim()
            if ($line -match 'tvg-name="([^"]*)"') { $name = $matches[1] }
            $group = 'Outros'
            if ($line -match 'group-title="([^"]*)"') { $group = $matches[1] }
            if (Test-Adult $group $name) { $removed++; continue }
            if (-not (Test-Keep $group $name)) { $removed++; continue }
            $out.Add($line)
            $out.Add($url)
            $cnt++
            $logo = ''
            if ($line -match 'tvg-logo="([^"]*)"') { $logo = $matches[1] }
            $tvgId = ''
            if ($line -match 'tvg-id="([^"]*)"') { $tvgId = $matches[1] }
            $real = Clean-Name $name
            if (-not $real) { $real = Clean-Name ([regex]::Replace($name, '(?i)[\[\]]', ' ')) }
            if (-not $real) { continue }
            $obj = [pscustomobject]@{
                Real   = $real
                Group  = Clean-Group $group
                Logo   = $logo
                TvgId  = $tvgId
                Url    = $url
                TvgUrl = $tvgUrl
            }
            if ($seenUrls.Add($url)) { $all.Add($obj) }
        }
    }
    [System.IO.File]::WriteAllLines((Join-Path $PSScriptRoot "lista0$i.m3u"), $out, $utf8)
}

$out = [System.Collections.Generic.List[string]]::new()
if ($all.Count -gt 0) {
    $firstTvg = ($all | Where-Object { $_.TvgUrl } | Select-Object -First 1).TvgUrl
    if ($firstTvg) { $out.Add("#EXTM3U x-tvg-url=`"$firstTvg`"") } else { $out.Add('#EXTM3U') }
} else {
    $out.Add('#EXTM3U')
}
foreach ($c in $all) {
    $escName = [System.Net.WebUtility]::HtmlDecode($c.Real)
    $escGroup = [System.Net.WebUtility]::HtmlDecode($c.Group)
    $escLogo = [System.Net.WebUtility]::HtmlDecode($c.Logo)
    $tvgId = if ($c.TvgId) { ' tvg-id="' + [System.Net.WebUtility]::HtmlDecode($c.TvgId) + '"' } else { '' }
    $out.Add("#EXTINF:-1$tvgId tvg-name=`"$escName`" tvg-logo=`"$escLogo`" group-title=`"$escGroup`",$escName")
    $out.Add($c.Url)
}
[System.IO.File]::WriteAllLines((Join-Path $PSScriptRoot 'todos_os_canais.m3u'), $out, $utf8)

$catalog = [System.Collections.Generic.List[string]]::new()
$byGroup = $all | Group-Object Group | Sort-Object Name
$totalNomes = 0
foreach ($g in $byGroup) {
    $nomesUnicos = $g.Group | Select-Object -ExpandProperty Real -Unique | Sort-Object
    $totalNomes += $nomesUnicos.Count
    $catalog.Add("=== GRUPO: $($g.Name) ($($g.Count) canais / $($nomesUnicos.Count) nomes) ===")
    foreach ($nm in $nomesUnicos) { $catalog.Add("  $nm") }
    $catalog.Add('')
    $catalog.Add('')
}
[System.IO.File]::WriteAllLines((Join-Path $PSScriptRoot 'canais_por_grupo.txt'), $catalog, $utf8)

$resumo = "ATUALIZACAO AUTOMATICA - $data`n`nCanais unicos no M3U: $($all.Count)`nGrupos: $($byGroup.Count)`nCanais removidos (filtros): $removed`n`nBaixado de: https://listas.oneplayhd.com/lista01..08.txt"
[System.IO.File]::WriteAllText((Join-Path $PSScriptRoot 'LEIA-ME.txt'), $resumo, $utf8)
Write-Output "OK - $($all.Count) canais unicos, $($byGroup.Count) grupos, $removed removidos"