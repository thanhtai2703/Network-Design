# 📋 Phân Tích Chức Năng Từng Dịch Vụ — VietMove

## Ký hiệu yêu cầu đề tài

| Mã | Yêu cầu |
|----|---------|
| **Y1** | Nhân viên truy cập Internet & hệ thống nội bộ |
| **Y2** | Server TMS (B2B SaaS) — độ sẵn sàng cao |
| **Y3** | Lưu trữ dữ liệu vận đơn, lộ trình, lịch sử |
| **Y4** | Xác thực tập trung (IAM Identity Center + Client VPN) |
| **Y5** | VPN nhân viên remote |
| **Y6** | Giám sát tập trung + cảnh báo sự cố |
| **Y7** | Chi nhánh truy cập TMS |
| **Y8** | VPN site-to-site chi nhánh |
| **Y9** | API endpoint mobile tài xế (real-time) |
| **Y10** | DR tại Hà Nội |
| **Y11** | Mở rộng chi nhánh không đổi kiến trúc |

---

## 🔍 Phân Tích Từng Dịch Vụ

### 🌐 Global Services (ngoài Region)

| Dịch vụ | Chức năng | Giải quyết yêu cầu | Cần thiết? |
|---------|-----------|-------------------|------------|
| **Route 53** | DNS phân giải tên miền → IP. **Failover routing**: khi Region 1 down, tự chuyển traffic sang Region 2 | **Y2** (HA), **Y10** (DR failover) | ✅ **Bắt buộc** |
| **CloudFront** | CDN — cache nội dung tĩnh ở edge gần người dùng, giảm latency. Kết hợp WAF chống DDoS | **Y2** (hiệu năng TMS), **Y9** (tài xế truy cập nhanh) | ✅ **Cần thiết** |
| **WAF** | Tường lửa ứng dụng web — chặn SQL injection, XSS, DDoS layer 7 | **Y2** (bảo vệ TMS) | ✅ **Cần thiết** |
| **IAM Identity Center (SSO)** | SSO — nhân viên đăng nhập 1 lần, truy cập tất cả hệ thống (AWS Console, TMS, VPN) | **Y4** (xác thực tập trung) | ✅ **Bắt buộc** — đề tài yêu cầu đích danh |

---

### 🏗️ VPC Core (`10.1.0.0/16`) — Application Layer

| Dịch vụ | Chức năng | Giải quyết yêu cầu | Cần thiết? |
|---------|-----------|-------------------|------------|
| **Internet Gateway** | Cổng ra Internet cho VPC (gắn VPC-level, không thuộc subnet) | **Y2**, **Y9** | ✅ **Bắt buộc** |
| **ALB (x3 AZ)** | Cân bằng tải — phân phối request đều giữa các Fargate task. Health check tự động | **Y2** (HA cho TMS) | ✅ **Bắt buộc** |
| **Client VPN Endpoint** | VPN cho nhân viên remote + trụ sở HCM kết nối vào VPC. Xác thực qua SSO | **Y4**, **Y5** | ✅ **Bắt buộc** — đề tài yêu cầu đích danh |
| **NAT Gateway (x3 AZ)** | Cho Fargate/Lambda ở private subnet truy cập Internet (pull image, gọi API) mà không bị expose | **Y2** | ✅ **Cần thiết** |
| **Fargate (x3 AZ)** | Chạy container TMS — serverless, auto-scale theo load | **Y2** (server TMS, HA) | ✅ **Bắt buộc** |
| **Lambda (x3 AZ)** | Serverless function — xử lý event-driven từ tài xế, xử lý SQS message | **Y9** (real-time) | ✅ **Cần thiết** |
| **VPC Endpoint** | Truy cập dịch vụ AWS (S3, CloudWatch, ECR) qua private network, không qua Internet | **Y2** (bảo mật), giảm cost | ✅ **Cần thiết** |

---

### 🏛️ Regional Services (trong Region, ngoài VPC)

