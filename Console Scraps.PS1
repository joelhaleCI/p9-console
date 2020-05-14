#Gets the access token from server

$otp = Read-Host -Prompt 'Enter OTP'
try {$ident1 = Invoke-RestMethod -Uri "https://dashboard.panorama9.com/oauth/access_token" -Method POST -Body $body}
catch [System.Net.WebException],[System.IO.IOException]{ "OTP didnt work, try again"}





##TESTING UPDATING VALUES - WORKING
$barcodeupdate = Read-host -Prompt "Enter the new Barcode"
Invoke-RestMethod -Uri "https://dashboard.panorama9.com/api/devices/c8cd7b90352feceb25b189394526c530cdb2ef7d" -Method Patch -Body ($bodyUpdate | ConvertTo-Json) -Headers $headersUpdate


        $moredata = "True"
    for ($i =1; $moredata -eq "True"; $i++){

        Set-Variable -Name allcomputers -Scope Global
        #Add computers to collection
        $allcomputers = $allcomputers + (Invoke-RestMethod -Uri "https://dashboard.panorama9.com/api/devices/computers?per_page=200&page=$i" -Method GET -Headers $headers)
    
        #check if data is done
        $moredata = Invoke-WebRequest -Uri "https://dashboard.panorama9.com/api/devices/computers?per_page=200&page=$i" -Method GET -Headers $headers
        $moredata = ($moredata.headers | ConvertTo-Json | convertfrom-json).'x-hasmore'
        write-host "Collecting page $i"
        }


$body = @{
    'username' = 'joel.hale@customink.com'
    'password' = '#0G84pe*WNa%'
    'grant_type'= 'password'
    'otp' = [string]$otp
}

#original search User function
function search-user([string]$user){
    if (!$user){
    $results = $allcomputers | where -Property user -like *$(Read-Host -Prompt "Enter the user you want to search for")* | select name,barcode,device_id,user
    } else {$results = $allcomputers | where -Property user -like *$user* | select name,barcode,device_id,user}

    $results |format-table
    foreach($machine in $results){
    write-host $machine.name
    $launchbrowser = Read-host "Launch P9 asset page?(Y/N)"
    switch ($launchbrowser){
    "Y"{Start-Process "https://dashboard.panorama9.com/portal#assets/hardware/computers/$($machine.device_id)"}
    "N"{continue}
    "Q"{break}
    }
}
}



function MegaSearch(){
    [string]$term = Read-Host -Prompt "Enter search term"
    if ($term.length -eq 5){
        $results = search-assetTEST($term)}
    else {"Nada"}

     cls
     Write-Host "================ $($results.name) ================ Connection to P9: " -nonewline
     P9OnlineTest
    
     Write-Host "`n"
     Write-Host "1: Open P9 Asset page"
     Write-Host "2: Update a Field"
     Write-Host "3: Get more info"
     Write-Host "M: Return to Menu"
     Write-Host "Q: Press 'Q' to quit."

     $selection = Read-host "Please make a selection"
     
     switch ($selection) {
        '1' {cls
            Write-Host "Opening P9 page"
            Start-Process "https://dashboard.panorama9.com/portal#assets/hardware/computers/$($results.device_id)"}
        '2' {cls
            Write-Host "Feature coming"}
        '3' {cls
            $results | select name,barcode,alias,device_id }
        'M' {
            break}
        'Q' {cls
            write-host "Closing"
            Exit-PSSession}
        default {cls
        write-host "Enter something valid"}
        }


}

#Search by Asset
function search-assetTEST([string]$term){
    if (!$term){
    $results = $allcomputers | where -Property barcode -eq (Read-Host -Prompt "Enter Asset tag to search")
    } else {$results = $allcomputers | where -Property barcode -eq $term
}
}



function search-user([string]$user){
    if (!$user){
    $results = $allcomputers | where {$_.user -like "*$(Read-Host -Prompt "Enter the user you want to search for")*"} 
    } else {$results = $allcomputers | where -property user -like *$user*}

    $results |format-table
    foreach($machine in $results){
    write-host $machine.name
    $launchbrowser = Read-host "Launch P9 asset page?(Y/N)"
    switch ($launchbrowser){
    "Y"{Start-Process "https://dashboard.panorama9.com/portal#assets/hardware/computers/$($machine.device_id)"}
    "N"{continue}
    "Q"{break}
    }
}
}


