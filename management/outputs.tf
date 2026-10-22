output "jumpbox_public_ip" {
  value = module.jumpbox.public_ip
}

output "jumpbox_private_ip" {
  value = module.jumpbox.private_ip
}

output "jumpbox_admin_username" {
  value = module.jumpbox.admin_username
}

output "jumpbox_principal_id" {
  value = module.jumpbox.principal_id
}
