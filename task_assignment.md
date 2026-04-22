# 👥 Phân Công Công Việc — Nhóm 4 Người

## Nguyên tắc
- Chia theo **phase**: hoàn thiện 100% hạ tầng trước → rồi mới deploy ứng dụng
- Mỗi phase phải **check xong** trước khi sang phase tiếp theo
- Mỗi người phụ trách **triển khai + demo** phần của mình

---

## Phase 1 — VPC & Subnet (Nền tảng)

> ⛔ **Checkpoint**: Tất cả VPC, subnet, route table, IGW phải tạo xong. Ping được giữa các subnet trong cùng VPC.

| Task | Người | Chi tiết |
|------|-------|---------|
| VPC Core `10.1.0.0/16` | **A** | 3 AZ × 2 subnet (public + private), route tables, IGW |
| VPC Data Layer `10.2.0.0/16` | **B** | 3 AZ × 1 private subnet, route tables |
| VPC Security & Mgmt `10.3.0.0/16` | **C** | 2 AZ × 1 public subnet, route tables |
| Security Groups toàn bộ | **D** | sg-alb, sg-fargate, sg-aurora, sg-redis, sg-bastion, sg-vpn |
| NACLs | **D** | Rules cho public/private subnet |
| NAT Gateway (3 AZ) trong VPC Core | **A** | Elastic IP + NAT mỗi AZ |

**Kiểm tra Phase 1:**
- [ ] Mỗi VPC đã tạo đúng CIDR
- [ ] Subnet đúng AZ, đúng loại (public/private)
- [ ] Route table: public → IGW, private → NAT
- [ ] Security Groups đã tạo đủ

---

## Phase 2 — Kết Nối Giữa Các VPC (Transit Gateway)

> ⛔ **Checkpoint**: Tất cả VPC phải kết nối được với nhau qua Transit Gateway.

| Task | Người | Chi tiết |
|------|-------|---------|
| Tạo Transit Gateway (Region 1) | **C** | TGW + route tables |
| Attach VPC Core vào TGW | **A** | VPC attachment |
| Attach VPC Data vào TGW | **B** | VPC attachment |
| Attach VPC Mgmt vào TGW | **C** | VPC attachment |
| VPC Endpoint (VPC Core) | **A** | ECR, S3, CloudWatch Logs |
| VPC Endpoint (VPC Data) | **B** | S3 |
| VPC Endpoint (VPC Mgmt) | **C** | SSM |

**Kiểm tra Phase 2:**
- [ ] Từ VPC Mgmt (Bastion) ping được private IP trong VPC Core
- [ ] Từ VPC Core ping được private IP trong VPC Data
- [ ] TGW route tables có route cho tất cả VPC CIDR

---

## Phase 3 — VPN & Xác Thực

> ⛔ **Checkpoint**: Chi nhánh và nhân viên remote kết nối được vào VPC Core.

| Task | Người | Chi tiết |
|------|-------|---------|
| S2S VPN (Đà Nẵng) attach vào TGW | **C** | Customer Gateway (EC2 + strongSwan mô phỏng) |
| S2S VPN (Hà Nội) attach vào TGW | **C** | Customer Gateway |
| Client VPN Endpoint (VPC Core) | **C** | Certificate, association với subnet |
| IAM Identity Center (SSO) | **C** | Tạo user, group, permission sets, liên kết Client VPN |
| Hỗ trợ test kết nối | **D** | Test từ CGW → TGW → VPC Core |

**Kiểm tra Phase 3:**
- [ ] S2S VPN tunnel status: **UP** (xanh)
- [ ] Từ EC2 mô phỏng chi nhánh, ping được ALB private IP
- [ ] Client VPN connect thành công, nhận IP `10.1.x.x`
- [ ] SSO đăng nhập được

---

## Phase 4 — Database & Cache

> ⛔ **Checkpoint**: Database và cache hoạt động, Fargate kết nối được đến Aurora/Redis.

| Task | Người | Chi tiết |
|------|-------|---------|
| Deploy Aurora cluster | **B** | Primary (writer) + 2 Replica (reader) |
| Deploy ElastiCache Redis | **B** | Cluster mode, 3 AZ |
| Cấu hình AWS Backup | **B** | Backup plan cho Aurora (daily) |
| Test kết nối DB | **D** | Từ Bastion → Aurora endpoint, Redis endpoint |

**Kiểm tra Phase 4:**
- [ ] Aurora writer endpoint hoạt động
- [ ] Redis cluster endpoint hoạt động
- [ ] Từ VPC Core (Bastion hoặc test container) connect được Aurora + Redis
- [ ] Backup plan đã tạo

---

## Phase 5 — Deploy Ứng Dụng (Fargate + Lambda)

> ⛔ **Checkpoint**: TMS (nginx) chạy trên Fargate, API Gateway + Lambda hoạt động.

| Task | Người | Chi tiết |
|------|-------|---------|
| Deploy Fargate (nginx TMS giả) | **A** | ECS cluster, task definition, service (3 AZ) |
| Cấu hình ALB | **A** | Target group → Fargate, health check, listener 80/443 |
| Setup API Gateway + Lambda | **A** | REST API cho mobile tài xế |
| Setup SQS | **A** | Queue nhận message từ Lambda |
| Setup EFS (tùy chọn) | **A** | Mount target trong private subnet |

**Kiểm tra Phase 5:**
- [ ] Truy cập ALB DNS → thấy trang nginx TMS
- [ ] Refresh → hostname thay đổi (ALB phân tải)
- [ ] API Gateway endpoint trả response
- [ ] Lambda xử lý → gửi message vào SQS

---

## Phase 6 — Edge & DNS (CloudFront, WAF, Route 53)

