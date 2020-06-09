###########VARIABLES#############
$workdir = "C:\P9"
$P9Consoledir = "$workdir\P9Console"
$logdir = "C:\P9\ScriptLogs"
$logfile = "P9Console.log"

$global:allcomputers = $null
$global:ident = $null
$global:TargetMachine = $null
$global:TargetSoftware = $null
$global:TargetUser = $null
$global:P9Online = $null
$global:P9ConnectRunning = $null

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12


###########ENDVARIABLES#############

########LOGGING########
If(Test-Path -Path $P9Consoledir -PathType container){}
else {New-Item -Path $P9Consoledir -ItemType directory -ErrorAction ignore}
If (Test-Path -Path $logdir\$logfile -PathType leaf){}
else {
New-Item -Path $workdir -ItemType directory -ErrorAction ignore
New-Item -Path $workdir -Name "ScriptLogs" -ItemType "directory" -ErrorAction ignore
New-Item -Path $logdir -Name "$logfile" -ItemType "file" -ErrorAction ignore
}
########ENDLOGGING########


##GENERAL FUNCTIONS##
#####################

function LogIt ($note) {
$time = Get-Date -Format "MM/dd/yyyy HH:mm ss"
Add-Content $logdir\$logfile "$time : $note `n"
}
function SendAlert ($note){
Start-Process -FilePath "C:\Windows\System32\msg.exe" -ArgumentList "* /server:localhost $note"
LogIt -note "Note sent to user: $note "
}

#####################



##Get Login Token##
##################
function GetToken(){

    if(Test-Path -Path "$P9Consoledir\Token.txt" -PathType leaf){
        write-host "Stored token found, loading..."
        Start-Sleep 1
        $global:ident = Get-Content "$P9Consoledir\Token.txt"}
        else {
            write-host "No token found"
            $validIdent = $false
            while ($validIdent -eq $false){
                $UN = Read-Host -Prompt "Enter P9 Username"
                cls
                $PW = Read-Host -Prompt "Enter P9 Password"
                cls
                $otp = Read-Host -Prompt "Enter OTP(2FA)"
                cls

                $TokenBody = @{
                'username' = [string]$UN
                'password' = [string]$PW
                'grant_type'= 'password'
                'otp' = [string]$otp
            }

                try {$global:ident = Invoke-RestMethod -Uri "https://dashboard.panorama9.com/oauth/access_token" -Method POST -Body $TokenBody}
                catch [System.Net.WebException],[System.IO.IOException]{ "Username, Password, or OTP didnt work, try again."}

                if ($global:ident){
                    write-host "Token collected: $($ident.access_token)"
                    $global:ident = $ident.access_token 
                    $validIdent = $true
                    $global:ident | Set-Content $P9Consoledir\Token.txt}
                else {continue}

            }
        }
}

##DatasetBuilder##
##################

function BuildSet ($check){
    Clear-Variable -Name allcomputers -scope Global
    $progressPreference = 'silentlyContinue'
            
            if((Test-Path -Path "C:\P9\P9Console\AllComputers.csv" -PathType leaf) -And $check -eq $null){
                write-host "Local Cached copy of 'AllComputers' file found, loading..."
                start-sleep 2
                $global:allcomputers = import-csv -Path "C:\P9\P9Console\AllComputers.csv"
                } else {


                    $moredata = "True"
                    $headers = @{
                        'Authorization' = "OAuth $($global:ident)"
                    }

                    Write-Host "Building Set of all computers"
                    for ($i =1; $moredata -eq "True"; $i++){

                        #Add computers to collection
                        $global:allcomputers = $global:allcomputers + (Invoke-RestMethod -Uri "https://dashboard.panorama9.com/api/devices/computers?per_page=100&page=$i" -Method GET -Headers $headers)
    
                        #check if data is done
                        $moredata = Invoke-WebRequest -Uri "https://dashboard.panorama9.com/api/devices/computers?per_page=200&page=$i" -Method GET -Headers $headers
                        $moredata = ($moredata.headers | ConvertTo-Json | convertfrom-json).'x-hasmore'
                        write-host "Collecting page $i"
                        }
                    $Global:allcomputers | Export-Csv -Path "$P9Consoledir\AllComputers.csv"
                }
}

##Console Specific FUNCTIONS##
##############################

function ReadyToGo($option){
    cls
    if ((P9OnlineTest -Display Feedback) -eq $false)
        {write-host "P9 appears to be offline,check internet connection and rerun"
        pause
        break}
    else {write-Host "Connection to P9 is good, starting console."
        sleep 1}
}

