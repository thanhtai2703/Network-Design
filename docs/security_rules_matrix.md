# 🔒 Security Rules Matrix — VietMove

> Bảng thiết kế Security Groups & NACLs cho toàn bộ hệ thống. Dùng làm input cho task 2.5 (SG) và 2.6 (NACL) trong [task_assignment.md](../task_assignment.md).

## Tham chiếu IP Plan

| VPC | CIDR | Public subnets | Private subnets |
|-----|------|----------------|-----------------|
| VPC Core (HCM) | `10.1.0.0/16` | `10.1.1.0/24`, `10.1.2.0/24`, `10.1.3.0/24` | `10.1.10.0/24`, `10.1.11.0/24`, `10.1.12.0/24` |
| VPC Data (HCM) | `10.2.0.0/16` | — | `10.2.1.0/24`, `10.2.2.0/24`, `10.2.3.0/24` |
| VPC Mgmt (HCM) | `10.3.0.0/16` | `10.3.1.0/24`, `10.3.2.0/24` | — |
| VPC-DR Core (HN) | `10.10.0.0/16` | `10.10.1.0/24` | `10.10.10.0/24`, `10.10.11.0/24` |
| VPC-DR Data (HN) | `10.20.0.0/16` | — | `10.20.1.0/24`, `10.20.2.0/24` |

Chi tiết: xem [docs/](./).

---

## 1. Security Groups Matrix

> SG là **stateful** — return traffic tự được phép, chỉ cần khai báo 1 chiều.
>
> Cross-VPC traffic (qua Transit Gateway) **không tham chiếu SG được**, phải dùng **CIDR**.

| # | SG Name | VPC | Gắn vào | Direction | Proto | Port | Source / Dest | Mục đích |
|---|---------|-----|---------|-----------|-------|------|--------------|---------|
| 1 | **sg-alb** | Core | ALB (public) | IN | TCP | 80, 443 | `0.0.0.0/0` | Internet → ALB |
|   |           |      |              | OUT | TCP | 80    | `sg-fargate` | ALB → Fargate |
| 2 | **sg-fargate** | Core | Fargate task (private) | IN | TCP | 80 | `sg-alb` | ALB → Fargate |
|   |               |      |                        | OUT | TCP | 3306 | `10.2.1.0/24`, `10.2.2.0/24`, `10.2.3.0/24` | → Aurora (qua TGW) |
|   |               |      |                        | OUT | TCP | 6379 | `10.2.1.0/24`, `10.2.2.0/24`, `10.2.3.0/24` | → Redis (qua TGW) |
|   |               |      |                        | OUT | TCP | 443  | `0.0.0.0/0` | Pull image ECR, AWS API |
| 3 | **sg-lambda** | Core | Lambda ENI (private) | OUT | TCP | 3306 | `10.2.0.0/16` | → Aurora |
|   |              |      |                      | OUT | TCP | 443 | `0.0.0.0/0` | AWS API, SQS |
| 4 | **sg-aurora** | Data | Aurora cluster | IN | TCP | 3306 | `10.1.10.0/24`, `10.1.11.0/24`, `10.1.12.0/24` | Fargate + Lambda |
|   |              |      |                | IN | TCP | 3306 | `10.3.1.0/24`, `10.3.2.0/24` | Bastion quản trị |
|   |              |      |                | IN | TCP | 3306 | `10.10.10.0/24`, `10.10.11.0/24` | DR Fargate (failover) |
| 5 | **sg-redis** | Data | ElastiCache | IN | TCP | 6379 | `10.1.10.0/24`, `10.1.11.0/24`, `10.1.12.0/24` | Fargate + Lambda |
|   |             |      |             | IN | TCP | 6379 | `10.3.1.0/24`, `10.3.2.0/24` | Bastion |
| 6 | **sg-bastion** | Mgmt | Bastion EC2 | IN | TCP | 22 | `<Admin IP>/32` | SSH từ admin |
|   |               |      |             | OUT | TCP | 22 | `10.1.0.0/16`, `10.2.0.0/16` | Jump vào private |
|   |               |      |             | OUT | TCP | 3306, 6379 | `10.2.0.0/16` | Quản trị DB/cache |
| 7 | **sg-vpn** | Core | Client VPN ENI | IN | UDP | 443 | `0.0.0.0/0` | Client VPN connect |
|   |           |      |                | OUT | All | All | `10.0.0.0/8` | Forward traffic vào VPC |
| 8 | **sg-vpc-endpoint** | mỗi VPC | Interface Endpoint | IN | TCP | 443 | VPC CIDR | Truy cập AWS service qua private network |
| 9 | **sg-dr-alb** | DR Core | DR-ALB | IN | TCP | 80, 443 | `0.0.0.0/0` | Internet → DR-ALB (khi failover) |
|   |              |         |        | OUT | TCP | 80 | `sg-dr-fargate` | DR-ALB → DR-Fargate |
| 10 | **sg-dr-fargate** | DR Core | DR-Fargate | IN | TCP | 80 | `sg-dr-alb` | DR-ALB → DR-Fargate |
|    |                  |         |            | OUT | TCP | 3306 | `10.20.1.0/24`, `10.20.2.0/24` | → Aurora DR |
|    |                  |         |            | OUT | TCP | 443  | `0.0.0.0/0` | Pull image, AWS API |
| 11 | **sg-dr-aurora** | DR Data | Aurora Replica | IN | TCP | 3306 | `10.10.10.0/24`, `10.10.11.0/24` | DR-Fargate |
|    |                  |         |                | IN | TCP | 3306 | `10.2.0.0/16` | Aurora Global replication |

