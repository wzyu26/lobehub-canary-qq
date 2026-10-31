# Registers the runners with a token from the repository's "New self-hosted runner" page.
# The token is read here so it never lands in chat, shell history or a file.
$secure = Read-Host 'Paste the runner registration token' -AsSecureString
$env:RUNNER_TOKEN = [System.Net.NetworkCredential]::new('', $secure).Password
Set-Location $PSScriptRoot
docker compose up -d --build
Remove-Item Env:RUNNER_TOKEN
docker compose ps