| Dịch vụ | Chức năng | Giải quyết yêu cầu | Cần thiết? |
|---------|-----------|-------------------|------------|
| **API Gateway** | Quản lý API endpoint cho mobile tài xế — rate limiting, authentication, routing | **Y9** (API endpoint cho tài xế) | ✅ **Bắt buộc** — đề tài yêu cầu đích danh |
| **SQS** | Message queue — đệm request tài xế, chống mất dữ liệu khi spike traffic | **Y9**, **Y2** | ✅ **Cần thiết** |
| **EFS** | Shared file system cho Fargate (báo cáo, chứng từ vận đơn) | **Y2** | 🟡 **Tùy chọn** — bỏ được nếu TMS không cần shared storage |
| **CloudWatch** | Giám sát metrics (CPU, memory, request count), thu thập logs, dashboard, alarm | **Y6** (giám sát tập trung) | ✅ **Bắt buộc** — đề tài yêu cầu đích danh |
| **CloudTrail** | Ghi lại mọi API call trên AWS account — audit trail | **Y6** (giám sát) | ✅ **Cần thiết** |
| **S3 (logs)** | Lưu trữ log tập trung từ CloudTrail, CloudWatch Logs | **Y6** (lưu trữ log) | ✅ **Cần thiết** |
| **SNS** | Gửi notification — CloudWatch alarm trigger → SNS gửi email/SMS cho admin | **Y6** (cảnh báo sự cố) | ✅ **Bắt buộc** |

---

### 💾 VPC Data Layer (`10.2.0.0/16`)

| Dịch vụ | Chức năng | Giải quyết yêu cầu | Cần thiết? |
|---------|-----------|-------------------|------------|
| **Aurora Primary (W)** | Database chính (Writer) — lưu vận đơn, lộ trình, lịch sử giao hàng | **Y3** | ✅ **Bắt buộc** |
| **Aurora Standby (R) x2 AZ** | Read Replica — phân tải đọc, tự promote thành Primary khi Writer down | **Y2**, **Y3** | ✅ **Bắt buộc** |
| **ElastiCache Redis (x3 AZ)** | Cache dữ liệu truy vấn thường xuyên (trạng thái đơn hàng, session) | **Y2**, **Y9** | ✅ **Cần thiết** |
| **AWS Backup** | Backup tự động cho Aurora, point-in-time recovery | **Y3** (bảo vệ dữ liệu) | ✅ **Cần thiết** |
| **VPC Endpoint** | Truy cập S3/CloudWatch từ Data Layer qua private network | Bảo mật | ✅ Cần thiết |

---

### 🔒 VPC Security & Management (`10.3.0.0/16`)

| Dịch vụ | Chức năng | Giải quyết yêu cầu | Cần thiết? |
|---------|-----------|-------------------|------------|
| **Bastion Host (x2 AZ)** | Jump server — admin truy cập private resource qua Bastion. Điểm truy cập bảo mật duy nhất | **Y1** (quản trị) | ✅ **Cần thiết** |
| **VPC Endpoint** | Truy cập AWS services (SSM Session Manager) từ private subnet | Bảo mật | ✅ Cần thiết |

---

### 🔗 Networking (Transit Gateway + S2S VPN)

| Dịch vụ | Chức năng | Giải quyết yêu cầu | Cần thiết? |
|---------|-----------|-------------------|------------|
| **Transit Gateway (Region 1)** | Hub trung tâm kết nối tất cả VPC + S2S VPN. Thêm chi nhánh/VPC mới chỉ cần attach | **Y11** (mở rộng), **Y7**, **Y8** | ✅ **Bắt buộc** |
| **S2S VPN (x2)** | Kết nối mã hóa IPsec từ Customer Gateway chi nhánh vào Transit Gateway | **Y8** (VPN site-to-site) | ✅ **Bắt buộc** — đề tài yêu cầu đích danh |
| **Customer Gateway** | Đại diện router vật lý tại chi nhánh (Đà Nẵng, Hà Nội). Nằm on-premises, ngoài AWS | **Y7**, **Y8** | ✅ Bắt buộc (đi kèm S2S VPN) |

