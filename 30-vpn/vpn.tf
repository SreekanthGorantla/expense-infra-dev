resource "aws_key_pair" "openvpnas" {
  key_name = "openvpnas"
  public_key = file("C:\\Devops\\daws\\openvpnas.pub")
}

resource "aws_instance" "openvpn" {
  ami                    = data.aws_ami.openvpn.id
  key_name = aws_key_pair.openvpnas.key_name
  vpc_security_group_ids = [data.aws_ssm_parameter.vpn_sg_id.value]
  instance_type          = "t3.micro"
  subnet_id = local.public_subnet_id
  user_data = file("user-data.sh")
  tags = merge(
    var.common_tags,
    {
        Name    = "/${var.project_name}/${var.environment}-vpn"
    }
  )
}

output "vpn_ip" {
  value = aws_instance.openvpn.public_ip
}