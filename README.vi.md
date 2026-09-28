# EPUB Quick Look

[English](README.md)

EPUB Quick Look bổ sung bản xem nhanh `.epub` trong Finder. Chọn sách và nhấn **Space** để xem tiêu đề, tác giả, nội dung chương và hình ảnh. Ứng dụng cũng có cửa sổ đọc EPUB đơn giản. Dự án dùng Swift, AppKit và Quick Look preview extension của Apple, không cần thư viện ngoài.

## Tương thích

- Đã thử trên Mac Apple Silicon chạy macOS 27 và Xcode 27.
- Dự án đặt phiên bản macOS tối thiểu là 15.0; các phiên bản cũ hơn chưa được thử.
- Hỗ trợ EPUB không mã hóa. Không hỗ trợ sách có DRM.

## Cài đặt từ bản phát hành

Tải `EPUB-Quick-Look-macOS.dmg` hoặc `EPUB-Quick-Look-macOS.zip` tại [GitHub Releases](https://github.com/thangnt/epub-quicklook-macos/releases/latest). Hai gói chứa cùng một ứng dụng.

**DMG:** Mở ảnh đĩa, kéo `EPUB Quick Look.app` vào lối tắt **Applications**, rồi tháo ảnh đĩa.

**ZIP:** Giải nén và chép `EPUB Quick Look.app` vào `/Applications`.

Mở ứng dụng một lần từ Applications để macOS đăng ký Quick Look extension. Sau đó chọn tệp `.epub` trong Finder và nhấn **Space**. Không cần giữ ứng dụng chạy.

Bản phát hành được ký ad hoc và **chưa được Apple notarize**. Trên Mac khác, macOS có thể chặn lần mở đầu tiên. Nếu tin cậy bản phát hành này, hãy thử mở ứng dụng, sau đó vào **System Settings → Privacy & Security → Open Anyway** và làm theo hướng dẫn. Xem [hướng dẫn của Apple](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac). Không cần tắt Gatekeeper cho toàn hệ thống.

## Sử dụng

- **Xem nhanh trong Finder:** Chọn một tệp `.epub`, nhấn **Space**. Nhấn Space hoặc Escape để đóng.
- **Cửa sổ đọc:** Mở `EPUB Quick Look.app`, chọn **Mở EPUB…**. Bạn cũng có thể dùng **Open With → EPUB Quick Look** trong Finder.

## Khi Finder chỉ hiện biểu tượng EPUB

1. Kiểm tra ứng dụng đã nằm trong `/Applications`, rồi mở một lần.
2. Vào **System Settings → General → Login Items & Extensions → Quick Look** và bật **EPUBPreview**. [Apple mô tả cài đặt này tại đây](https://support.apple.com/guide/mac-help/change-login-items-extensions-settings-mtusr003/mac).
3. Nếu đã cài extension khác cho EPUB, thử tắt extension đó và xem lại.
4. Chạy `qlmanage -r` trong Terminal để làm mới Quick Look, rồi thử lại trong Finder.

## Biên dịch từ mã nguồn

Dùng Xcode 27 trên Mac có macOS SDK. Mở `EPUBQuickLook.xcodeproj` và biên dịch scheme **EPUBQuickLook**, hoặc chạy:

```sh
xcodebuild -project EPUBQuickLook.xcodeproj \
  -scheme EPUBQuickLook -configuration Release \
  -derivedDataPath build CODE_SIGN_IDENTITY=- build
```

Ứng dụng được tạo ở `build/Build/Products/Release/EPUB Quick Look.app`. Tệp cấu hình dự án là `project.yml`; nếu sửa tệp này, chạy `xcodegen generate` để tạo lại dự án Xcode.

## Giới hạn và quyền riêng tư

- Để Finder phản hồi nhanh, bản xem trước giới hạn 30 chương đầu, 2 MB mã HTML và 25 MB hình ảnh.
- Hỗ trợ ảnh PNG, JPEG, GIF và WebP. Không hiển thị CSS phức tạp, SVG, âm thanh, video hay script của sách. XHTML sai cú pháp được chuyển thành văn bản giản lược.
- Quá trình xử lý diễn ra trên Mac. Ứng dụng và extension không yêu cầu quyền truy cập mạng.

Để gỡ cài đặt, xóa `EPUB Quick Look.app` khỏi Applications. Nếu Finder vẫn giữ bản xem cũ, chạy `qlmanage -r`.
