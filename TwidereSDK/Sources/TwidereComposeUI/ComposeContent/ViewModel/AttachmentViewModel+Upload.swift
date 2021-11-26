//
//  AttachmentViewModel+Upload.swift
//  
//
//  Created by MainasuK on 2021-11-26.
//

import os.log
import UIKit
import Kingfisher
import UniformTypeIdentifiers
import TwidereCore
import TwitterSDK

extension Data {
    fileprivate func chunks(size: Int) -> [Data] {
        return stride(from: 0, to: count, by: size).map {
            Data(self[$0..<Swift.min(count, $0 + size)])
        }
    }
}

extension AttachmentViewModel.Output {
    var maxPayloadSizeInBytes: Int {
        switch self {
        case .image:        return 5 * 1024 * 1024      // 5 MiB
//            case .gif:          return 15 * 1024 * 1024     // 15 MiB
//            case .video:        return 15 * 1024 * 1024     // 15 MiB
        }
    }
    
    struct SliceResult {
        let chunks: [Data]
        let type: UTType
        
        let totalBytes: Int
        
        public init(chunks: [Data], type: UTType) {
            self.chunks = chunks
            self.type = type
            self.totalBytes = chunks.reduce(0, { result, next in return result + next.count })
        }
        
    }
    
    func slice() -> SliceResult? {
        // needs execute in background
        assert(!Thread.isMainThread)
        
        // try png then use JPEG compress with Q=0.8
        // then slice into 1MiB chunks
        switch self {
        case .image(let data):
            // use processed imageData to remove EXIF
            guard let image = UIImage(data: data),
                  var imageData = image.pngData()
            else { return nil }
            
            var didRemoveEXIF = false
            repeat {
                guard let image = KFCrossPlatformImage(data: imageData) else { return nil }
                if imageData.kf.imageFormat == .PNG {
                    // A. png image
                    guard let pngData = image.pngData() else { return nil }
                    didRemoveEXIF = true
                    if pngData.count > maxPayloadSizeInBytes {
                        guard let compressedJpegData = image.jpegData(compressionQuality: 0.8) else { return nil }
                        os_log("%{public}s[%{public}ld], %{public}s: compress png %.2fMiB -> jpeg %.2fMiB", ((#file as NSString).lastPathComponent), #line, #function, Double(imageData.count) / 1024 / 1024, Double(compressedJpegData.count) / 1024 / 1024)
                        imageData = compressedJpegData
                    } else {
                        os_log("%{public}s[%{public}ld], %{public}s: png %.2fMiB", ((#file as NSString).lastPathComponent), #line, #function, Double(pngData.count) / 1024 / 1024)
                        imageData = pngData
                    }
                } else {
                    // B. other image
                    if !didRemoveEXIF {
                        guard let jpegData = image.jpegData(compressionQuality: 0.8) else { return nil }
                        os_log("%{public}s[%{public}ld], %{public}s: compress jpeg %.2fMiB -> jpeg %.2fMiB", ((#file as NSString).lastPathComponent), #line, #function, Double(imageData.count) / 1024 / 1024, Double(jpegData.count) / 1024 / 1024)
                        imageData = jpegData
                        didRemoveEXIF = true
                    } else {
                        let targetSize = CGSize(width: image.size.width * 0.8, height: image.size.height * 0.8)
                        let scaledImage = image.af.imageScaled(to: targetSize)
                        guard let compressedJpegData = scaledImage.jpegData(compressionQuality: 0.8) else { return nil }
                        os_log("%{public}s[%{public}ld], %{public}s: compress jpeg %.2fMiB -> jpeg %.2fMiB", ((#file as NSString).lastPathComponent), #line, #function, Double(imageData.count) / 1024 / 1024, Double(compressedJpegData.count) / 1024 / 1024)
                        imageData = compressedJpegData
                    }
                }
            } while (imageData.count > maxPayloadSizeInBytes)
            
            let chunks = imageData.chunks(size: 1 * 1024 * 1024)      // 1 MiB chunks
            os_log("%{public}s[%{public}ld], %{public}s: split to %ld chunks", ((#file as NSString).lastPathComponent), #line, #function, chunks.count)

            return SliceResult(
                chunks: chunks,
                type: imageData.kf.imageFormat == .PNG ? UTType.png : UTType.jpeg
            )
//        case .gif(let url):
//            fatalError()
//        case .video(let url):
//            fatalError()
        }
    }
}

extension AttachmentViewModel {
    struct UploadContext {
        let apiService: APIService
        let authenticationContext: TwitterAuthenticationContext
    }
}

extension AttachmentViewModel {
    func upload(
        context: UploadContext
    ) async throws -> Twitter.API.Media.InitResponse {
        guard let output = self.output,
              let sliceResult = output.slice() else {
            throw AppError.implicit(.badRequest)
        }
        
        // init + N * append + finalize
        progress.totalUnitCount = 1 + Int64(sliceResult.chunks.count) + 1
        progress.completedUnitCount = 0
        
        // init
        let mediaInitResponse = try await context.apiService.mediaInit(
            totalBytes: sliceResult.totalBytes,
            mediaType: sliceResult.type.preferredMIMEType ?? "",
            twitterAuthenticationContext: context.authenticationContext
        )
        AttachmentViewModel.logger.log(level: .debug, "\((#file as NSString).lastPathComponent, privacy: .public)[\(#line, privacy: .public)], \(#function, privacy: .public): init media success: \(mediaInitResponse.value.mediaIDString)")
        let mediaID = mediaInitResponse.value.mediaIDString
        progress.completedUnitCount += 1
        
        // append
        let chunkCount = sliceResult.chunks.count
        for (i, chunk) in sliceResult.chunks.enumerated() {
            _ = try await context.apiService.mediaAppend(
                mediaID: mediaID,
                chunk: chunk,
                index: i,
                twitterAuthenticationContext: context.authenticationContext
            )
            AttachmentViewModel.logger.log(level: .debug, "\((#file as NSString).lastPathComponent, privacy: .public)[\(#line, privacy: .public)], \(#function, privacy: .public): append chunk \(i)/\(chunkCount) success")
            progress.completedUnitCount += 1
        }
        
        var isFinalized = false
        repeat {
            let mediaFinalizedResponse = try await context.apiService.mediaFinalize(
                mediaID: mediaID,
                twitterAuthenticationContext: context.authenticationContext
            )
            if let info = mediaFinalizedResponse.value.processingInfo {
                assert(!Thread.isMainThread)
                let checkAfterSeconds = UInt64(info.checkAfterSecs)
                AttachmentViewModel.logger.log(level: .debug, "\((#file as NSString).lastPathComponent, privacy: .public)[\(#line, privacy: .public)], \(#function, privacy: .public): finalize status pending. check after \(info.checkAfterSecs)s")
                await Task.sleep(1_000_000_000 * checkAfterSeconds)     // 1s * checkAfterSeconds
                continue
            
            } else {
                AttachmentViewModel.logger.log(level: .debug, "\((#file as NSString).lastPathComponent, privacy: .public)[\(#line, privacy: .public)], \(#function, privacy: .public): finalize success")
                isFinalized = true
            }
        } while !isFinalized
        progress.completedUnitCount += 1
        
        return mediaInitResponse.value
    }
    
}
