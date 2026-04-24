# Remote state backend is intentionally commented out.
#
# This is a public portfolio repository and per CLAUDE.md §4 it must be
# structurally incapable of touching real AWS state. A live S3 backend would
# attempt to read state from a real bucket during `terraform init`, and
# anyone cloning the repo could inadvertently point their local init at
# real infrastructure. Leaving the backend commented out forces `init` into
# local-state mode, which is what we want for `fmt` / `validate` / `tflint`.
#
# For a real deployment, uncomment and populate with the environment's
# bucket / key / DynamoDB lock table, and run `terraform init -migrate-state`.

# terraform {
#   backend "s3" {
#     bucket         = "REPLACE-ME-tfstate"
#     key            = "environments/dev/terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "REPLACE-ME-tfstate-lock"
#     encrypt        = true
#   }
# }
