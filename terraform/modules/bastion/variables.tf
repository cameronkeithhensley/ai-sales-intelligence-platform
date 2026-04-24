variable "environment" {
  description = "Deployment environment identifier (dev, staging, prod). Used in resource names and tags."
  type        = string
}

variable "name" {
  description = "Logical name suffix for the bastion (e.g. 'admin'). Used in resource names."
  type        = string
  default     = "bastion"
}

variable "vpc_id" {
  description = "VPC ID the bastion security group belongs to."
  type        = string
}

variable "subnet_id" {
  description = "Private subnet ID to place the bastion instance in."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type. t3.micro is plenty for running psql + light admin tasks."
  type        = string
  default     = "t3.micro"
}

variable "additional_security_group_ids" {
  description = "Extra security group IDs to attach to the bastion (e.g. IDs the bastion needs to be a member of so downstream SG rules can reference it)."
  type        = list(string)
  default     = []
}

variable "root_volume_size" {
  description = "Size of the encrypted root EBS volume in GiB."
  type        = number
  default     = 20
}

variable "kms_key_id" {
  description = "KMS key ID/ARN for root volume encryption. Null => AWS-managed default EBS key."
  type        = string
  default     = null
}

variable "additional_iam_policy_arns" {
  description = "Extra IAM policy ARNs to attach to the bastion instance role (beyond AmazonSSMManagedInstanceCore)."
  type        = list(string)
  default     = []
}

variable "user_data_extra" {
  description = "Optional extra shell commands to append to the default cloud-init user data."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags merged onto every resource created by this module."
  type        = map(string)
  default     = {}
}
