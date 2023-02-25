function Get-IntuneWin32AppsFromLog {
    <#
        .SYNOPSIS
            Parses the IME logs of an Intune managed computer for Win32App information
    
        .DESCRIPTION
            Gets the two last logs (because they roll), finds the line that contains "all" the apps, parses and partially translates the information for human readability. By default trims away redundant and empty information.
    
        .EXAMPLE
            Get-IntuneWin32AppsFromLog

        .EXAMPLE
            Get-IntuneWin32AppsFromLog -Verbose

        .EXAMPLE
            Get-IntuneWin32AppsFromLog -LogFolder "C:\users\kevin\Desktop\Logs" -Full
    #>
    [CmdletBinding()]
    param (
        [Parameter(HelpMessage = "Folder where the Intune Management Extension logs are. Can be overridden in case you got a folder with the logs of another machine, for example.")]
        [string]$LogFolder = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs',

        [Parameter(HelpMessage = "For getting ALL the properties")]
        [switch]$Full
    )

    Write-Verbose "Getting the information from the logs"
    $data = Get-ChildItem -Path $LogFolder -Filter IntuneManagementExtension*.log | # Get all log files, including the previous ones
    Sort-Object LastWriteTime | Select-Object -Last 2 | # Get only the last 2, should be enough
    Get-Content | # Read the logs
    Where-Object { $_ -Like '*Get policies = *' } | # Only get these lines
    Select-Object -Last 1 | # Get the last one
    Select-String -Pattern '\[\{.*\}\]' | # Regex out only the json part
    Select-Object -ExpandProperty Matches | 
    Select-Object -ExpandProperty Value | 
    ConvertFrom-Json # Convert from json
    
    if ($data.SyncRoot) {
        $data = $data.SyncRoot # Some times during testing, the data was behind a SyncRoot.
    }

    # Resolve some enums into helpful strings
    Write-Verbose "Resolving Intent, TargetType and InstallContext enums"
    $data = $data | Select-Object -Property *, `
    @{Name = 'IntentString'; Expression = { switch ($_.Intent) {
                1 { 'Available' }
                3 { 'Required' }
                4 { 'Uninstall' }
            }
        }
    },
    @{Name = 'TargetTypeString'; Expression = { switch ($_.TargetType) {
                1 { 'User' }
                2 { 'Device' }
                3 { 'Both' }
            }
        }
    },
    @{Name = 'InstallContextString'; Expression = { switch ($_.InstallContext) {
                1 { 'User' }
                2 { 'System' }
            }
        }
    }

    $data = foreach ($d in $data) {
        # Nested json conversion
        Write-Verbose "Converting RequirementRules from json"
        $d.RequirementRules = $d.RequirementRules | ConvertFrom-Json

        Write-Verbose "Converting InstallEx from json"
        $d.InstallEx = $d.InstallEx | ConvertFrom-Json
        
        Write-Verbose "Converting ReturnCodes from json"
        $d.ReturnCodes = $d.ReturnCodes | ConvertFrom-Json
        
        Write-Verbose "Converting DetectionRule from json"
        $d.DetectionRule = $d.DetectionRule | ConvertFrom-Json

        if ($d.DetectionRule.DetectionType -eq 3) {
            # Decode script
            Write-Verbose "DetectionType is script, converting it from base64 and adding it as property `"Detection`""
            $DetectionScriptBodyBase64 = ($d.DetectionRule.DetectionText | ConvertFrom-Json).ScriptBody
            $DetectionScriptBody = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($DetectionScriptBodyBase64))
            $d | Add-Member -NotePropertyName 'Detection' -NotePropertyValue $DetectionScriptBody 
        }
        else {
            # Convert another nested json
            Write-Verbose "Converting Detection information from json"
            $d | Add-Member -NotePropertyName 'Detection' -NotePropertyValue ($d.DetectionRule.DetectionText | ConvertFrom-Json -Depth 3)
        }

        Write-Output $d
    }

    if (!$Full) {
        Write-Verbose "Switch parameter `"Full`" was not true, trimming away properties that are empty on all object, and properties that have been resolved into human friendlier formats."
        $Props = ($data | Get-Member -MemberType NoteProperty).Name
        $Exclude = foreach ($p in $Props) {
            if ($null -eq ($data.$p | Sort-Object -Unique)) {
                # All the values of the property is $null, add to exclude
                $p
            }
        }

        $Exclude += 'Intent', 'TargetType', 'InstallContext', 'DetectionRule' # Also exclude the properties that got replaced/improved

        $data = $data | Select-Object -Property * -ExcludeProperty $Exclude
    }

    return $data
}
