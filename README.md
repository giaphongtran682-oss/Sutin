# Ông Già Noel 2026 — bản nâng cấp

## Thành phần
- `index.html`: trang khách đặt lịch, chọn quà, tra cứu trạng thái đơn; màn mở cửa Noel có hiệu ứng hai cánh cửa và ông già Noel cùng tuần lộc chạy ngang qua; có nhạc chuông Noel nguyên bản, nút bật/tắt và thanh âm lượng.
- `admin.html`: trang quản trị, quản lý quà/ảnh, dịch vụ, nhân viên, hotline/Zalo, trạng thái liên hệ khách hàng, khung giờ vàng, trạng thái đơn và xuất Excel.
- `supabase/nang-cap-2026.sql`: migration bổ sung schema, RPC, trigger tính phụ thu và Storage policies. Migration này đã được áp dụng vào Supabase project hiện tại.

## Cấu hình hiện tại
- Supabase URL: `https://yvqoypzlafrscuxkesao.supabase.co`
- Frontend dùng publishable key. Không đưa `service_role` key vào website.
- Bucket ảnh quà: `gifts` (public read, admin-only upload/update/delete; giới hạn 5 MB, JPEG/PNG/WebP).
- Mã đơn: `NOEL-` + 8 ký tự đầu của UUID đơn. Khách tra cứu bằng mã đơn và đúng số điện thoại đã đặt.
- Khung giờ vàng: mặc định đang tắt; admin có thể bật, đặt giờ và phụ thu. Database tự tính lại phụ thu theo múi giờ Asia/Ho_Chi_Minh.
- Liên hệ khách hàng: admin cấu hình hotline và link Zalo OA/chat; trang khách có nút gọi/nhắn Zalo. Trong từng đơn, admin có nút gọi trực tiếp hoặc mở Zalo của khách và lưu trạng thái chưa liên hệ/đã gọi/đã nhắn. Zalo chỉ mở cuộc trò chuyện, chưa tự gửi tin nhắn qua Zalo API.

## Cách dùng
1. Đưa `index.html` và `admin.html` lên cùng thư mục hosting HTTPS (ví dụ GitHub Pages/Netlify).
2. Mở `admin.html`, đăng nhập bằng tài khoản Supabase đã có quyền `admin`.
3. Trong Quản lý quà tặng, thêm quà và chọn ảnh; trong phần cấu hình, nhập hotline, link Zalo OA/chat và thiết lập giờ/phụ thu.
4. Khách đặt lịch sẽ nhận mã đơn, dùng mã + số điện thoại ở mục Tra cứu đơn để xem trạng thái.
5. Trước khi xóa đơn, hãy xuất Excel. File Excel có 2 sheet: `Don hang` và `Chi tiet qua`.

## Lưu ý
- Xóa đơn là thao tác xóa vĩnh viễn; chi tiết quà trong đơn bị xóa theo. Nên xuất Excel trước.
- Nhân viên đã được gán vào đơn cũ sẽ được tạm khóa thay vì xóa vật lý để bảo toàn lịch sử phân công.
- Xóa/ẩn quà không xóa dòng chi tiết quà trong đơn cũ.
- Zalo không tự gửi thông báo nếu chưa có Zalo OA API và thông tin xác thực hợp lệ.
- Quầy quà cập nhật trực tiếp khi quản trị thêm, sửa, ẩn/xóa quà; có tải lại dự phòng khi khách quay lại trang. Bảng `gifts` đã được thêm vào publication `supabase_realtime`.
- Trong trang quản trị, có thể ẩn/hiện món quà hoặc xóa vĩnh viễn. Xóa vĩnh viễn sẽ đặt `order_gifts.gift_id` thành NULL để giữ tên quà và giá đã chốt trong đơn cũ.
- Hiệu ứng mở cửa phát hoạt cảnh ông già Noel và xe tuần lộc chạy ngang; người dùng có thể bỏ qua hoặc giảm chuyển động theo cài đặt thiết bị.
- Nhạc Noel là giai điệu chuông nguyên bản được tổng hợp ngay trong trình duyệt bằng Web Audio; khách có thể bật/tắt và chỉnh âm lượng. Trình duyệt di động yêu cầu thao tác chạm trước khi phát âm thanh.
- Website cần được host qua HTTPS để đăng nhập, upload ảnh và các API trình duyệt hoạt động ổn định.


### Cập nhật giao diện
- Nhạc Noel được phối lại theo giai điệu chuông nhẹ, có hòa âm nền và nhịp chậm hơn.
- Ảnh quà ở quầy, cửa sổ xem chi tiết và ảnh thu nhỏ trong trang quản trị dùng chế độ hiển thị toàn ảnh (`contain`), không cắt mất phần ảnh.


### Cập nhật quản lý quà tặng (16/11/2026)
- Mỗi món quà hiện có ô chọn ảnh riêng; chọn ảnh mới rồi nhấn **Lưu thông tin + ảnh** để thay ảnh.
- Có thể sửa tên, giá, mô tả và số lượng tồn ngay trên từng món quà.
- Ảnh được tự thu nhỏ/tối ưu về JPEG trước khi tải lên Storage; hỗ trợ chọn ảnh từ thư viện iPhone nếu trình duyệt đọc được định dạng ảnh.
- Có nút **Xóa vĩnh viễn**. Dữ liệu lịch sử đơn cũ vẫn giữ `gift_name` và `unit_price`; chỉ liên kết tới món quà bị đặt NULL. Ảnh cũ trong bucket cũng được dọn nếu là ảnh thuộc bucket `gifts`.
- Storage policies đã được kiểm tra: chỉ admin được upload, cập nhật và xóa ảnh; khách chỉ đọc ảnh công khai.


## Cập nhật 16/11/2026 – Nhạc và quyền nhân viên
- Nhạc Noel được phối lại theo giai điệu Jingle Bells (tác phẩm public domain), với lớp chuông và piano/bass tổng hợp; bảng điều khiển được thu gọn thành nút nhỏ ở góc màn hình.
- Trang quản trị có đăng nhập riêng cho nhân viên bằng mã do Admin cấp (8–32 ký tự chữ/số/_/-).
- Nhân viên chỉ xem các đơn chưa có người nhận hoặc đơn do chính mình nhận; có thể nhận đơn chưa phân công. Cơ sở dữ liệu xử lý nhận đơn nguyên tử để tránh hai người nhận cùng một đơn.
- Mã nhân viên được lưu dạng bcrypt hash; mỗi lần đổi mã, mọi phiên cũ của nhân viên đó bị thu hồi. Phiên có thời hạn 12 giờ; khóa nhân viên cũng thu hồi phiên.
- Migration `supabase/nang-cap-phan-quyen-nhan-vien.sql` đã được áp dụng trực tiếp trên Supabase project hiện tại. Khi thay file trên hosting, không cần chạy lại migration.
