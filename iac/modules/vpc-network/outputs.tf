# ------------------------------------------------------------------------------
# Outputs para consumir en otros módulos
# ------------------------------------------------------------------------------


output "vpc_id" {
  description = "ID de la VPC creada"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "Lista de IDs de subnets privadas"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "Lista de IDs de subnets públicas"
  value       = module.vpc.public_subnets
}
