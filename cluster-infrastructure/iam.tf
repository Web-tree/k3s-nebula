resource "aws_iam_user" "k3s_node" {
  name = "k3s-node-${var.cluster_name}-${var.env}"
  path = "/system/"
}

resource "aws_iam_access_key" "k3s_node" {
  user = aws_iam_user.k3s_node.name
}

resource "aws_iam_user_policy" "k3s_node_ssm" {
  name = "k3s-node-ssm-policy"
  user = aws_iam_user.k3s_node.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = [
          "arn:aws:ssm:${var.aws_region}:*:parameter${var.ssm_parameter_path}",
          "arn:aws:ssm:${var.aws_region}:*:parameter${var.hcloud_token_ssm_path}"
        ]
      }
    ]
  })
}
