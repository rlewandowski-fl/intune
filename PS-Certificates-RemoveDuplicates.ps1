#Suppress notifications
$InformationPreference = "SilentlyContinue"
$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "SilentlyContinue"

#Find and remove duplicate certificates from personal computer certificates
$cert = @{}
Get-ChildItem -Recurse Cert:\LocalMachine\My |
    Where-Object {$_.Issuer -like "*Fole*"} |
    ForEach-Object {
        $subject = $_.Subject
        If (!$cert.ContainsKey($subject)) {
            $cert[$subject] = @{}
        }
        $cert[$subject]["$($_.Thumbprint)"] = $_
    }

$cert.Keys | ForEach-Object {
    $duplicates = ($cert[$_] | Where-Object {$_.Count -gt 1})
    If ($duplicates) {
        $duplicates.GetEnumerator() |
            Sort-Object [DateTime]"${Value.GetDateTimeString()}" -Descending |
            Select-Object -ExpandProperty Value -Skip 1 |
            ForEach-Object {
                If (Test-Path $_.PSPath) {
                    Remove-Item -Path $_.PSPath -DeleteKey
                }
            }
    }
}

#Exit successful
Exit(0)