---

## 2. NACL Matrix

> NACL là **stateless** — phải mở cả IN và OUT, kể cả ephemeral ports `1024–65535`.
>
> Rule number nhỏ ưu tiên trước. Để khoảng 10 đơn vị để dễ chèn sau.

### nacl-public-core — Áp dụng cho Core public subnets

| Direction | Rule# | Proto | Port | CIDR | Action | Ghi chú |
|-----------|-------|-------|------|------|--------|---------|
| IN | 100 | TCP | 80 | `0.0.0.0/0` | ALLOW | HTTP → ALB |
| IN | 110 | TCP | 443 | `0.0.0.0/0` | ALLOW | HTTPS → ALB |
| IN | 120 | UDP | 443 | `0.0.0.0/0` | ALLOW | Client VPN |
| IN | 130 | TCP | 1024-65535 | `0.0.0.0/0` | ALLOW | Ephemeral (response) |
| OUT | 100 | TCP | 1024-65535 | `0.0.0.0/0` | ALLOW | Response về client |
| OUT | 110 | TCP | 80, 443 | `0.0.0.0/0` | ALLOW | NAT outbound |
| OUT | 120 | TCP | 80 | `10.1.10.0/24`, `10.1.11.0/24`, `10.1.12.0/24` | ALLOW | ALB → Fargate |

### nacl-private-core — Áp dụng cho Core private subnets

| Direction | Rule# | Proto | Port | CIDR | Action | Ghi chú |
|-----------|-------|-------|------|------|--------|---------|
| IN | 100 | TCP | 80 | `10.1.1.0/24`, `10.1.2.0/24`, `10.1.3.0/24` | ALLOW | Từ ALB |
| IN | 110 | TCP | 1024-65535 | `0.0.0.0/0` | ALLOW | NAT return |
| IN | 120 | TCP | 1024-65535 | `10.0.0.0/8` | ALLOW | Cross-VPC return |
| OUT | 100 | TCP | 3306 | `10.2.0.0/16` | ALLOW | → Aurora |
| OUT | 110 | TCP | 6379 | `10.2.0.0/16` | ALLOW | → Redis |
| OUT | 120 | TCP | 443 | `0.0.0.0/0` | ALLOW | ECR, AWS API |
| OUT | 130 | TCP | 1024-65535 | `10.1.1.0/24`, `10.1.2.0/24`, `10.1.3.0/24` | ALLOW | Response về ALB |

### nacl-data — Áp dụng cho Data private subnets

| Direction | Rule# | Proto | Port | CIDR | Action | Ghi chú |
|-----------|-------|-------|------|------|--------|---------|
| IN | 100 | TCP | 3306 | `10.1.0.0/16` | ALLOW | Fargate + Lambda → Aurora |
| IN | 110 | TCP | 6379 | `10.1.0.0/16` | ALLOW | Fargate + Lambda → Redis |
| IN | 120 | TCP | 3306, 6379 | `10.3.0.0/16` | ALLOW | Bastion → DB/Redis |
| IN | 130 | TCP | 3306 | `10.10.0.0/16` | ALLOW | DR-Fargate (failover) |
| OUT | 100 | TCP | 1024-65535 | `10.0.0.0/8` | ALLOW | Response về client |
| OUT | 110 | TCP | 443 | `0.0.0.0/0` | ALLOW | VPC Endpoint → S3 |