function P9OnlineTest($Display){
#options for $Display: YES, FEEDBACK

    $isOnline = Test-Connection -ComputerName dashboard.panorama9.com -Quiet -Count 1

    if ($isOnline -eq $true){
        $global:P9Online = $true
        if ($display -eq "yes"){write-host "Connected" -ForegroundColor Green | out-string}}
    else {$global:P9Online = $false
        if ($display -eq "yes"){write-host "No Connection" -ForegroundColor Red | out-string}}

    if ($display -eq "feedback"){
        $isOnline}
}

function IsMachineOnline(){
    if ($Global:TargetMachine.is_online -eq $true){
        Write-host "Online" -ForegroundColor Green
        } else {Write-host "Offline" -ForegroundColor Red}
}

function IsP9ConnectOnline(){
    
    foreach ($line in $TargetMachine.remote_control){
        if ($line.provider -eq 'Panorama9 connect'){
            $running = $true
            }
    }
    if ($running -eq $true){write-host "Running" -ForegroundColor Green
        $global:P9ConnectRunning = $true}
    else {Write-host "Not Running" -ForegroundColor Red
        $global:P9ConnectRunning = $false}
}

function GetP9ConnectClient(){
    $header = @{
    'Authorization' = "OAuth $global:ident"
    'Content-Type' = "application/json"
    }

    Invoke-RestMethod -Uri "https://dashboard.panorama9.com/api/devices/$($($TargetMachine).device_id)/remote-control/p9connect/download" -Method GET -Headers $header -OutFile "C:\P9\P9 Connect.exe"
}

function StartP9Connect(){
    $header = @{
    'Authorization' = "OAuth $global:ident"
    'Content-Type' = "application/json"
    }
    $body = @{
    "command" = "start"
    }
    Invoke-RestMethod -Uri "https://dashboard.panorama9.com/api/devices/$($($TargetMachine).device_id)/remote-control/p9connect" -Method POST -Headers $header -body ($body | ConvertTo-json)
}

function SoftwareSearch ($term){
    if (!$term){$term = Read-host -Prompt "Search for what application?(All for all)"}
    if ($term -eq "All"){$global:TargetSoftware
        pause
        break}
    $results = $global:TargetSoftware | where -Property name -like "*$term*"
    if ($results.count -eq "0"){"No results found, try changing search term"
        pause
        break}
    elseif ($results.count -eq "1"){"Single result found"
        pause
        $results}
    else {$results
        pause}
}

function GetSoftware (){
#Downloads all software installed on TargetMachine

    $header = @{
    'Authorization' = "OAuth $global:ident"
    }

    $global:TargetSoftware = Invoke-restmethod -Uri "https://dashboard.panorama9.com/api/devices/$($Global:targetmachine.device_id)/software" -Method GET -Headers $header
    
}

function GetFormattedDate($option){

    if ($option -eq $null){$option = "Warranty"}
        do
    {
        $date= read-host "Please enter $option Date (MONTH DAY YEAR)"

        $date = $date -as [datetime]

        if (!$date) {
            "Not A valid date and time"
        }
    } while ($date -isnot [datetime])

    #this format didnt work, too long P9 didnt like it. I think it accounts for seconds which is not allowed in P9
    #$date = $date | Get-Date -Format "o"

    #This was weird, had to set the hour to '12' because the default '0' would trick P9 into thinking this was actually the day before
    $date = $date | Get-Date -UFormat '+%Y-%m-%dT12:%M:%SZ'
    $date
}


function AddDevice(){
    $header = @{
        'Authorization' = "OAuth $global:ident"
        'Content-Type' = "application/json"
    }

    $body = @{
       "type"= "computer"
       "manufacturer"= (Read-host -prompt "Manufacturer")
       "model"= (Read-host -prompt "Model")
       "serial"= ($serial = Read-host -prompt "Serial")
       "name"= $serial
       "price"= [int](Read-host -prompt "Price[integer]")
       "price_currency"= "USD"
       "warranty_date"= (GetFormattedDate)
       "first_use_date"= (GetFormattedDate -option "First Use")
       "barcode"= (Read-host -prompt "Asset Tag")
       "ip" = "127.0.0.1"
       "notes"= (Read-host -prompt "Notes")
    }

    cls
    $body
    $commit = Read-Host -Prompt "Please check this information for correctness. Create Asset in P9? (Y/N)"

    switch ($commit){
        'Y' {
            write-host "Adding Asset to P9..."
            Invoke-restmethod -Uri "https://dashboard.panorama9.com/api/devices" -Method POST -Headers $header -Body (ConvertTo-Json $body)
            Write-host "Completed"
            pause
            }
        'N' {
            write-host "Cancelling action"
            continue}
    }

}




