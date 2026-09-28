# EPUB Quick Look

Ứng dụng macOS cho Apple Silicon, gồm trình đọc EPUB đơn giản và Quick Look extension để xem nội dung `.epub` ngay trong Finder bằng phím Space. Dự án dùng Swift, AppKit và API Quick Look của Apple; không cần tải thư viện ngoài.

## Cài đặt

Tải `EPUB-Quick-Look-macOS.zip` từ [trang Releases](https://github.com/thangnt/epub-quicklook-macos/releases/latest), giải nén, chép `EPUB Quick Look.app` vào `/Applications` và mở ứng dụng một lần. Sau đó chọn tệp `.epub` trong Finder và nhấn **Space**.

## Biên dịch

Yêu cầu Xcode 27 và `xcodegen`.

```sh
cd epub-quicklook
xcodegen generate
xcodebuild -project EPUBQuickLook.xcodeproj -scheme EPUBQuickLook -configuration Release -derivedDataPath build CODE_SIGN_IDENTITY=- build
```

Ứng dụng được tạo tại `build/Build/Products/Release/EPUB Quick Look.app`. Nếu có nhiều extension cùng xử lý EPUB, vào **System Settings → General → Login Items & Extensions → Quick Look** để bật EPUBPreview. Có thể dùng `qlmanage -r` để xóa cache Quick Look sau khi cập nhật ứng dụng.

## Giới hạn

- Bản xem nhanh hiển thị tối đa 30 chương đầu, 2 MB nội dung HTML và 25 MB hình ảnh để Finder phản hồi nhanh.
- Chỉ hỗ trợ EPUB không mã hóa/DRM; hình PNG, JPEG, GIF và WebP. Bố cục CSS phức tạp, SVG, video, âm thanh và JavaScript của sách không được trình bày.
- Nội dung XHTML được lọc trước khi đưa vào HTML preview. Sách có XHTML lỗi cú pháp được chuyển sang văn bản giản lược.
- Bản phát hành được ký ad hoc, chưa được Apple notarize; khi chuyển sang Mac khác, macOS có thể yêu cầu xác nhận trước khi mở.
