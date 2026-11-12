variable "bucket_name" {
  description = "State bucket name. Terragrunt appends the caller account id at runtime."
  type        = string
}