> ⛔ **Checkpoint**: Truy cập TMS qua domain name, có CDN + WAF bảo vệ.

| Task | Người | Chi tiết |
|------|-------|---------|
| Setup CloudFront | **A** | Distribution trỏ về ALB |
| Setup WAF | **A** | Rules cơ bản gắn vào CloudFront |
| Setup Route 53 | **A** | Domain, record trỏ về CloudFront |

**Kiểm tra Phase 6:**
- [ ] Truy cập `tms.vietmove.demo` → thấy trang TMS
- [ ] WAF dashboard thấy request count
- [ ] CloudFront cache hoạt động

---

## Phase 7 — Monitoring & Logging

> ⛔ **Checkpoint**: Giám sát hoạt động, nhận được email cảnh báo.

| Task | Người | Chi tiết |
|------|-------|---------|
| CloudWatch dashboards + alarms | **C** | CPU, request count, DB connections |
| SNS topic + email subscription | **C** | Gửi cảnh báo khi alarm trigger |
| CloudTrail | **D** | Bật audit logging |
| S3 bucket (logs) | **D** | Lưu CloudTrail + CloudWatch logs |

**Kiểm tra Phase 7:**
- [ ] CloudWatch dashboard hiện metrics
- [ ] Stop 1 Fargate task → nhận email cảnh báo từ SNS
- [ ] CloudTrail ghi log API calls

---

## Phase 8 — DR Region (Hà Nội)

> ⛔ **Checkpoint**: DR hoạt động, failover thành công.

| Task | Người | Chi tiết |
|------|-------|---------|
| VPC-DR Core (2 AZ) | **B** | Public + private subnet, IGW, NAT |
| VPC-DR Data (2 AZ) | **B** | Private subnet |
| Transit Gateway DR | **B** | Attach 2 VPC DR |
| Inter-Region TGW Peering | **C** | Kết nối TGW Region 1 ↔ TGW Region 2 |
| Aurora Global Database | **B** | Replication Region 1 → Region 2 |
| ElastiCache Redis DR | **B** | Replica |
| Fargate DR (standby) | **B** | Nginx TMS, desired count = 1 |
| ALB DR | **B** | Target group → Fargate DR |
| Route 53 Failover routing | **B** | Health check + failover policy |
| S2S VPN Hà Nội → TGW DR | **C** | CGW Hà Nội kết nối vào DR |

**Kiểm tra Phase 8:**
- [ ] Aurora Global DB replication lag < 1s
- [ ] Truy cập DR ALB → thấy trang TMS (Region Hà Nội)
- [ ] Stop Fargate Region 1 → Route 53 chuyển sang DR → TMS vẫn hoạt động 🎉

---

## Phase 9 — Test End-to-End & Demo

| Task | Người | Chi tiết |
|------|-------|---------|
| Test Demo 1 (B2B truy cập) | **A** | Route 53 → CloudFront → WAF → ALB → Fargate |
| Test Demo 2 (S2S VPN chi nhánh) | **C** | CGW → TGW → VPC Core |
| Test Demo 3 (Client VPN remote) | **C** | VPN Client → SSO → TMS |
| Test Demo 4 (Monitoring) | **C** | CloudWatch alarm → SNS email |
| Test Demo 5 (DR Failover) | **B** | Route 53 failover → DR Region |
| Viết tài liệu thuyết minh | **D** | Giải thích kiến trúc, lý do chọn dịch vụ |
| Viết slide thuyết trình | **D** | Flow demo, kiến trúc tổng quan |
| Quay video demo backup | **D** | Phòng trường hợp demo live lỗi |

---

## 📅 Timeline (3 tuần)

### Tuần 1
| Ngày | Phase | Ai làm |
|------|-------|--------|
| Ngày 1-2 | **Phase 1**: VPC & Subnet | A, B, C, D (song song) |
| Ngày 3 | **Phase 2**: Transit Gateway | C tạo TGW, A/B attach |
| Ngày 4-5 | **Phase 3**: VPN & SSO | C |
| Ngày 5 | **Phase 4**: Database & Cache | B |

### Tuần 2
| Ngày | Phase | Ai làm |
|------|-------|--------|
| Ngày 1-2 | **Phase 5**: Fargate + Lambda | A |
| Ngày 3 | **Phase 6**: CloudFront + WAF + Route 53 | A |
| Ngày 4 | **Phase 7**: Monitoring | C, D |
| Ngày 5 | **Phase 8**: DR Region | B, C |

### Tuần 3
| Ngày | Phase | Ai làm |
|------|-------|--------|
| Ngày 1-3 | **Phase 8** (tiếp) + **Phase 9**: Test | Cả nhóm |
| Ngày 4-5 | Tài liệu + slide + video | D (cả nhóm hỗ trợ) |

---

## 📋 Tổng Hợp Khối Lượng Mỗi Người

| Người | Phase chính | Khối lượng |
|-------|------------|------------|
| **A** | 1 (VPC Core), 5 (Fargate), 6 (Edge) | ⭐⭐⭐ |
| **B** | 1 (VPC Data), 4 (DB), 8 (DR) | ⭐⭐⭐⭐ (nhiều nhất) |
| **C** | 1 (VPC Mgmt), 2 (TGW), 3 (VPN), 7 (Monitoring) | ⭐⭐⭐⭐ |
| **D** | 1 (SG/NACL), 7 (Logging), 9 (Docs) | ⭐⭐ |

> [!IMPORTANT]
> **Quy tắc vàng**: Không ai được bắt đầu phase tiếp theo nếu phase hiện tại chưa pass hết checklist. Mỗi checkpoint cần ít nhất 2 người verify.
