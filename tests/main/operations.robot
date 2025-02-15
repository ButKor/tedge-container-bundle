*** Settings ***
Resource        ../resources/common.resource
Library         DateTime
Library         Cumulocity
Library         DeviceLibrary

Suite Setup     Set Main Device


*** Test Cases ***
Restart device
    Skip
    ${date_from}=    Get Test Start Time
    Sleep    1s
    ${operation}=    Cumulocity.Restart Device
    Operation Should Be SUCCESSFUL    ${operation}    timeout=120

Get Logfile Request
    [Template]    Get Logfile Request
    software-management

Get Configuration File
    [Template]    Get Configuration File
    tedge.toml
    system.toml

Execute Shell Command
    ${operation}=    Cumulocity.Execute Shell Command    ls -l /etc/tedge
    Cumulocity.Operation Should Be SUCCESSFUL    ${operation}


*** Keywords ***
Get Configuration File
    [Arguments]    ${typename}
    ${operation}=    Cumulocity.Get Configuration    ${typename}
    Cumulocity.Operation Should Be SUCCESSFUL    ${operation}

Get Logfile Request
    [Arguments]    ${name}
    ...    ${search_text}=
    ...    ${max_lines}=1000
    ${start_timestamp}=    DateTime.Get Current Date    UTC    -24 hours    result_format=%Y-%m-%dT%H:%M:%S+0000
    ${end_timestamp}=    Get Current Date    UTC    +60 seconds    result_format=%Y-%m-%dT%H:%M:%S+0000
    ${operation}=    Cumulocity.Create Operation
    ...    description=Get Log File: ${name}
    ...    fragments={"c8y_LogfileRequest": {"dateFrom":"${start_timestamp}","dateTo":"${end_timestamp}","logFile":"${name}","maximumLines":${max_lines},"searchText":"${search_text}"}}
    ${operation}=    Operation Should Be SUCCESSFUL    ${operation}
    Should Not Be Empty    ${operation["c8y_LogfileRequest"]["file"]}