### nacl-mgmt — Áp dụng cho Mgmt public subnets

| Direction | Rule# | Proto | Port | CIDR | Action | Ghi chú |
|-----------|-------|-------|------|------|--------|---------|
| IN | 100 | TCP | 22 | `<Admin IP>/32` | ALLOW | SSH whitelist |
| IN | 110 | TCP | 1024-65535 | `0.0.0.0/0` | ALLOW | Ephemeral return |
| OUT | 100 | TCP | 22 | `10.1.0.0/16`, `10.2.0.0/16` | ALLOW | Jump SSH |
| OUT | 110 | TCP | 3306, 6379 | `10.2.0.0/16` | ALLOW | Quản trị DB/cache |
| OUT | 120 | TCP | 80, 443 | `0.0.0.0/0` | ALLOW | yum update, AWS API |
| OUT | 130 | TCP | 1024-65535 | `0.0.0.0/0` | ALLOW | SSH return |

### nacl-dr-public-core — DR public subnet

Giống `nacl-public-core` nhưng đổi CIDR private sang `10.10.10.0/24`, `10.10.11.0/24`.

### nacl-dr-private-core — DR private subnets

| Direction | Rule# | Proto | Port | CIDR | Action | Ghi chú |
|-----------|-------|-------|------|------|--------|---------|
| IN | 100 | TCP | 80 | `10.10.1.0/24` | ALLOW | Từ DR-ALB |
| IN | 110 | TCP | 1024-65535 | `0.0.0.0/0` | ALLOW | NAT return |
| OUT | 100 | TCP | 3306 | `10.20.0.0/16` | ALLOW | → Aurora DR |
| OUT | 110 | TCP | 443 | `0.0.0.0/0` | ALLOW | ECR, AWS API |
| OUT | 120 | TCP | 1024-65535 | `10.10.1.0/24` | ALLOW | Response về ALB |

### nacl-dr-data — DR Data private subnets

| Direction | Rule# | Proto | Port | CIDR | Action | Ghi chú |
|-----------|-------|-------|------|------|--------|---------|
| IN | 100 | TCP | 3306 | `10.10.0.0/16` | ALLOW | DR-Fargate → Aurora |
| IN | 110 | TCP | 3306 | `10.2.0.0/16` | ALLOW | Aurora Global replication |
| OUT | 100 | TCP | 1024-65535 | `10.0.0.0/8` | ALLOW | Response |

---

## 3. Phụ thuộc triển khai

| Resource | Phụ thuộc | Owner |
|----------|-----------|-------|
| sg-alb, sg-fargate, sg-lambda, sg-vpn, sg-vpc-endpoint (Core) | VPC Core ✅ | A → D dùng |
| sg-aurora, sg-redis, sg-vpc-endpoint (Data) | VPC Data ⏳ | B → D dùng |
| sg-bastion, sg-vpc-endpoint (Mgmt) | VPC Mgmt ⏳ | C → D dùng |
| sg-dr-* | VPC-DR Core + Data ⏳ | B → D dùng |
| nacl-public-core, nacl-private-core | VPC Core ✅ | D |
| nacl-data | VPC Data ⏳ | D (sau khi B xong) |
| nacl-mgmt | VPC Mgmt ⏳ | D (sau khi C xong) |
| nacl-dr-* | DR VPCs ⏳ | D (sau khi B xong) |

---

## 4. Checklist trước khi apply

- [ ] Mỗi SG đã định nghĩa cả inbound + outbound rule cần thiết
- [ ] Cross-VPC traffic dùng CIDR, không tham chiếu SG ID
- [ ] NACL đã mở ephemeral port `1024–65535` ở chiều ngược lại
- [ ] Default NACL của AWS đã bị override (associate NACL custom vào subnet)
- [ ] Không có SG/NACL mở `0.0.0.0/0` cho DB port (3306, 6379)
- [ ] SSH Bastion chỉ mở cho IP admin whitelist, không mở `0.0.0.0/0`
- [ ] Rule number trong NACL có khoảng (100, 110, 120…) để dễ chèn sau