##Single search function##
##########################

function search-general([string]$type, $target){
    if (!$target){
    $results = $allcomputers | where -Property $type -like *$(Read-Host -Prompt "Enter the parameter you want to search for")*
    } else {$results = $allcomputers | where -Property $type -like *$target*}

    $i = 0
    foreach($machine in $results){
        
        $i++
        ##Check to see if we can get the username the easy way ($machine.user.username) or the annoying way (Splitting string)
        if($($machine.user.username) -eq $null){
            $editeduser = ($machine.user).split("="";")
            $editeduser = $editeduser[3]
            ##Change
            Set-Variable -Name "editeduser$i" -Value $editeduser
        } else {
            $editeduser = $($machine.user.username)
            Set-Variable -Name "editeduser$i" -Value $editeduser
        }

        ##Display results machine by machine
        $obj = [pscustomobject]@{
        "#" = $i
        Name = "$($machine.name)"
        Asset = "$($machine.barcode)"
        "Last User" = "$editeduser"
        "Device ID" = "$($machine.device_id)"
        Notes = "$($machine.notes)"
        }
    
        set-Variable -Name "option$i" -Value $machine.device_id
        $obj

    }

    ##This block allows us to correct for no entry or single entry and allows user to return to menu i result was no good.
    :search switch ($i){
        '0' {write-host "No results found, consider loosening search term"
            pause
            break}
        '1' {write-host "Single result found"
            $j = Read-Host -Prompt "Load data from P9? (Y/N)"
            if(($j -eq "Y") -or ($j -eq "")){
                $userchoice = '1'
                $selection = get-variable option${userchoice}
                subsearch($selection.Value)
            } else {break}
            }
        default {
        do{
            $userchoice = Read-host -prompt "Select an object to act on`nEnter 'M' to return to main menu"
            if ($userchoice -eq "M"){
                break search}
            elseif ($userchoice -eq ""){
                Write-host "Please enter valid entry"}
            }while ($userchoice -eq "")
            $selection = get-variable option${userchoice}
            # Set TargetUser using selection
            $global:TargetUser = editeduser${userchoice}
            subsearch($selection.Value)
            }
    }
}


function subsearch([string]$devID){
    #Used to pull machine information from P9

    $result = $global:allcomputers | where -Property device_id -eq $devID
    write-host "You have selected $($result.name)"
    Write-host "Fetching up to date record..."

    $header = @{
    'Authorization' = "OAuth $global:ident"
    "Content-Type" = "application/vnd.panorama9.com-v1+json"
    }
    $global:TargetMachine = Invoke-restmethod -Uri "https://dashboard.panorama9.com/api/devices/$devID" -Method GET -Headers $header
    
    GetSoftware
    ComputerMenu
}

##Update Data Function##
########################

function UpdateData($type,$value){

    $headersUpdate = @{
        'Authorization' = "OAuth $global:ident"
        "Content-Type" = "application/json"
        }

    
    if ($type -eq "price"){
        $bodyPrice = @{
            'price_currency' = "USD"
            'price' = [int]$value
        }
        Invoke-RestMethod -Uri "https://dashboard.panorama9.com/api/devices/$($Global:TargetMachine.device_id)" -Method Patch -Body ($bodyPrice | ConvertTo-Json) -Headers $headersUpdate
        write-host "Price Update"
        pause
    } else {
        $bodyupdate = @{
            [string]"$type" = [string]"$value"
        }
        Invoke-RestMethod -Uri "https://dashboard.panorama9.com/api/devices/$($Global:TargetMachine.device_id)" -Method Patch -Body ($bodyUpdate | ConvertTo-Json) -Headers $headersUpdate
        Write-host "Other Update"
        pause
    }

    #Update local machine registration to show update
    $Global:TargetMachine.$($type) = $value
}