---

### 🛡️ DR Region (Hà Nội)

| Dịch vụ | Chức năng | Giải quyết yêu cầu | Cần thiết? |
|---------|-----------|-------------------|------------|
| **VPC-DR Core (ALB + Fargate)** | Bản sao TMS ở Hà Nội. Standby, khi Region 1 down → scale up | **Y10** (DR) | ✅ **Bắt buộc** |
| **NAT Gateway (DR)** | Cho Fargate DR ra Internet | **Y10** | ✅ Bắt buộc |
| **VPC Data Layer DR (Aurora + Redis)** | Aurora Global DB Replica + ElastiCache Redis. Khi failover → promote thành Primary | **Y10**, **Y3** | ✅ **Bắt buộc** |
| **VPC Endpoint (DR)** | Truy cập AWS services từ DR private subnet | Bảo mật | ✅ Cần thiết |
| **Transit Gateway (DR)** | Kết nối VPC trong DR Region | **Y10**, **Y11** | ✅ Bắt buộc |
| **Inter-Region Peering** | Kết nối 2 Transit Gateway giữa 2 Region | **Y10**, **Y11** | ✅ Bắt buộc |

---

### 👤 On-Premises (ngoài AWS)

| Thành phần | Vai trò | Kết nối vào |
|-----------|---------|-------------|
| **User (tài xế mobile)** | Dùng app cập nhật trạng thái đơn hàng | API Gateway (qua Internet) |
| **Remote Employee** | Nhân viên kỹ thuật làm việc từ xa | SSO → Client VPN Endpoint |
| **Customer Gateway (Office)** | Router chi nhánh Đà Nẵng / Hà Nội | S2S VPN → Transit Gateway |

---

## 📊 Tổng Kết

| Dịch vụ | Kết luận | Lý do |
|---------|----------|-------|
| 🟢 Route 53 | **Giữ** | Bắt buộc cho DNS + DR failover |
| 🟢 CloudFront | **Giữ** | B2B SaaS cần CDN |
| 🟢 WAF | **Giữ** | Ứng dụng public phải có WAF |
| 🟢 IAM Identity Center | **Giữ** | Đề tài yêu cầu đích danh |
| 🟢 IGW | **Giữ** | Bắt buộc cho public subnet |
| 🟢 ALB | **Giữ** | Bắt buộc cho HA |
| 🟢 Client VPN | **Giữ** | Đề tài yêu cầu đích danh |
| 🟢 NAT GW | **Giữ** | Fargate private cần ra Internet |
| 🟢 Fargate | **Giữ** | Chạy TMS — core system |
| 🟢 Lambda | **Giữ** | Xử lý event mobile real-time |
| 🟢 API Gateway | **Giữ** | Đề tài yêu cầu API cho tài xế |
| 🟢 SQS | **Giữ** | Đệm request tài xế, chống mất data |
| 🟢 Aurora + Standby | **Giữ** | Database chính + HA |
| 🟢 Redis | **Giữ** | Cache cho real-time tracking |
| 🟢 Backup | **Giữ** | Bảo vệ dữ liệu |
| 🟢 Bastion | **Giữ** | Quản trị bảo mật |
| 🟢 CloudWatch + SNS | **Giữ** | Đề tài yêu cầu giám sát + cảnh báo |
| 🟢 CloudTrail + S3 | **Giữ** | Audit log |
| 🟢 S2S VPN + CGW | **Giữ** | Đề tài yêu cầu đích danh |
| 🟢 Transit GW + Peering | **Giữ** | Đề tài yêu cầu mở rộng |
| 🟢 DR Region (toàn bộ) | **Giữ** | Đề tài yêu cầu đích danh |
| 🟡 **EFS** | **Tùy chọn** | Giữ nếu TMS cần shared file. Bỏ nếu không |

> [!TIP]
> **Kết luận**: Tất cả dịch vụ trên sơ đồ cuối cùng đều cần thiết, không có dịch vụ dư thừa. Chỉ **EFS** là tùy chọn.
