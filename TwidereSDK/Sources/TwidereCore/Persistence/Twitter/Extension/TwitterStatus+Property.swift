//
//  TwitterStatus+Property.swift
//  TwitterStatus
//
//  Created by Cirno MainasuK on 2021-8-19.
//  Copyright © 2021 Twidere. All rights reserved.
//

import Foundation
import CoreData
import CoreDataStack
import CoreGraphics
import TwitterSDK
import Fuzi

// MARK: - V1

extension TwitterStatus.Property {
    public init(entity: Twitter.Entity.Tweet, networkDate: Date) {
        self.init(
            id: entity.idStr,
            text: entity.fullText ?? entity.text ?? "",
            likeCount: entity.favoriteCount.flatMap(Int64.init) ?? 0,
            replyCount: 0,
            repostCount: entity.retweetCount.flatMap(Int64.init) ?? 0,
            quoteCount: 0,
            language: entity.lang,
            source: entity.source.flatMap { source in
                do {
                    let document = try HTMLDocument(string: source)
                    let content = document.body?.stringValue
                    return content
                } catch {
                    assertionFailure(error.localizedDescription)
                    return nil
                }
            },
            replyToStatusID: entity.inReplyToStatusIDStr,
            replyToUserID: entity.inReplyToUserIDStr,
            createdAt: entity.createdAt,
            updatedAt: networkDate
        )
    }
}

extension Twitter.Entity.Tweet {
    public var twitterAttachments: [TwitterAttachment]? {
        guard let extendedEntities = self.extendedEntities,
              let media = extendedEntities.media
        else { return nil }
        
        let attachments = media.compactMap { media -> TwitterAttachment? in
            guard let kind = media.attachmentKind,
                  let size = media.sizes?.size(kind: .large),
                  let width = size.w,
                  let height = size.h
            else { return nil }
            return TwitterAttachment(
                kind: kind,
                size: CGSize(width: width, height: height),
                assetURL: media.attachmentAssetURL,
                previewURL: media.attachmentPreviewURL,
                durationMS: media.videoInfo?.durationMillis,
                altDescription: media.extAltText
            )
        }
        
        return attachments
    }
    
    public var twitterLocation: TwitterLocation? {
        guard let place = self.place,
              let fullName = place.fullName
        else { return nil }
        
        return TwitterLocation(
            id: place.id,
            fullName: fullName,
            name: place.name,
            country: place.country,
            countryCode: place.countryCode
        )
    }
}

extension Twitter.Entity.ExtendedEntities.Media {
    public var attachmentKind: TwitterAttachment.Kind? {
        guard let type = self.type else { return nil }
        switch type {
        case "photo":           return .photo
        case "video":           return .video
        case "animated_gif":    return .animatedGIF
        default:                return nil
        }
    }
    
    public var attachmentAssetURL: String? {
        guard let kind = attachmentKind else { return nil }
        switch kind {
        case .photo:        return mediaURLHTTPS
        case .video:        return videoInfo?.variants?.max(by: { ($0.bitrate ?? 0) < ($1.bitrate ?? 0) })?.url
        case .animatedGIF:  return videoInfo?.variants?.max(by: { ($0.bitrate ?? 0) < ($1.bitrate ?? 0) })?.url
        }
    }
    
    public var attachmentPreviewURL: String? {
        guard let kind = attachmentKind else { return nil }
        switch kind {
        case .photo:            return nil
        case .video:            return mediaURLHTTPS
        case .animatedGIF:      return mediaURLHTTPS
        }
    }
}


// MARK: - V2

extension TwitterStatus.Property {
    public init(
        status: Twitter.Entity.V2.Tweet,
        author: Twitter.Entity.V2.User,
        place: Twitter.Entity.V2.Place?,
        media: [Twitter.Entity.V2.Media],
        networkDate: Date
    ) {
        self.init(
            id: status.id,
            text: status.text,
            likeCount: status.publicMetrics.flatMap { Int64($0.likeCount) } ?? 0,
            replyCount: status.publicMetrics.flatMap { Int64($0.replyCount) } ?? 0,
            repostCount: status.publicMetrics.flatMap { Int64($0.retweetCount) } ?? 0,
            quoteCount: status.publicMetrics.flatMap { Int64($0.quoteCount) } ?? 0,
            language: status.lang,
            source: status.source,
            replyToStatusID: status.repliedToID,
            replyToUserID: status.inReplyToUserID,
            createdAt: status.createdAt,
            updatedAt: networkDate
        )
    }
}

extension Twitter.Entity.V2.Tweet {
    public var repliedToID: Twitter.Entity.V2.Tweet.ID? {
        for referencedTweet in referencedTweets ?? [] {
            switch referencedTweet.type {
            case .repliedTo:
                return referencedTweet.id
            case .quoted:
                continue
            case .retweeted:
                continue
            case .none:
                continue
            }
        }
        return nil
    }
    
    public var quoteID: Twitter.Entity.V2.Tweet.ID? {
        for referencedTweet in referencedTweets ?? [] {
            switch referencedTweet.type {
            case .repliedTo:
                continue
            case .quoted:
                return referencedTweet.id
            case .retweeted:
                continue
            case .none:
                continue
            }
        }
        return nil
    }
    
    public var repostID: Twitter.Entity.V2.Tweet.ID? {
        for referencedTweet in referencedTweets ?? [] {
            switch referencedTweet.type {
            case .repliedTo:
                continue
            case .quoted:
                continue
            case .retweeted:
                return referencedTweet.id
            case .none:
                continue
            }
        }
        return nil
    }
}

extension Twitter.Entity.V2.Media {
    public var twitterAttachment: TwitterAttachment? {
        guard let kind = attachmentKind else { return nil }
        guard let width = width,
            let height = height
        else { return nil }
        return TwitterAttachment(
            kind: kind,
            size: CGSize(width: width, height: height),
            assetURL: url,
            previewURL: previewImageURL,
            durationMS: durationMS,
            altDescription: nil
        )
    }
    
    public var attachmentKind: TwitterAttachment.Kind? {
        switch type {
        case "photo":           return .photo
        case "video":           return .video
        case "animated_gif":    return .animatedGIF
        default:                return nil
        }
    }
}

extension Twitter.Entity.V2.Place {
    public var twitterLocation: TwitterLocation {
        return TwitterLocation(
            id: id,
            fullName: fullName,
            name: name,
            country: country,
            countryCode: countryCode
        )
    }
}
