Bài tập này giả định Công ty muốn thiết lập một hệ thống mạng trên AWS cho VietMove với các yêu cầu sau:
Trụ sở chính (Bình Thạnh – TP. HCM):
Nhân viên kỹ thuật và phòng ban có máy tính có thể truy cập Internet và hệ thống nội bộ để làm việc.
Một hệ thống server chạy nền tảng TMS phục vụ khách hàng doanh nghiệp (B2B SaaS) với yêu cầu độ sẵn sàng cao, đảm bảo theo dõi đơn hàng không gián đoạn.
Một hệ thống server lưu trữ dữ liệu vận đơn, lộ trình và lịch sử giao hàng của khách hàng.
Một hệ thống xác thực tập trung cho nhân viên nội bộ truy cập hệ thống, sử dụng IAM Identity Center (SSO) kết hợp Client VPN Endpoint để đảm bảo chỉ nhân viên được xác thực mới truy cập được hạ tầng nội bộ." .
Hỗ trợ VPN cho nhân viên kỹ thuật làm việc từ xa.
Một hệ thống giám sát tập trung theo dõi toàn bộ hạ tầng và cảnh báo khi có sự cố.
Chi nhánh Đà Nẵng & Hà Nội:
Điều phối viên chi nhánh sử dụng máy bàn để truy cập hệ thống TMS đặt tại trụ sở chính.
Một hệ thống xác thực tập trung cho nhân viên nội bộ truy cập hệ thống, sử dụng IAM Identity Center (SSO) kết hợp Client VPN Endpoint để đảm bảo chỉ nhân viên được xác thực mới truy cập được hạ tầng nội bộ.
Hỗ trợ VPN site-to-site để chi nhánh kết nối an toàn về trụ sở chính.
Một API endpoint riêng cho ứng dụng mobile của tài xế gọi về cập nhật trạng thái đơn hàng theo thời gian thực.
Yêu cầu chung:
Hệ thống DR (Disaster Recovery) đặt tại chi nhánh Hà Nội, đảm bảo dịch vụ không gián đoạn khi trụ sở chính gặp sự cố.
Hỗ trợ mở rộng thêm chi nhánh mới trong tương lai mà không cần thay đổi kiến trúc lõi.
