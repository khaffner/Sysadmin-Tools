function Get-StorageSpaceStatus {
    $PhysicalDisks = Get-PhysicalDisk
    $Reliability = $PhysicalDisks | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue
    $PhysicalDisks | Sort-Object FriendlyName | Select-Object FriendlyName, DeviceID, *Status, MediaType, Usage, `
    @{N = "PercentAllocated"; E = { [Math]::Round(($_.allocatedSize / $_.Size) * 100, 2) } }, `
    @{N = "ReadErrorsUncorrected"; E = { ($Reliability | Where-Object DeviceID -EQ $_.DeviceID).ReadErrorsUncorrected } }
}