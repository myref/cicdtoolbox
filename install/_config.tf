# Specify providers
terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
    ansible = {
      source = "nbering/ansible"
      version = "1.0.4"
    }

  }
}
