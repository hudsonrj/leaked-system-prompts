// =============================================================================
// bastion-jump.bicep — SOMENTE AMBIENTE HAT
// Bastion + VM Linux (login Entra ID) para operar o data plane privado
// (psql, criação de índices no AI Search, testes de DNS). Na Vale o acesso é
// pela rede corporativa/VPN + Managed DevOps Pool.
// =============================================================================
param location string
param namePrefix string
param tags object
param bastionSubnetId string
param jumpSubnetId string
param adminUsername string = 'hatadmin'
@description('Chave pública SSH (break-glass). Login normal via Entra ID.')
param sshPublicKey string
param vmSize string = 'Standard_B2s'

resource pip 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-bas-${namePrefix}'
  location: location
  tags: tags
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

resource bas 'Microsoft.Network/bastionHosts@2024-05-01' = {
  name: 'bas-${namePrefix}'
  location: location
  tags: tags
  sku: { name: 'Standard' }
  properties: {
    enableTunneling: true   // permite `az network bastion ssh/tunnel` a partir do notebook
    ipConfigurations: [
      {
        name: 'ipcfg'
        properties: {
          subnet: { id: bastionSubnetId }
          publicIPAddress: { id: pip.id }
        }
      }
    ]
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: 'nic-vm-jump-${namePrefix}'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      { name: 'ipcfg', properties: { subnet: { id: jumpSubnetId }, privateIPAllocationMethod: 'Dynamic' } }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: 'vm-jump-${namePrefix}'
  location: location
  tags: union(tags, { 'auto-shutdown': '20:00' })
  identity: { type: 'SystemAssigned' }
  properties: {
    hardwareProfile: { vmSize: vmSize }
    osProfile: {
      computerName: 'jump'
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: { publicKeys: [ { path: '/home/${adminUsername}/.ssh/authorized_keys', keyData: sshPublicKey } ] }
      }
    }
    storageProfile: {
      imageReference: { publisher: 'Canonical', offer: 'ubuntu-24_04-lts', sku: 'server', version: 'latest' }
      osDisk: { createOption: 'FromImage', managedDisk: { storageAccountType: 'StandardSSD_LRS' } }
    }
    networkProfile: { networkInterfaces: [ { id: nic.id } ] }
    securityProfile: { securityType: 'TrustedLaunch', uefiSettings: { secureBootEnabled: true, vTpmEnabled: true } }
  }
}

resource aadLogin 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: vm
  name: 'AADSSHLoginForLinux'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADSSHLoginForLinux'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
  }
}

resource shutdown 'Microsoft.DevTestLab/schedules@2018-09-15' = {
  name: 'shutdown-computevm-${vm.name}'
  location: location
  properties: {
    status: 'Enabled'
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: { time: '2000' }
    timeZoneId: 'E. South America Standard Time'
    targetResourceId: vm.id
  }
}

output vmId string = vm.id