foreach ($line in $results){

    $newresults = $line.user.Split("\"";",4)
    $newresults
}


#create powershell object
foreach ($line in $joels){

    $obj = New-Object -TypeName psobject
    $obj | Add-Member -MemberType NoteProperty -Name name -Value "$($line.name)"
    $obj | Add-Member -MemberType NoteProperty -Name barcode -Value "$($line.barcode)"
    $edited = ($line.user).split("\"";",4)
    $obj | Add-Member -MemberType NoteProperty -Name user -Value "$($edited[2])"
    $obj | Add-Member -MemberType NoteProperty -Name device_id -Value "$($line.device_id)"

    $obj
    }

#new object with hashtable
# for some reason the order of the properties cannot be changed, fucked up
foreach ($line in $joels){
    $edited = ($line.user).split("\"";",4)

    $properties = @{
    barcode = "$($line.barcode)"
    device_id = "$($line.device_id)"
    
    user = "$($edited[2])"
    name = "$($line.name)"
    }
    $o = New-Object psobject -Property $properties; $o
    }


#hashtable method
$i =0
foreach ($line in $joels){
    $i++
    $edited = ($line.user).split("\"";",4)

    $obj = [pscustomobject]@{
    "#" = $i
    test = "Anything"
    name = "$($line.name)"
    barcode = "$($line.barcode)"
    user = "$($edited[2])"
    device_id = "$($line.device_id)"
    }
    #this makes it look fucked up
    #$obj | Format-table
    
    set-Variable -Name "option$i" -Value $line.device_id
    $obj
    }


function SearchIt ([string]$term){
    if ($term.Length -eq 7 -or $term.Length -eq 12){
    write-host "This appears to be a Serial"
    search-host ($term)
    } elseif ($term.Length -eq 5) {
    write-host "This appears to be an Asset tag"
    search-asset ($term)
    } elseif ($term -eq "user"){
    write-host "Searching for a user"
    search-user
    }
}

##Depricated searchs scripts##

#Search by Asset
function search-asset([string]$term){
    if (!$term){
    $results = $allcomputers | where -Property barcode -eq (Read-Host -Prompt "Enter Asset tag to search") | select -Property name,barcode,alias,device_id
    } else {$results = $allcomputers | where -Property barcode -eq $term | select -Property name,barcode,alias,device_id}

    $results | Format-Table
    $launchbrowser = Read-host "Launch P9 asset page?(Y/N)"
    switch ($launchbrowser){
        "Y"{Start-Process "https://dashboard.panorama9.com/portal#assets/hardware/computers/$($results.device_id)"}
        "N"{continue}
        "Q"{break}
    }
}


#Searching by hostname
function search-host([string]$term){
    if (!$term){
    $results = $allcomputers | where -Property name -eq (Read-Host -Prompt "Enter computer name to search for") | select -Property name,barcode,alias,device_id
    } else {$results = $allcomputers | where -Property name -eq $term | select -Property name,barcode,alias,device_id}

    $results | Format-Table
    $launchbrowser = Read-host "Launch P9 asset page?(Y/N)"
    switch ($launchbrowser){
        "Y"{Start-Process "https://dashboard.panorama9.com/portal#assets/hardware/computers/$($results.device_id)"}
        "N"{continue}
        "Q"{break}
    }
}


#Search by user
function search-user([string]$user){
    if (!$user){
    $results = $allcomputers | where -Property user -like *$(Read-Host -Prompt "Enter the user you want to search for")*
    } else {$results = $allcomputers | where -Property user -like *$user*}

    $i = 0
    foreach($machine in $results){
        $i++
        $edited = ($machine.user).split("\"";",4)

        $obj = [pscustomobject]@{
        "#" = $i
        name = "$($machine.name)"
        barcode = "$($machine.barcode)"
        user = "$($edited[2])"
        device_id = "$($machine.device_id)"
        }
        #this makes it look fucked up
        #$obj | Format-table
    
        set-Variable -Name "option$i" -Value $machine.device_id #-scope Global
        $obj
    }
    $userchoice = Read-host -prompt "Select an object to act on"
    write-host "User chooses $userchoice"
    $selection = get-variable option${userchoice}
    $selection
    subsearch($selection.Value)
}

###END SEARCH



        #create custom object with properties we care about, mainly about formatting

        $obj = [pscustomobject]@{
        Hostname = $Global:TargetMachine.name
        Alias = $Global:TargetMachine.alias
        Model ="$($Global:TargetMachine.manufacturer) $($Global:TargetMachine.model)"
        Asset = $Global:TargetMachine.barcode
        OS = $Global:TargetMachine.os
        device_id = $Global:TargetMachine.device_id
        }


function BuildSetv1 ($check){

            
            if(Test-Path -Path "C:\P9\P9Console\AllComputers.csv" -PathType leaf -and $check -eq $null){
                write-host "Local Cached copy of 'AllComputers' file found, loading..."
                start-sleep 2
                $global:allcomputers = import-csv -Path "C:\P9\P9Console\AllComputers.csv"
                } else {

                $moredata = "True"
                $headers = @{
                    'Authorization' = "OAuth $($global:ident)"
                }
            
                for ($i =1; $moredata -eq "True"; $i++){

                    #Add computers to collection
                    $global:allcomputers = $global:allcomputers + (Invoke-RestMethod -Uri "https://dashboard.panorama9.com/api/devices/computers?per_page=200&page=$i" -Method GET -Headers $headers)
    
                    #check if data is done
                    $moredata = Invoke-WebRequest -Uri "https://dashboard.panorama9.com/api/devices/computers?per_page=200&page=$i" -Method GET -Headers $headers
                    $moredata = ($moredata.headers | ConvertTo-Json | convertfrom-json).'x-hasmore'
                    write-host "Collecting page $i"
                    }
                $allcomputers | Export-Csv -Path "$P9Consoledir\AllComputers.csv"
                }
}


##WIP
function AddDevice(){


    $body = @{
       "type"= "computer"
        "manufacturer"= (Read-host -prompt "Manufacturer")
       "model"= (Read-host -prompt "Model")
       "serial"= ($serial = Read-host -prompt "Serial")
       "name"= $serial
       "price"= [int](Read-host -prompt "Price[integer]")
       "price_currency"= "USD"
       "warranty_date"= (GetWarrDate)
       "first_use_date"= (GetWarrDate -option Shipping)
       "barcode"= (Read-host -prompt "Asset Tag")
       "notes"= (Read-host -prompt "Notes")
    }
}
##WIP


function checkitoutman(){
    $global:allcomputers.count
    Clear-Variable allcomputers -scope Global
    $global:allcomputers.count
    }