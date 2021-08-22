/*
output "aws_ami" {
    value = data.aws_ami.latest_amazon_linux_image.id
}
*/

output "myapp_server_public_ip" {
    value = aws_instance.myapp-server.public_ip
}
