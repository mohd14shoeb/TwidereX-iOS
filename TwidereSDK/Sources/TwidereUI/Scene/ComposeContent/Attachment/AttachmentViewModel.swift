//
//  AttachmentViewModel.swift
//  
//
//  Created by MainasuK on 2021/11/19.
//

import os.log
import UIKit
import Combine
import PhotosUI
import TwidereCommon
import Kingfisher

final public class AttachmentViewModel: NSObject, ObservableObject, Identifiable {

    static let logger = Logger(subsystem: "AttachmentViewModel", category: "ViewModel")
    
    public let id = UUID()
    
    var disposeBag = Set<AnyCancellable>()
    var observations = Set<NSKeyValueObservation>()

    // input
    public let input: Input
    @Published var caption = ""
    @Published var sizeLimit = SizeLimit()
    
    // output
    @Published public private(set) var output: Output?
    @Published public private(set) var thumbnail: UIImage?      // original size image thumbnail
    @Published var error: Error?
    let progress = Progress()       // upload progress
    
    public init(input: Input) {
        self.input = input
        super.init()
        // end init
        
        defer {
            load(input: input)
        }
        
        $output
            .map { output -> UIImage? in
                switch output {
                case .image(let data, _):
                    return UIImage(data: data)
                case .video(let url, _):
                    return AttachmentViewModel.createThumbnailForVideo(url: url)
                case .none:
                    return nil
                }
            }
            .assign(to: &$thumbnail)
    }
    
    deinit {
        switch output {
        case .image:
            // FIXME:
            break
        case .video(let url, _):
            try? FileManager.default.removeItem(at: url)
        case nil :
            break
        }
    }
}

//extension AttachmentViewModel: Hashable {
//
//    public func hash(into hasher: inout Hasher) {
//        hasher.combine(id)
//        hasher.combine(input)
//    }
//
//    public static func == (lhs: AttachmentViewModel, rhs: AttachmentViewModel) -> Bool {
//        return lhs.input == rhs.input
//    }
//
//}

extension AttachmentViewModel {
    public enum Input: Hashable {
        case image(UIImage)
        case url(URL)
        case pickerResult(PHPickerResult)
    }
    
    public enum Output {
        case image(Data, imageKind: ImageKind)
        // case gif(Data)
        case video(URL, mimeType: String)    // assert use file for video only
        
        public enum ImageKind {
            case png
            case jpg
        }
        
        public var twitterMediaCategory: TwitterMediaCategory {
            switch self {
            case .image:        return .image
            case .video:        return .amplifyVideo
            }
        }
    }
        
    public struct SizeLimit {
        public let image: Int
        public let gif: Int
        public let video: Int
        
        public init(
            image: Int = 5 * 1024 * 1024,           // 5 MiB,
            gif: Int = 15 * 1024 * 1024,            // 15 MiB,
            video: Int = 512 * 1024 * 1024          // 512 MiB
        ) {
            self.image = image
            self.gif = gif
            self.video = video
        }
    }
    
    public enum AttachmentError: Error {
        case invalidAttachmentType
        case attachmentTooLarge
    }
    
    public enum TwitterMediaCategory: String {
        case image = "TWEET_IMAGE"
        case GIF = "TWEET_GIF"
        case video = "TWEET_VIDEO"
        case amplifyVideo = "AMPLIFY_VIDEO"
    }
}

extension AttachmentViewModel {
    
    private func load(input: Input) {
        switch input {
        case .image(let image):
            guard let data = image.pngData() else {
                error = AttachmentError.invalidAttachmentType
                return
            }
            output = .image(data, imageKind: .png)
        case .url(let url):
            Task { @MainActor in
                do {
                    let output = try await AttachmentViewModel.load(url: url)
                    self.output = output
                } catch {
                    self.error = error
                }
            }   // end Task
        case .pickerResult(let pickerResult):
            Task { @MainActor in
                do {
                    let output = try await AttachmentViewModel.load(pickerResult: pickerResult)
                    self.output = output
                } catch {
                    self.error = error
                }
            }   // end Task
        }
    }
    
