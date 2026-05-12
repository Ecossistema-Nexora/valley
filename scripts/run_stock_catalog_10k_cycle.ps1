param(
  [int]$TargetItems = 10000,
  [int]$MaxCategories = 200,
  [int]$MaxProductsPerCategory = 100,
  [switch]$RefreshMercado
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$RuntimeDir = Join-Path $Root "tmp\runtime"
$StatusPath = Join-Path $RuntimeDir "valley-stock-catalog-10k-cycle.json"
New-Item -ItemType Directory -Force -Path $RuntimeDir | Out-Null

function Invoke-ValleyStep {
  param(
    [string]$Name,
    [string[]]$Command
  )

  $startedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  $outputPath = Join-Path $RuntimeDir ("$Name.out.log")
  $errorPath = Join-Path $RuntimeDir ("$Name.err.log")
  $process = Start-Process -FilePath $Command[0] -ArgumentList $Command[1..($Command.Length - 1)] -WorkingDirectory $Root -NoNewWindow -PassThru -Wait -RedirectStandardOutput $outputPath -RedirectStandardError $errorPath
  return @{
    name = $Name
    started_at_utc = $startedAt
    finished_at_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    exit_code = $process.ExitCode
    stdout_log = ($outputPath | Resolve-Path).Path
    stderr_log = ($errorPath | Resolve-Path).Path
    status = $(if ($process.ExitCode -eq 0) { "ok" } else { "failed" })
  }
}

$steps = @()
$steps += Invoke-ValleyStep -Name "dropshipping_eligible_10k" -Command @(
  "python",
  "scripts\import_dropshipping_eligible_products.py",
  "--max-categories", "$MaxCategories",
  "--max-products-per-category", "$MaxProductsPerCategory",
  "--max-candidates", "$TargetItems",
  "--ignore-marketplace-advantage"
)

$importCommand = @("python", "scripts\import_real_stock_catalog.py", "--target-items", "$TargetItems")
if ($RefreshMercado) {
  $importCommand += "--refresh-mercado"
}
$steps += Invoke-ValleyStep -Name "stock_catalog_real_10k" -Command $importCommand
$steps += Invoke-ValleyStep -Name "stock_catalog_translate_ptbr" -Command @("python", "scripts\translate_stock_catalog_ptbr.py")

$status = @{
  status = $(if (($steps | Where-Object { $_.exit_code -ne 0 }).Count -eq 0) { "ok" } else { "partial" })
  service = "valley-stock-catalog-10k-cycle"
  generated_at_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  target_items = $TargetItems
  policy_path = "config/stock_catalog_import_policy.json"
  steps = $steps
}

$status | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 -Path $StatusPath
$status | ConvertTo-Json -Depth 8
