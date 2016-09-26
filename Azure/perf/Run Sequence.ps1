﻿param ($Name)

echo $Name
$host.ui.RawUI.WindowTitle = $Name

if (! (Test-PSTestExecuting)) {
    . "$PSScriptRoot\Common Setup.ps1"
}

Write-Verbose 'Executing Run'


$InputParameters = @{Name=$Name}
$tests = @(
    "$PSScriptRoot\Create Instance.ps1"
    "$PSScriptRoot\Terminate Instance.ps1"
)
Invoke-PsTest -Test $tests -InputParameters $InputParameters  -Count 10

gstat

Convert-PsTestToTableFormat    

