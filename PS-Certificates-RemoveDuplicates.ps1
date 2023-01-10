#Suppress notifications
$InformationPreference = "SilentlyContinue"
$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "SilentlyContinue"

#Find and remove duplicate certificates (if exist, oldest first) from personal computer certificates
$cert = @{}
Get-ChildItem -Recurse Cert:\LocalMachine\My |
    Where-Object {$_.Issuer -like "*Foley*"} |
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
		#Set exit code to success as duplicates were found and removed. This only needs to run once via InTune unless PKCS certificate configuration profiles change resulting in more duplicates.
		$ExitCode = 0
        $duplicates.GetEnumerator() |
            Sort-Object [DateTime]"${Value.GetDateTimeString()}" -Descending |
            Select-Object -ExpandProperty Value -Skip 1 |
            ForEach-Object {
                If (Test-Path $_.PSPath) {
                    Remove-Item -Path $_.PSPath -DeleteKey
                }
            }
    }
	Else {
		#Set exit code to failure status as no duplicates were found and removed. This will ensure the script will run additional times via InTune to account for PKCS certificate configuration profiles that may not have applied yet.
		$ExitCode = 1
	}
}

#Exit 
Exit($ExitCode)