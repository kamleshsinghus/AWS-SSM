﻿param (
    $Name = (Get-PSUtilDefaultIfNull -value $Name -defaultValue 'ssmlinux'), 
    $InstanceIds = $InstanceIds,
    $Region = (Get-PSUtilDefaultIfNull -value (Get-DefaultAWSRegion) -defaultValue 'us-east-1'),
    [string] $SetupAction = ''  # SetupOnly or CleanupOnly
    )

Set-DefaultAWSRegion $Region

if ($InstanceIds.Count -eq 0) {
    Write-Verbose "InstanceIds is empty, retreiving instance with Name=$Name"
    $InstanceIds = (Get-WinEC2Instance $Name -DesiredState 'running').InstanceId
}
$DocumentName = "ParameterStore-$Name"

Write-Verbose "Linux RC4 Param: InstanceIds=$InstanceIds, DocumentName=$DocumentName"

$doc = @'
{
    "schemaVersion": "2.0",
    "description": "Sample Document shows Parameters based on environment",
    "parameters":{
        "environment":{
            "type":"String",
            "description":"(Optional) Define the environment name.",
            "displayType":"textarea",
            "default": "test",
            "allowedValues":[
                            "test",
                            "staging",
                            "production"
                        ]
        },
        "hello":{
            "type":"String",
            "description":"(Optional) Fetched from parameter store based on environment",
            "displayType":"textarea",
            "default": "{{ssm:{{environment}}-$Name-hello}}"
        }
    },
    "mainSteps": [
        {
            "action": "aws:runShellScript",
            "name": "run",
            "inputs": {
                "runCommand": [
                    "echo Doc1.v1 - {{ hello }}"
                 ]
            }
        }
    ]
}
'@

$parameters = @("test-$Name-hello", "production-$Name-hello")

function Cleanup () {
    SSMDeleteDocument $DocumentName
    foreach ($parameter in $parameters) {
        if (Get-SSMParameterList -Filter @{Key='Name';Values=$parameter}) {
            Remove-SSMParameter -Name $parameter -Force
        }
    }
}
Cleanup
if ($SetupAction -eq 'CleanupOnly') {
    return
} 

SSMCreateDocument $DocumentName $doc
foreach ($parameter in $parameters) {
    Write-Verbose "Create SSM Parameter Name=$parameter"
    Write-SSMParameter -Name $parameter -Value 'world' -Type String
}

$startTime = Get-Date
$command = SSMRunCommand -InstanceIds $InstanceIds -SleepTimeInMilliSeconds 1000 `
    -DocumentName $DocumentName -Parameters @{environment='test'}

Test-SSMOuput $command -ExpectedOutput 'world' -ExpectedMinLength 10 

Write-Verbose "Time = $((Get-Date) - $startTime)"

if ($SetupAction -eq 'SetupOnly') {
    return
}

Cleanup