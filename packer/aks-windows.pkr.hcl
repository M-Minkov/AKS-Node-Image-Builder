packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2.0"
    }
  }
}

# Variables
variable "subscription_id" {
  type = string
}

variable "client_id" {
  type    = string
  default = ""
}

variable "client_secret" {
  type      = string
  sensitive = true
  default   = ""
}

variable "tenant_id" {
  type    = string
  default = ""
}

variable "use_azure_cli_auth" {
  type    = bool
  default = false
}

variable "resource_group" {
  type = string
}

variable "location" {
  type    = string
  default = "newzealandnorth"
}

variable "vm_size" {
  type    = string
  default = "Standard_D4s_v3"
}

variable "k8s_version" {
  type    = string
  default = "1.29"
}

variable "containerd_version" {
  type    = string
  default = "1.7.11"
}

variable "image_prefix" {
  type    = string
  default = "aks-node"
}

# Unused but declared so the same var file works for both templates
variable "enable_gpu" {
  type    = bool
  default = false
}

variable "nvidia_driver_version" {
  type    = string
  default = "535"
}

locals {
  timestamp  = formatdate("YYYYMMDD-hhmm", timestamp())
  image_name = "${var.image_prefix}-windows-k8s${var.k8s_version}-${local.timestamp}"
}

source "azure-arm" "windows" {
  subscription_id    = var.subscription_id
  client_id          = var.use_azure_cli_auth ? null : var.client_id
  client_secret      = var.use_azure_cli_auth ? null : var.client_secret
  tenant_id          = var.use_azure_cli_auth ? null : var.tenant_id
  use_azure_cli_auth = var.use_azure_cli_auth

  os_type         = "Windows"
  image_publisher = "MicrosoftWindowsServer"
  image_offer     = "WindowsServer"
  image_sku       = "2022-datacenter-azure-edition"
  
  location = var.location
  vm_size  = var.vm_size
  
  communicator   = "winrm"
  winrm_use_ssl  = true
  winrm_insecure = true
  winrm_timeout  = "10m"
  winrm_username = "packer"
  
  managed_image_name                = local.image_name
  managed_image_resource_group_name = var.resource_group
  
  azure_tags = {
    os              = "windows-2022"
    k8s_version     = var.k8s_version
    containerd      = var.containerd_version
    build_timestamp = local.timestamp
  }
}

build {
  sources = ["source.azure-arm.windows"]

  provisioner "powershell" {
    script = "../scripts/windows/base-setup.ps1"
  }

  provisioner "powershell" {
    script = "../scripts/windows/install-containerd.ps1"
    environment_vars = [
      "CONTAINERD_VERSION=${var.containerd_version}"
    ]
  }

  provisioner "powershell" {
    script = "../scripts/windows/install-kubernetes.ps1"
    environment_vars = [
      "K8S_VERSION=${var.k8s_version}"
    ]
  }

  provisioner "powershell" {
    script = "../scripts/windows/security-hardening.ps1"
  }

  provisioner "powershell" {
    script = "../scripts/windows/cleanup.ps1"
  }

  provisioner "powershell" {
    inline = [
      "& $env:SystemRoot\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /quiet /quit /mode:vm",
      "while($true) { $imageState = Get-ItemProperty HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup\\State | Select ImageState; if($imageState.ImageState -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') { Write-Output $imageState.ImageState; Start-Sleep -s 10  } else { break } }"
    ]
  }
}