function Menu
{ 
     param (
           [string]$Title = 'P9 Console'
     )
     $continue = $true
     :main while($continue -ne $false){
     cls
     Write-Host "================ $Title ================ Connection to P9: " -nonewline
     (P9OnlineTest -Display "Yes")
    
     Write-Host "`n"
     Write-Host " 1: Search by Asset tag"
     Write-Host " 2: Search by SerialNumber"
     Write-Host " 3: Search by User"
     Write-Host " 4: Search by Alias (WIP)"
     Write-Host " D: Search by Device ID"
     Write-Host "`n" -nonewline
     Write-Host " A: Manually add device"
     Write-Host "`n"-nonewline
     Write-Host " B: Press 'B' to Force Rebuild of computers."
     Write-Host " Q: Press 'Q' to quit."
     Write-Host "`n"

     $selection = Read-host "Please make a selection"
     
     switch ($selection) {
        '1' {cls
            Write-Host "1: Search by Asset tag"
            search-general barcode}
        '2' {cls
            Write-Host "2: Search by SerialNumber"
            search-general name}
        '3' {cls
            Write-Host "3: Search by User"
            search-general user}
        '4' {cls
            Write-Host "4: Search by Alias"
            search-general alias}
        '5' {cls
            Write-Host "5: Search by IP (WIP)"
            search-general}
        'A' {cls
            Write-Host "A: Add Device"
            AddDevice}
        ##Secret option
        'D' {subsearch (Read-Host -Prompt "Enter Device ID manually")}

        'B'{BuildSet 1}
        'Q' {cls
            $continue = $false
            clear-variable global:target*}
        default {cls
        write-host "Enter something, dummy"
        pause}
        }
        }
}


function ComputerMenu
{ 
     param (
           [string]$Title = 'P9 Console - Target Computer'

     )
     $continue = $true

     :computer while($continue -eq $true){
         cls
         Write-Host "================ $Title ================ Connection to P9: " -nonewline
         P9OnlineTest -Display "yes"
    
         #Write-Host "`n"

        #Write out Machine info first
        $TargetMachine | select -Property name,alias,barcode,manufacturer,model,os,device_id,warranty_date,notes
        if ($TargetMachine.os -like "Microsoft Windows*"){
            Write-Host "Windows version:  $(($targetsoftware | where name -like "*Microsoft Windows 10*").version)"}
        Write-Host "Last User: $global:TargetUser"
        Write-Host "P9Connect Status:  " -NoNewline
        IsP9ConnectOnline
        write-host "Current Machine Status:  " -NoNewline
        IsMachineOnline
        

        Write-Host "`n"
        Write-Host " 1: Add/Edit Machine Alias"
        Write-Host " 2: Add/Edit Barcode"
        Write-Host " 3: Add/Edit Warranty Date"
        Write-Host " 4: View Asset in P9 (Browser)"
        Write-Host " 5: Add/Edit Other"
        Write-Host "`n"-NoNewline

        Write-Host " S: Search software"
        Write-Host "`n" -NoNewline
        Write-Host " R: Refresh view"
        Write-Host "`n" -NoNewline

        #P9 Connect Logic
        if($P9ConnectRunning -eq $true){
        Write-Host " C: Download and connect to client (WIP)"}
        if($P9ConnectRunning -eq $false){
        Write-Host " C: Start P9Connect service (WIP)"}

        Write-Host "`n" -NoNewline
        Write-Host " M: Press 'M' to return to main menu."
        Write-Host " Q: Press 'Q' to quit."
        Write-Host "`n" -NoNewline

        $selection = Read-host "Please make a selection"
     
         switch ($selection) {
            '1' {cls
                UpdateData "alias" (Read-host -Prompt "Enter new Alias")
                write-host "Alias updated"
                Sleep 1}
            '2' {cls
                UpdateData "barcode" (Read-host -Prompt "Enter new Barcode")
                write-host "Barcode updated"
                Sleep 1}
            '3' {cls
                UpdateData "warranty_date" (GetFormattedDate)
                write-host "Warranty updated"
                Sleep 1}
            '4' {cls
                if ($TargetMachine.manually_added -eq $false){
                Start-Process "https://dashboard.panorama9.com/portal#assets/hardware/computers/$($Global:TargetMachine.device_id)"}
                else {Start-Process "https://dashboard.panorama9.com/portal#assets/hardware/computers/custom/$($Global:TargetMachine.device_id)"}
                }
            ##Debug Tool
            '5' {cls
                Updatedata (read-host -prompt "Enter field you want to update") (read-host -prompt "Enter value of this field")
                pause}
            'S' {cls
                SoftwareSearch}
            'R' {cls
                subsearch $targetMachine.device_id}
            'C' {cls
                if ($P9ConnectRunning -eq $true){GetP9ConnectClient; Start-Process -FilePath "C:\P9\P9 Connect.exe" -Wait}
                else {StartP9Connect}
                pause}
            'M' {cls
                $continue = $false
                break}
            'Q' {cls
                clear-variable global:target*
                break main}
            default {cls
            write-host "Enter something, dummy"}
            }

        }

}

function main(){

    ReadyToGo
    GetToken
    BuildSet
    Menu
    }

main
