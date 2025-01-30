# Defining VM Volumes
resource "libvirt_volume" "toolbox" {
  name      = "cicdtoolbox.qcow2"
  pool      = "default"
  source    = "https://cloud-images.ubuntu.com/releases/${var.os_version_name}/release/ubuntu-${var.os_version}-server-cloudimg-amd64.img"
  format    = "qcow2"
}

resource "libvirt_volume" "kvmhost" {
  name      = "kvmhost.qcow2"
  pool      = "default"
  source    = "https://cloud-images.ubuntu.com/releases/${var.os_version_name}/release/ubuntu-${var.os_version}-server-cloudimg-amd64.img"
  format    = "qcow2"
}

data "template_file" "user_data_toolbox" {
  template = "${file("${path.module}/cloud_init_toolbox.cfg")}"
}

data "template_file" "user_data_kvm" {
  template = "${file("${path.module}/cloud_init_kvm.cfg")}"
}

resource "libvirt_cloudinit_disk" "commoninit_toolbox" {
  name = "commoninit_toolbox.iso"
  pool = "default"
  user_data      = "${data.template_file.user_data_toolbox.rendered}"
}

resource "libvirt_cloudinit_disk" "commoninit_kvm" {
  name = "commoninit_kvm.iso"
  pool = "default"
  user_data      = "${data.template_file.user_data_kvm.rendered}"
}

# Define KVM domain to create
resource "libvirt_domain" "toolbox" {
  name        = "cicd-toolbox"
  memory      = "${var.system_memory_toolbox}"
  vcpu        = "${var.system_cores_toolbox}"
  running     = true

  disk {
      volume_id = "${libvirt_volume.toolbox.id}"
    }

  network_interface {
    network_name = "default" # List networks with virsh net-list
    wait_for_lease = true
  }

  cloudinit = "${libvirt_cloudinit_disk.commoninit_toolbox.id}"

  console {
    type = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type = "spice"
    listen_type = "address"
    autoport = true
  }
}

resource "libvirt_domain" "kvm" {
  name        = "kvm-host"
  memory      = "${var.system_memory_kvm}"
  vcpu        = "${var.system_cores_kvm}"
  running     = true

  disk {
      volume_id = "${libvirt_volume.kvm.id}"
    }

  network_interface {
    network_name = "default" # List networks with virsh net-list
    wait_for_lease = true
  }

  cloudinit = "${libvirt_cloudinit_disk.commoninit_kvm.id}"

  console {
    type = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type = "spice"
    listen_type = "address"
    autoport = true
  }
}

resource "ansible_host" "toolbox" {
    inventory_hostname = "${var.toolbox_type}-${var.toolbox_name}"
    groups = ["${var.toolbox_type}","${var.toolbox_type}_test"]
    vars = {
        ansible_host = "${libvirt_domain.toolbox.network_interface.0.addresses.0}"
    }
}
resource "ansible_host" "kvmhost" {
    inventory_hostname = "kvmhost"
    groups = ["kvmhost"]
    vars = {
        ansible_host = "${libvirt_domain.kvm.network_interface.0.addresses.0}"
    }
}