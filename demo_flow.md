# 🎬 Flow Demo Hạ Tầng AWS — VietMove

> Không cần app thật. Dùng **nginx welcome page** làm TMS giả để chứng minh hạ tầng hoạt động.

---

## Chuẩn Bị Chung

### TMS giả (thay thế app thật)
Dùng **nginx container** trả về 1 trang HTML đơn giản:
```html
<h1>VietMove TMS</h1>
<p>Server: {{hostname}} | AZ: {{availability_zone}}</p>
```
Deploy lên Fargate → khi demo, refresh trang sẽ thấy hostname thay đổi → chứng minh ALB đang phân tải giữa các AZ.

### Tạo nhanh trên AWS
```bash
# Dùng image nginx có sẵn, không cần build
# Fargate task definition trỏ đến: public.ecr.aws/nginx/nginx:latest
```

---

## 5 Kịch Bản Demo

### Demo 1: Khách hàng B2B truy cập TMS (2 phút)

**Chứng minh**: Route 53 → CloudFront → WAF → ALB → Fargate hoạt động

| Bước | Hành động | Kết quả mong đợi |
|------|-----------|------------------|
| 1 | Mở browser, truy cập `tms.vietmove.demo` (domain Route 53) | Hiển thị trang nginx "VietMove TMS" |
| 2 | Refresh 3-4 lần | Hostname thay đổi → ALB đang phân tải giữa 3 AZ |
| 3 | Mở AWS Console → CloudFront | Thấy request đi qua CloudFront distribution |
| 4 | Mở AWS Console → WAF | Thấy request count tăng, không bị block |

---

### Demo 2: Chi nhánh kết nối qua S2S VPN (3 phút)

**Chứng minh**: S2S VPN → Transit Gateway → VPC Core hoạt động

| Bước | Hành động | Kết quả mong đợi |
|------|-----------|------------------|
| 1 | Mở AWS Console → VPC → Site-to-Site VPN | Thấy 2 connection (Đà Nẵng + Hà Nội), status **UP** (xanh) |
| 2 | Mở Transit Gateway → VPN Attachments | Thấy S2S VPN attach trực tiếp vào Transit Gateway |
| 3 | Từ "máy chi nhánh" (EC2 mô phỏng), ping IP private của ALB | Ping thành công → kết nối VPN hoạt động |
| 4 | Từ "máy chi nhánh", truy cập `http://10.1.x.x` (ALB private IP) | Hiển thị trang TMS → chi nhánh truy cập được |
| 5 | Mở Transit Gateway → Route Tables | Thấy route từ CGW → VPC Core |

> **Mẹo**: Không cần router thật ở chi nhánh. Dùng **1 EC2 instance** trong 1 VPC riêng, cấu hình strongSwan/OpenSwan làm Customer Gateway mô phỏng chi nhánh.

---

### Demo 3: Nhân viên remote VPN (2 phút)

**Chứng minh**: Client VPN + IAM Identity Center (SSO) hoạt động

| Bước | Hành động | Kết quả mong đợi |
|------|-----------|------------------|
| 1 | Mở AWS VPN Client trên laptop | Hiển thị VPN connection |
| 2 | Đăng nhập bằng tài khoản SSO (IAM Identity Center) | Xác thực thành công |
| 3 | Connect VPN | Status: Connected, nhận IP private `10.1.x.x` |
| 4 | Truy cập `http://10.1.x.x` (ALB) | Hiển thị trang TMS → nhân viên remote truy cập được |
| 5 | Mở IAM Identity Center Console | Thấy danh sách user, group, permission sets |

---

### Demo 4: Giám sát & Cảnh báo (3 phút)

**Chứng minh**: CloudWatch + SNS hoạt động

| Bước | Hành động | Kết quả mong đợi |
|------|-----------|------------------|
| 1 | Mở CloudWatch → Dashboard | Thấy metrics: CPU Fargate, request count ALB, DB connections |
| 2 | Mở CloudWatch → Alarms | Thấy alarm đã tạo (VD: CPU > 80%) |
| 3 | **Tạo tình huống giả**: Stop 1 Fargate task thủ công | Alarm chuyển sang **ALARM** (đỏ) |
| 4 | Kiểm tra email | Nhận email cảnh báo từ SNS: "Fargate task unhealthy" |
| 5 | Fargate tự khởi động lại task mới | Alarm trở lại **OK** (xanh) → self-healing |

---

### Demo 5: DR Failover ⭐ (Demo ấn tượng nhất — 5 phút)

**Chứng minh**: Route 53 failover → DR Region hoạt động

| Bước | Hành động | Kết quả mong đợi |
|------|-----------|------------------|
| 1 | Truy cập `tms.vietmove.demo` | Trang TMS hiện, ghi **"Region: ap-southeast-1 (HCM)"** |
| 2 | Mở Route 53 → Health Check | Status: **Healthy** (xanh) |
| 3 | **Mô phỏng sự cố**: Stop tất cả Fargate task ở Region 1 (hoặc đổi security group block traffic) | ALB Region 1 trả 503 |
| 4 | Chờ 30-60 giây, Route 53 health check detect | Status chuyển **Unhealthy** (đỏ) |
| 5 | Refresh `tms.vietmove.demo` | Trang TMS vẫn hiện, nhưng ghi **"Region: ap-northeast-1 (Hà Nội)"** 🎉 |
| 6 | Mở Aurora Console | Thấy Aurora DR đã promote thành Primary |
| 7 | Khôi phục Region 1, Route 53 tự chuyển traffic về | Failback hoàn tất |

> **Đây là demo gây ấn tượng nhất** — chứng minh hệ thống không gián đoạn khi trụ sở chính gặp sự cố, đúng yêu cầu đề tài.

---

## 🎯 Thứ Tự Demo Đề Xuất

```
Demo 1 (B2B truy cập)     →  Chứng minh hạ tầng cơ bản hoạt động
  ↓
Demo 3 (VPN remote)       →  Chứng minh xác thực SSO + VPN
  ↓
Demo 2 (S2S VPN)           →  Chứng minh kết nối chi nhánh
  ↓
Demo 4 (Monitoring)        →  Chứng minh giám sát + cảnh báo
  ↓
Demo 5 (DR Failover) ⭐    →  Kết thúc bằng demo ấn tượng nhất
```

---

## 💰 Chi Phí Demo Ước Tính

> [!TIP]
> Chỉ bật hạ tầng **khi demo**, tắt ngay sau đó. Dùng **Fargate Spot** và **Aurora Serverless** để tiết kiệm.

| Dịch vụ | Chi phí/giờ | Ghi chú |
|---------|-------------|---------|
| Fargate (6 task, 0.25 vCPU) | ~$0.12/h | 3 task mỗi Region |
| Aurora Serverless (2 cluster) | ~$0.12/h | Tối thiểu 0.5 ACU |
| NAT Gateway (4 cái) | ~$0.18/h | Tính theo giờ |
| ALB (2 cái) | ~$0.045/h | |
| Client VPN Endpoint | ~$0.15/h | Tính theo association |
| S2S VPN | ~$0.10/h | 2 connection |
| **Tổng** | **~$0.7/h** | **~17,000 VNĐ/giờ** |

Chạy demo 2 tiếng ≈ **34,000 VNĐ**. Nhớ **xóa tất cả** sau khi demo xong.

> [!WARNING]
> **Quan trọng**: Sau demo, vào **CloudFormation** (nếu dùng IaC) hoặc xóa thủ công tất cả resource. NAT Gateway và VPN Endpoint tính tiền theo giờ kể cả không dùng!
