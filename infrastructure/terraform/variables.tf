variable "db_url" {
  description = "URL de conexión a la base de datos Supabase"
  type        = string
  sensitive   = true # Esto oculta el valor en los logs de la consola
}

variable "jwt_secret" {
  description = "Clave secreta para JWT"
  type        = string
  sensitive   = true
}

variable "env" {
  description = "Entorno de despliegue (qa o prod)"
  type        = string
  default     = "qa"
}