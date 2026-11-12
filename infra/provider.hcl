locals {
  tofu_version         = "1.13.9"
  aws_provider_version = "6.72.0"
  dev_env              = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  aws_region           = local.dev_env.locals.aws_region
  name_prefix          = local.dev_env.locals.name_prefix
  state_bucket_name    = "${local.name_prefix}-tfstate-${get_aws_account_id()}"
}

terraform_binary              = "tofu"
terraform_version_constraint  = local.tofu_version
terragrunt_version_constraint = "1.1.6"

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = "${local.tofu_version}"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "${local.aws_provider_version}"
    }
  }
}

provider "aws" {
  region = "${local.aws_region}"
}
EOF
}
