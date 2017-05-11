#######################################################################################################################
# This file will be removed when PowerCLI is uninstalled. To make your own scripts run when PowerCLI starts, create a
# file named "Initialize-PowerCLIEnvironment_Custom.ps1" in the same directory as this file, and place your scripts in
# it. The "Initialize-PowerCLIEnvironment_Custom.ps1" is not automatically deleted when PowerCLI is uninstalled.
#######################################################################################################################
param(
    [string]$vc_fqdn,
    [string]$vm_name = "None",
    [string]$power = "False",
    [bool]$create = $false,
    [string]$datastore = "None",
    [string]$template = "None",
    [string]$address = "None",
    [string]$move = $false,
    [string]$remove = $false,
    [string]$hostname = $false,
    [string]$dn = $false,
    [string]$change_ip = $false,
    [string]$change_hostname = $false
)

# List of modules to be loaded
$moduleList = @(
    "VMware.VimAutomation.Core",
    "VMware.VimAutomation.Vds",
    "VMware.VimAutomation.Cloud",
    "VMware.VimAutomation.PCloud",
    "VMware.VimAutomation.Cis.Core",
    "VMware.VimAutomation.Storage",
    "VMware.VimAutomation.HorizonView",
    "VMware.VimAutomation.HA",
    "VMware.VimAutomation.vROps",
    "VMware.VumAutomation",
    "VMware.DeployAutomation",
    "VMware.ImageBuilder",
    "VMware.VimAutomation.License"
    )

$productName = "PowerCLI"
$productShortName = "PowerCLI"

$loadingActivity = "Loading $productName"
$script:completedActivities = 0
$script:percentComplete = 0
$script:currentActivity = ""
$script:totalActivities = `
   $moduleList.Count + 1

function ReportStartOfActivity($activity) {
   $script:currentActivity = $activity
   Write-Progress -Activity $loadingActivity -CurrentOperation $script:currentActivity -PercentComplete $script:percentComplete
}
function ReportFinishedActivity() {
   $script:completedActivities++
   $script:percentComplete = (100.0 / $totalActivities) * $script:completedActivities
   $script:percentComplete = [Math]::Min(99, $percentComplete)
   
   Write-Progress -Activity $loadingActivity -CurrentOperation $script:currentActivity -PercentComplete $script:percentComplete
}

# Load modules
function LoadModules(){
   ReportStartOfActivity "Searching for $productShortName module components..."
   
   $loaded = Get-Module -Name $moduleList -ErrorAction Ignore | % {$_.Name}
   $registered = Get-Module -Name $moduleList -ListAvailable -ErrorAction Ignore | % {$_.Name}
   $notLoaded = $registered | ? {$loaded -notcontains $_}
   
   ReportFinishedActivity
   
   foreach ($module in $registered) {
      if ($loaded -notcontains $module) {
		 ReportStartOfActivity "Loading module $module"
         
		 Import-Module $module
		 
		 ReportFinishedActivity
      }
   }
}
###########################################
#  These are our custom functions we made #
###########################################

function PerformPower($loc_power){
    if ($loc_power -ne "False"){
        if ($loc_power -eq "on"){
            Write-Output "Turning power on"
            start-vm -VM $vm_name -Confirm:$false
            Write-Output "POWER ON"
        }
        elseif ($loc_power -eq "off"){
            Write-Output "Turning power off"
            stop-vm -VM $vm_name -Confirm:$false
            Write-Output "POWER OFF"
        }
    }

}

function ChangeUbuntuIP($new_ip){
    $ip = GetIpAddress($vm_name)
    $command = "mkdir /tmp/powercli; cat /etc/network/interfaces | sed `"s/address $ip/address $new_ip/`" > /tmp/powercli/interfaces; sudo mv /tmp/powercli/interfaces /etc/network/interfaces; rm -r /tmp/powercli; sudo systemctl networking; sudo ifup ens160"
    Invoke-VMScript -VM $vm_name -ScriptText $command -GuestUser administrator -GuestPassword Cyberark1
    Write-Output "Changed Ubuntu ip from $ip to $new_ip"
}

function GetIfconfig(){
    # Logs onto server and runs the ipconfig -a command
    $res = Invoke-VMScript -VM $vm_name -ScriptText "ifconfig -a"
    return $res
}

function GetIpAddress($tmp_vm){
    $res = Get-VMGuest -VM $tmp_vm | Select IPAddress
    $ip = $res.IPAddress[0]
    return $ip
}

