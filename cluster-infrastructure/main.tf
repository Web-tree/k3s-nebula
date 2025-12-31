# Main resource definitions

# T046: Generate cluster token
resource "random_password" "k3s_token" {
  length  = 64
  special = false
}
