variable "os_version_name" {
  description = "OS release name"
  type        = string
  default     = "jammy"
}

variable "os_version" {
  description = "OS version"
  type        = string
  default     = "22.04"
}

variable "system_memory_toolbox" {
  description = "System memory for the CICD-toolbox"
  type        = string
  default     = "16484"
}

variable "system_cores_toolbox" {
  description = "System cores for the CICD-toolbox"
  type        = string
  default     = 4
}

variable "disk_size_toolbox" {
  description = "Disk size for the CICD-toolbox"
  type        = string
  default     = 53687091200
}

variable "system_memory_kvm" {
  description = "System memory for the CICD-toolbox"
  type        = string
  default     = "16484"
}

variable "system_cores_kvm" {
  description = "System cores for the CICD-toolbox"
  type        = string
  default     = 4
}

variable "disk_size_kvm" {
  description = "Disk size for target data"
  type        = string
  default     = 2147483648
}