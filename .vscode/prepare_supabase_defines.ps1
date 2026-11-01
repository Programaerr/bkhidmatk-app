$ErrorActionPreference = 'Stop'
$envPath = Join-Path (Get-Location) '.env'
$definesPath = Join-Path (Get-Location) '.dart-defines.json'

if (-not (Test-Path -LiteralPath $envPath -PathType Leaf)) {
    throw 'Missing .env. Add SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY.'
}

$values = @{}
foreach ($line in Get-Content -LiteralPath $envPath) {
    if ($line -match '^\s*(?:export\s+)?(SUPABASE_URL|SUPABASE_PUBLISHABLE_KEY|SUPABASE_ANON_KEY)\s*=\s*(.*?)\s*$') {
        $name = $matches[1]
        $value = $matches[2].Trim()
        if ($value.Length -ge 2 -and
            (($value.StartsWith('"') -and $value.EndsWith('"')) -or
                ($value.StartsWith("'") -and $value.EndsWith("'")))) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        $values[$name] = $value
    }
}

$url = $values['SUPABASE_URL']
$key = $values['SUPABASE_PUBLISHABLE_KEY']
if ([string]::IsNullOrWhiteSpace($key)) {
    $key = $values['SUPABASE_ANON_KEY']
}

$parsedUrl = $null
if ([string]::IsNullOrWhiteSpace($url) -or
    -not [uri]::TryCreate($url, [System.UriKind]::Absolute, [ref]$parsedUrl) -or
    $parsedUrl.Scheme -ne 'https') {
    throw 'SUPABASE_URL in .env must be a valid HTTPS URL.'
}
if ([string]::IsNullOrWhiteSpace($key)) {
    throw 'Missing SUPABASE_PUBLISHABLE_KEY (or SUPABASE_ANON_KEY) in .env.'
}

$defines = @{
    SUPABASE_URL = $url
    SUPABASE_PUBLISHABLE_KEY = $key
}
$json = ConvertTo-Json -InputObject $defines
[System.IO.File]::WriteAllText(
    $definesPath,
    $json,
    [System.Text.UTF8Encoding]::new($false)
)
Write-Output 'Supabase configuration prepared for Flutter.'
