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

variable "enable_gpu" {
  type    = bool
  default = false
}

variable "nvidia_driver_version" {
  type    = string
  default = "535"
}

variable "image_prefix" {
  type    = string
  default = "aks-node"
}

locals {
  timestamp    = formatdate("YYYYMMDD-hhmm", timestamp())
  image_name   = "${var.image_prefix}-ubuntu-k8s${var.k8s_version}-${local.timestamp}${var.enable_gpu ? "-gpu" : ""}"
}

source "azure-arm" "ubuntu" {
  subscription_id    = var.subscription_id
  client_id          = var.use_azure_cli_auth ? null : var.client_id
  client_secret      = var.use_azure_cli_auth ? null : var.client_secret
  tenant_id          = var.use_azure_cli_auth ? null : var.tenant_id
  use_azure_cli_auth = var.use_azure_cli_auth

  os_type         = "Linux"
  image_publisher = "canonical"
  image_offer     = "0001-com-ubuntu-server-jammy"
  image_sku       = "22_04-lts-gen2"
  
  location = var.location
  vm_size  = var.vm_size
  
  managed_image_name                = local.image_name
  managed_image_resource_group_name = var.resource_group
  
  azure_tags = {
    os              = "ubuntu-22.04"
    k8s_version     = var.k8s_version
    containerd      = var.containerd_version
    gpu_enabled     = var.enable_gpu
    build_timestamp = local.timestamp
  }
}

build {
  sources = ["source.azure-arm.ubuntu"]

  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init...'",
      "cloud-init status --wait"
    ]
  }

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    script = "../scripts/linux/base-setup.sh"
  }

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    script = "../scripts/linux/install-containerd.sh"
    environment_vars = [
      "CONTAINERD_VERSION=${var.containerd_version}"
    ]
  }

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    script = "../scripts/linux/install-kubernetes.sh"
    environment_vars = [
      "K8S_VERSION=${var.k8s_version}"
    ]
  }

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    script = "../scripts/linux/install-nvidia.sh"
    environment_vars = [
      "NVIDIA_DRIVER_VERSION=${var.nvidia_driver_version}",
      "SKIP_GPU=${var.enable_gpu ? "false" : "true"}"
    ]
  }

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    script = "../scripts/linux/security-hardening.sh"
  }

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    script = "../scripts/linux/cleanup.sh"
  }

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    inline = [
      "/usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync"
    ]
    inline_shebang = "/bin/sh -x"
  }
}
