resource "aws_iam_role" "zeet" {
  name = "zeet-${var.cluster_name}"
  path = "/"

  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"]

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_instance_profile" "zeet" {
  name = "zeet-${var.cluster_name}"
  role = aws_iam_role.zeet.name
}
