import Foundation
import QuickLookUI
import UniformTypeIdentifiers

final class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    func providePreview(for request: QLFilePreviewRequest,
                                 completionHandler: @escaping (QLPreviewReply?, Error?) -> Void) {
        let fileURL = request.fileURL
        let reply = QLPreviewReply(dataOfContentType: .html,
                                   contentSize: CGSize(width: 820, height: 720)) { response in
            let preview = try EPUBRenderer.render(url: fileURL)
            response.title = preview.title
            for image in preview.images {
                response.attachments[image.id] = QLPreviewReplyAttachment(
                    data: image.data, contentType: image.type)
            }
            return Data(preview.html.utf8)
        }
        completionHandler(reply, nil)
    }
}
