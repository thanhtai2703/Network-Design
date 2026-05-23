aws_region   = "ap-southeast-1"
project_name = "VietMove"

vpc_core_cidr = "10.1.0.0/16"
vpc_data_cidr = "10.2.0.0/16"
vpc_mgmt_cidr = "10.3.0.0/16"

# Whitelist IP admin được phép SSH vào Bastion
# THAY bằng IP thật trước khi apply. Demo có thể dùng IP văn phòng / IP công cộng của bạn.
admin_ssh_cidrs = [
  # "203.0.113.10/32",
]

# Giữ 1 VPC giả lập (Đà Nẵng) để tiện test S2S VPN trong quá trình build.
# Demo thật sẽ dùng strongSwan trên máy cá nhân làm CGW.
offices = {
  danang = { cidr = "10.100.0.0/16" }
  # hanoi = { cidr = "10.101.0.0/16" }  # bật lại khi cần demo 2 chi nhánh
}
