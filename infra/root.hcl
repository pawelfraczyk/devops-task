include "provider" {
  path   = find_in_parent_folders("provider.hcl")
  expose = true
}

generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  backend "s3" {
    bucket       = "${include.provider.locals.state_bucket_name}"
    key          = "${path_relative_to_include("root")}/terraform.tfstate"
    region       = "${include.provider.locals.aws_region}"
    encrypt      = true
    use_lockfile = true
  }
}
EOF
}
