output "ssh" {
  sensitive = true
  value     = tls_private_key.ssh.private_key_pem
}

output "instance_ip" {
  value = aws_instance.zeet.public_ip
}