    private static func load(url: URL) async throws -> Output {
        guard let uti = UTType(filenameExtension: url.pathExtension) else {
            throw AttachmentError.invalidAttachmentType
        }
        
        if uti.conforms(to: .image) {
            guard url.startAccessingSecurityScopedResource() else {
                throw AttachmentError.invalidAttachmentType
            }
            defer { url.stopAccessingSecurityScopedResource() }
            let imageData = try Data(contentsOf: url)
            return .image(imageData, imageKind: imageData.kf.imageFormat == .PNG ? .png : .jpg)
        } else if uti.conforms(to: .movie) {
            guard url.startAccessingSecurityScopedResource() else {
                throw AttachmentError.invalidAttachmentType
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            let fileName = UUID().uuidString
            let tempDirectoryURL = FileManager.default.temporaryDirectory
            let fileURL = tempDirectoryURL.appendingPathComponent(fileName).appendingPathExtension(url.pathExtension)
            try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            try FileManager.default.copyItem(at: url, to: fileURL)
            return .video(fileURL, mimeType: UTType.movie.preferredMIMEType ?? "video/mp4")
        } else {
            throw AttachmentError.invalidAttachmentType
        }
    }
    
    private static func load(pickerResult asset: PHPickerResult) async throws -> Output {
        if asset.isImage() {
            guard let result = try await asset.itemProvider.loadImageData() else {
                throw AttachmentError.invalidAttachmentType
            }
            let imageKind: Output.ImageKind = {
                if let type = result.type {
                    if type == UTType.png {
                        return .png
                    }
                    if type == UTType.jpeg {
                        return .jpg
                    }
                }
                
                let imageData = result.data

                if imageData.kf.imageFormat == .PNG {
                    return .png
                }
                if imageData.kf.imageFormat == .JPEG {
                    return .jpg
                }
                
                assertionFailure("unknown image kind")
                return .jpg
            }()
            return .image(result.data, imageKind: imageKind)
        } else if asset.isMovie() {
            guard let result = try await asset.itemProvider.loadVideoData() else {
                throw AttachmentError.invalidAttachmentType
            }
            return .video(result.url, mimeType: "video/mp4")
        } else {
            assertionFailure()
            throw AttachmentError.invalidAttachmentType
        }
    }

}

extension AttachmentViewModel {
    static func createThumbnailForVideo(url: URL) -> UIImage? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let asset = AVURLAsset(url: url)
        let assetImageGenerator = AVAssetImageGenerator(asset: asset)
        assetImageGenerator.appliesPreferredTrackTransform = true   // fix orientation
        do {
            let cgImage = try assetImageGenerator.copyCGImage(at: CMTimeMake(value: 0, timescale: 1), actualTime: nil)
            let image = UIImage(cgImage: cgImage)
            return image
        } catch {
            AttachmentViewModel.logger.log(level: .debug, "\((#file as NSString).lastPathComponent, privacy: .public)[\(#line, privacy: .public)], \(#function, privacy: .public): thumbnail generate fail: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - TypeIdentifiedItemProvider
extension AttachmentViewModel: TypeIdentifiedItemProvider {
    public static var typeIdentifier: String {
        return Bundle(for: AttachmentViewModel.self).bundleIdentifier! + String(describing: type(of: AttachmentViewModel.self))
    }
}

// MARK: - NSItemProviderWriting
extension AttachmentViewModel: NSItemProviderWriting {
    
    public static var writableTypeIdentifiersForItemProvider: [String] {
        return [
            AttachmentViewModel.typeIdentifier,
            UTType.image.identifier,
            UTType.movie.identifier
        ]
    }
    
    public var writableTypeIdentifiersForItemProvider: [String] {
        var typeIdentifiers: [String] = [AttachmentViewModel.typeIdentifier]
        
        switch input {
        case .image:
            typeIdentifiers.append(UTType.image.identifier)
        case .url(let url):
            let _uti = UTType(filenameExtension: url.pathExtension)
            if let uti = _uti {
                if uti.conforms(to: .image) {
                    typeIdentifiers.append(UTType.image.identifier)
                } else if uti.conforms(to: .movie) {
                    typeIdentifiers.append(UTType.image.identifier)
                    typeIdentifiers.append(UTType.movie.identifier)
                }
            }
        case .pickerResult(let item):
            if item.isImage() {
                typeIdentifiers.append(UTType.image.identifier)
            } else if item.isMovie() {
                typeIdentifiers.append(UTType.image.identifier)
                typeIdentifiers.append(UTType.movie.identifier)
            }
        }
        
        return typeIdentifiers
    }
    
    public func loadData(
        withTypeIdentifier typeIdentifier: String,
        forItemProviderCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void
    ) -> Progress? {
        switch typeIdentifier {
        case AttachmentViewModel.typeIdentifier:
            do {
                let archiver = NSKeyedArchiver(requiringSecureCoding: false)
                try archiver.encodeEncodable(id, forKey: NSKeyedArchiveRootObjectKey)
                archiver.finishEncoding()
                let data = archiver.encodedData
                completionHandler(data, nil)
            } catch {
                assertionFailure()
                completionHandler(nil, nil)
            }
        default:
            break
        }
        
        let loadingProgress = Progress(totalUnitCount: 100)
        
        Publishers.CombineLatest(
            $output,
            $error
        )
        .sink { [weak self] output, error in
            guard let self = self else { return }
            
            // continue when load completed
            guard output != nil || error != nil else { return }
            
            switch output {
            case .image(let data, _):
                switch typeIdentifier {
                case UTType.image.identifier:
                    loadingProgress.completedUnitCount = 100
                    completionHandler(data, nil)
                default:
                    completionHandler(nil, nil)
                }
            case .video(let url, _):
                switch typeIdentifier {
                case UTType.image.identifier:
                    let _image = AttachmentViewModel.createThumbnailForVideo(url: url)
                    let _data = _image?.pngData()
                    loadingProgress.completedUnitCount = 100
                    completionHandler(_data, nil)
                case UTType.movie.identifier:
                    let task = URLSession.shared.dataTask(with: url) { data, response, error in
                        completionHandler(data, error)
                    }
                    task.progress.observe(\.fractionCompleted) { progress, change in
                        loadingProgress.completedUnitCount = Int64(100 * progress.fractionCompleted)
                    }
                    .store(in: &self.observations)
                    task.resume()
                default:
                    completionHandler(nil, nil)
                }
            case nil:
                completionHandler(nil, error)
            }
        }
        .store(in: &disposeBag)
        
        return loadingProgress
    }
    
}

extension PHPickerResult {
    fileprivate func isImage() -> Bool {
        return itemProvider.hasRepresentationConforming(
            toTypeIdentifier: UTType.image.identifier,
            fileOptions: []
        )
    }
    
    fileprivate func isMovie() -> Bool {
        return itemProvider.hasRepresentationConforming(
            toTypeIdentifier: UTType.movie.identifier,
            fileOptions: []
        )
    }
}
