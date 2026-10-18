function Get-RandomString {
    param([int]$Length = 16)
    $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return -join (1..$Length | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
}

function Get-PasswordHash {
    param(
        [Parameter(Mandatory)][string]$Password,
        [Parameter(Mandatory)][string]$Salt
    )
    $combined = [Text.Encoding]::UTF8.GetBytes($Password + $Salt)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    return [Convert]::ToBase64String($sha256.ComputeHash($combined))
}

function Test-Password {
    param(
        [Parameter(Mandatory)][string]$InputPassword,
        [Parameter(Mandatory)][string]$StoredHash,
        [Parameter(Mandatory)][string]$StoredSalt
    )
    $computed = Get-PasswordHash $InputPassword $StoredSalt
    return ($computed -eq $StoredHash)
}

function Protect-JsonData {
    param([string]$Path, $Data)
    $Data | ConvertTo-Json -Depth 10 | Out-File $Path -Encoding UTF8
}

function Import-JsonData {
    param([string]$Path, $Default = @())
    if (-not (Test-Path $Path)) { return $Default }
    $txt = Get-Content $Path -Raw -Encoding UTF8
    return $txt | ConvertFrom-Json -Depth 10
}
