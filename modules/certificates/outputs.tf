output "ca_key_algorithm" {
  value       = "${tls_private_key.root.algorithm}"
  description = "Algorithm used"
}

output "ca_private_key_pem" {
  value       = "${tls_private_key.root.private_key_pem}"
  description = "The private key data in PEM format (CA)"
}

output "ca_cert_pem" {
  value       = "${tls_self_signed_cert.root.cert_pem}"
  description = "Certificate"
}
