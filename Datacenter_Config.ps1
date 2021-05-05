$script:configurationData = @{
    AllNodes = @(
        @{
            NodeName = '192.168.10.163'
        },
        @{
            NodeName = '192.168.10.164'
        },
        @{
            NodeName = '192.168.10.165'
        }
    )
}

Configuration Datacenter_Config {
    Import-DscResource -ModuleName 'VMware.vSphereDSC'

    $ESXiUser = "root"
    $ESXiPassword = "VMware1!"
    $ESXiPassword = $ESXiPassword | ConvertTo-SecureString -AsPlainText -Force
    $VMHostCredential = New-Object System.Management.Automation.PSCredential($ESXiUser, $ESXiPassword)

    vSphereNode 'lab-vc-06.go-lab.jp' {
        Datacenter 'MyDatacenter' {
            Name = 'lab-dc-61'
            Location = ''
            Ensure = 'Present'
        }

        Cluster MyCluster {
            Name = 'dsc-cluster-61'
            Location = ''
            DatacenterName = 'lab-dc-61'
            DatacenterLocation = ''
            Ensure = 'Present'
        }
        
        $i = 0
        $AllNodes | foreach {
            $VMHost = $_
            $i++
            $VMHostResourceName = "VMHost_" + $VMHost["NodeName"]
            vCenterVMHost $VMHostResourceName {
                Name = $VMHost["NodeName"]
                DatacenterName = 'lab-dc-61'
                DatacenterLocation = ''
                Location = 'dsc-cluster-61'
                Ensure = 'Present'
                VMHostCredential = $VMHostCredential
                Port = 443
                Force = $true
                DependsOn = '[Cluster]MyCluster'
            }

            $vSSResourceName = "vSS_" + $VMHost["NodeName"]
            VMHostVss $vSSResourceName {
                Name = $VMHost["NodeName"]
                Ensure = 'Present'
                VssName = 'vSwitch1'
                Mtu = 1500
                DependsOn = "[vCenterVMHost]$VMHostResourceName"
            }

            $vSSBridgeResourceName = "vSSBridge_" + $VMHost["NodeName"]
            VMHostVssBridge $vSSBridgeResourceName {
                Name = $VMHost["NodeName"]
                VssName = 'vSwitch1'
                Ensure = 'Present'
                NicDevice = @('vmnic2','vmnic3')
                DependsOn = "[VMHostVss]$vSSResourceName"
            }

            $vSSTeamResourceName = "vSSTeam_" + $VMHost["NodeName"]
            VMHostVssTeaming $vSSTeamResourceName {
                Name = $VMHost["NodeName"]
                Ensure = 'Present'
                VssName = 'vSwitch1'
                CheckBeacon = $false
                ActiveNic = @('vmnic2')
                StandbyNic = @('vmnic3')
                NotifySwitches = $true
                Policy = 'Failover_Explicit'
                RollingOrder = $false
                DependsOn = "[VMHostVss]$vSSResourceName"
            }

            $vSSPGResourceName = "vSSPGs_" + $VMHost["NodeName"]
            VMHostVssPortGroup $vSSPGResourceName {
                VMHostName = $VMHost["NodeName"]
                Name = 'PG-VLAN-0010-vSwitch1'
                VssName = 'vSwitch1'
                Ensure = 'Present'
                VLanId = 10
                DependsOn = "[VMHostVss]$vSSResourceName"
            }
        }
        
    }
}