function ChangeHostNameAndFQDN($temp_ip, $temp_hostname, $temp_dn){
    $command = "sudo echo '$temp_hostname' | sudo tee /etc/hostname"
    Invoke-VMScript -VM $vm_name -ScriptText $command -GuestUser administrator -GuestPassword Cyberark1
    Write-Output "Changed /etc/hostname to $temp_hostname"


    $command = "sudo sed -i '2s/.*/$temp_ip    $hostname.$temp_dn    $temp_hostname/' /etc/hosts"
    Invoke-VMScript -VM $vm_name -ScriptText $command -GuestUser administrator -GuestPassword Cyberark1
    Write-Output "Changed /etc/hosts to $temp_hostname"
}

# This is the resource pool vms are being added too on the vc
$RESOURCE_POOL = "clusterbuster"


########################################
#            Installation              #
########################################
# Install powercli from https://www.vmware.com/support/developer/PowerCLI/
# and that is it. It is now ready to run

########################################
#            Usage                     #
########################################
# POWER
#   To power on a vm
#     .\Powercli_wrapper.ps1 -vc_fqdn vc.teamc.witcsn.net -vm_name vm2 -power on
#   to power off a vm
#     .\Powercli_wrapper.ps1 -vc_fqdn vc.teamc.witcsn.net -vm_name vm2 -power off
# 
# CREATE
#   To add a vm
#     .\Powercli_wrapper.ps1 -vc_fqdn vc.teamc.witcsn.net -create $true -vm_name new_vm -template temp_vm 
#
# REMOVE
#   To remove a vm
#     .\Powercli_wrapper.ps1 -vc_fqdn vc.teamc.witcsn.net -vm_name vm1 -remove yep
#
# MOVE
#   To move a vm
#     .\Powercli_wrapper.ps1 -vc_fqdn vc.teamc.witcsn.net -vm_name vm1 -move h1.teamc.witcsn.net
#
# CHANGE_IP
#    to change an ip simpley and restart
#      .\Powercli_wrapper.ps1 -vc_fqdn vc.teamc.witcsn.net -vm_name vm1 -change_ip 192.1.1.1
# 
# CHANGE_HOSTNAME
#    To change hostname and restart
#      .\Powercli_wrapper.ps1 -vc_fqdn vc.teamc.witcsn.net -vm_name vm1 -change_hostname something -address 192.1.1.1 -dn teamc.witcsn.net


LoadModules

Write-Output "Connecting to h1 server...."
Write-Output "FQDN given: $vc_fqdn"
# good ole hard coded credentials
connect-viserver $vc_fqdn -user username -Password password
Write-Output "Connected to h1 server"

if ($create -eq $true){
    # Create a new VM
    if ($template -eq "None"){
        Write-Output "ERROR: Specify a Template to deploy from"
    
    }elseif($vm_name -eq "None"){
        Write-Output "ERROR: Specify a VM name"
    }elseif ($datastore -eq $false){
        Write-Output "ERROR: Specify a Data store"
    }
    else{
        # create the vm using a template and placing it in the resource pool
        Write-Output "Creating $vm_name using template $template in $RESOURCE_POOL"
        New-VM -Name $vm_name -Template $template -ResourcePool $RESOURCE_POOL -Datastore $datastore
        if ($power -eq "on"){
                PerformPower $power
                Write-Output "Waiting fo
                r target device to boot up...."
                Start-Sleep -Seconds 120
                ChangeUbuntuIP $address
                ChangeHostNameAndFQDN $address $hostname $dn
                PerformPower off
                PerformPower on
        }
        $power = "False"

    }
}elseif($move -ne $false){
    # Move a vm
    $res = Get-VM -Name $vm_name | Select-Object VMHost
    $host_vm_is_on = $res.VMHost.Name
    Write-Output "Moving $vm_name from $host_vm_is_on --> $move"
    if ($host_vm_is_on -eq $move){
        Write-Output "ERROR: You are trying to move a vm to the same host"
        Write-Output "This is silly....."
    }else{
        Get-VM -Name $vm_name | Move-VM -Destination $move
    }

}elseif($remove -ne $false){
    # Remoce a VM
    $res = Get-VM -Name $vm_name | Select-Object PowerState
    $state = $res.PowerState
    if ($state -eq "PoweredOn"){
        Write-Output "$vm_name is currently Powered On, shutting down now."
        PerformPower off
    }
    Remove-VM -VM $vm_name
    Write-Output "Vm $vm_name has been removed"
}elseif($change_ip -ne $false){
    ChangeUbuntuIP $change_ip
    PerformPower off
    PerformPower on
}elseif($change_hostname -ne $false){
    ChangeHostNameAndFQDN $address $change_hostname $dn
    PerformPower off
    PerformPower on
}

if ($power -ne "False"){
    # Power a vm
    PerformPower $power
}


Write-Output "Disconnecting from h1...."
Disconnect-VIServer -confirm:$false
Write-Output "Disconnected from h1"


