//
//  StatusView+ViewModel.swift
//  StatusView+ViewModel
//
//  Created by Cirno MainasuK on 2021-8-27.
//  Copyright © 2021 Twidere. All rights reserved.
//

import os.log
import UIKit
import Combine
import SwiftUI
import CoreData
import CoreDataStack
import TwidereCommon
import TwidereCore
import TwitterMeta
import MastodonMeta
import Meta

extension StatusView {
    public final class ViewModel: ObservableObject {
        var disposeBag = Set<AnyCancellable>()
        var observations = Set<NSKeyValueObservation>()
        var objects = Set<NSManagedObject>()
        
        @Published public var platform: Platform = .none
        
        @Published public var header: Header = .none
        
        @Published public var authorAvatarImageURL: URL?
        @Published public var authorName: MetaContent?
        @Published public var authorUsername: String?
        
        @Published public var protected: Bool = false
        
        @Published public var content: MetaContent?
        @Published public var mediaViewConfigurations: [MediaView.Configuration] = []
        
        @Published public var pollItems: [PollItem] = []
        @Published public var isVotable: Bool = false
        
        @Published public var location: String?
        
        @Published public var isRepost: Bool = false
        @Published public var isLike: Bool = false
        
        @Published public var replyCount: Int = 0
        @Published public var repostCount: Int = 0
        @Published public var quoteCount: Int = 0
        @Published public var likeCount: Int = 0
        
        @Published public var visibility: StatusVisibility?
        
        @Published public var dateTimeProvider: DateTimeProvider?
        @Published public var timestamp: Date?
        
        @Published public var sharePlaintextContent: String?
        @Published public var shareStatusURL: String?
        
       public enum Header {
            case none
            case repost(info: RepostInfo)
            case notification(info: NotificationHeaderInfo)
            // TODO: replyTo
            
            public struct RepostInfo {
                public let authorNameMetaContent: MetaContent
            }
       }
    }
}

extension StatusView.ViewModel {
    func bind(statusView: StatusView) {
        bindHeader(statusView: statusView)
        bindAuthor(statusView: statusView)
        bindContent(statusView: statusView)
        bindMedia(statusView: statusView)
        bindPoll(statusView: statusView)
        bindLocation(statusView: statusView)
        bindToolbar(statusView: statusView)
    }
    
    private func bindHeader(statusView: StatusView) {
        $header
            .sink { header in
                switch header {
                case .none:
                    return
                case .repost(let info):
                    statusView.headerIconImageView.image = Asset.Media.repeat.image
                    statusView.headerIconImageView.tintColor = Asset.Colors.Theme.daylight.color
                    statusView.headerTextLabel.setupAttributes(style: StatusView.headerTextLabelStyle)
                    statusView.headerTextLabel.configure(content: info.authorNameMetaContent)
                    statusView.setHeaderDisplay()
                case .notification(let info):
                    statusView.headerIconImageView.image = info.iconImage
                    statusView.headerIconImageView.tintColor = info.iconImageTintColor
                    statusView.headerTextLabel.setupAttributes(style: StatusView.headerTextLabelStyle)
                    statusView.headerTextLabel.configure(content: info.textMetaContent)
                    statusView.setHeaderDisplay()
                }
            }
            .store(in: &disposeBag)
    }
    
    private func bindAuthor(statusView: StatusView) {
        // avatar
        $authorAvatarImageURL
            .sink { url in
                let configuration = AvatarImageView.Configuration(url: url)
                statusView.authorAvatarButton.avatarImageView.configure(configuration: configuration)
            }
            .store(in: &disposeBag)
        UserDefaults.shared
            .observe(\.avatarStyle, options: [.initial, .new]) { defaults, _ in
                let avatarStyle = defaults.avatarStyle
                let animator = UIViewPropertyAnimator(duration: 0.3, timingParameters: UISpringTimingParameters())
                animator.addAnimations { [weak statusView] in
                    guard let statusView = statusView else { return }
                    switch avatarStyle {
                    case .circle:
                        statusView.authorAvatarButton.avatarImageView.configure(cornerConfiguration: .init(corner: .circle))
                    case .roundedSquare:
                        statusView.authorAvatarButton.avatarImageView.configure(cornerConfiguration: .init(corner: .scale(ratio: 4)))
                    }
                }
                animator.startAnimation()
            }
            .store(in: &observations)
        // lock
        $protected
            .sink { protected in
                statusView.lockImageView.isHidden = !protected
            }
            .store(in: &disposeBag)
        // name
        $authorName
            .sink { metaContent in
                let metaContent = metaContent ?? PlaintextMetaContent(string: "")
                statusView.authorNameLabel.setupAttributes(style: StatusView.authorNameLabelStyle)
                statusView.authorNameLabel.configure(content: metaContent)
            }
            .store(in: &disposeBag)
        // username
        $authorUsername
            .map { text in
                guard let text = text else { return "" }
                return "@\(text)"
            }
            .assign(to: \.text, on: statusView.authorUsernameLabel)
            .store(in: &disposeBag)
        // visibility
        $visibility
            .sink { visibility in
                guard let visibility = visibility,
                      let image = visibility.inlineImage
                else { return }
                
                statusView.visibilityImageView.image = image
                statusView.setVisibilityDisplay()
            }
            .store(in: &disposeBag)
        // timestamp
        Publishers.CombineLatest(
            $timestamp,
            $dateTimeProvider
        )
        .sink { timestamp, dateTimeProvider in
            statusView.timestampLabel.text = dateTimeProvider?.shortTimeAgoSinceNow(to: timestamp)
            statusView.metricsDashboardView.timestampLabel.text = {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .medium
                let text = timestamp.flatMap { formatter.string(from: $0) }
                return text
            }()
        }
        .store(in: &disposeBag)
        // dashboard
        Publishers.CombineLatest4(
            $replyCount,
            $repostCount,
            $quoteCount,
            $likeCount
        )
        .sink { replyCount, repostCount, quoteCount, likeCount in
            switch statusView.style {
            case .plain:
                statusView.setMetricsDisplay()

                statusView.metricsDashboardView.setupReply(count: replyCount)
                statusView.metricsDashboardView.setupRepost(count: repostCount)
                statusView.metricsDashboardView.setupQuote(count: quoteCount)
                statusView.metricsDashboardView.setupLike(count: likeCount)
                
                let needsDashboardDisplay = replyCount > 0 || repostCount > 0 || quoteCount > 0 || likeCount > 0
                statusView.metricsDashboardView.dashboardContainer.isHidden = !needsDashboardDisplay
            default:
                break
            }
        }
        .store(in: &disposeBag)
    }
    
    private func bindContent(statusView: StatusView) {
        $content
            .sink { metaContent in
                guard let content = metaContent else {
                    statusView.contentTextView.reset()
                    return
                }
                statusView.contentTextView.configure(content: content)
            }
            .store(in: &disposeBag)
    }
    
    private func bindMedia(statusView: StatusView) {
        $mediaViewConfigurations
            .sink { configurations in
                let maxSize = CGSize(
                    width: statusView.contentMaxLayoutWidth,
                    height: statusView.contentMaxLayoutWidth
                )
                var needsDisplay = true
                switch configurations.count {
                case 0:
                    needsDisplay = false
                case 1:
                    let configuration = configurations[0]
                    let adaptiveLayout = MediaGridContainerView.AdaptiveLayout(
                        aspectRatio: configuration.aspectRadio,
                        maxSize: maxSize
                    )
                    let mediaView = statusView.mediaGridContainerView.dequeueMediaView(adaptiveLayout: adaptiveLayout)
                    mediaView.setup(configuration: configuration)
                default:
                    let gridLayout = MediaGridContainerView.GridLayout(
                        count: configurations.count,
                        maxSize: maxSize
                    )
                    let mediaViews = statusView.mediaGridContainerView.dequeueMediaView(gridLayout: gridLayout)
                    for (i, (configuration, mediaView)) in zip(configurations, mediaViews).enumerated() {
                        guard i < MediaGridContainerView.maxCount else { break }
                        mediaView.setup(configuration: configuration)
                    }
                }
                if needsDisplay {
                    statusView.setMediaDisplay()
                }
            }
            .store(in: &disposeBag)
    }
    
    private func bindPoll(statusView: StatusView) {
        $pollItems
            .sink { items in
                guard !items.isEmpty else { return }
                
                var snapshot = NSDiffableDataSourceSnapshot<PollSection, PollItem>()
                snapshot.appendSections([.main])
                snapshot.appendItems(items, toSection: .main)
                statusView.pollTableViewDiffableDataSource?.applySnapshotUsingReloadData(snapshot)
                
                statusView.pollTableViewHeightLayoutConstraint.constant = CGFloat(items.count) * PollOptionTableViewCell.height
                statusView.setPollDisplay()
            }
            .store(in: &disposeBag)
        $isVotable
            .sink { isVotable in
                statusView.pollTableView.allowsSelection = isVotable
            }
            .store(in: &disposeBag)
    }
    
    private func bindLocation(statusView: StatusView) {
        $location
            .sink { location in
                guard let location = location, !location.isEmpty else { return }
                if statusView.traitCollection.preferredContentSizeCategory > .extraLarge {
                    statusView.locationMapPinImageView.image = Asset.ObjectTools.mappin.image
                } else {
                    statusView.locationMapPinImageView.image = Asset.ObjectTools.mappinMini.image
                }
                statusView.locationLabel.text = location
                statusView.setLocationDisplay()
            }
            .store(in: &disposeBag)
    }
    
    private func bindToolbar(statusView: StatusView) {
        $replyCount
            .sink { count in
                statusView.toolbar.setupReply(count: count, isEnabled: true)
            }
            .store(in: &disposeBag)
        Publishers.CombineLatest3(
            $isRepost,
            $repostCount,
            $protected
        )
        .sink { isRepost, count, protected in
            statusView.toolbar.setupRepost(count: count, isRepost: isRepost, isLocked: protected)
        }
        .store(in: &disposeBag)
        Publishers.CombineLatest(
            $isLike,
            $likeCount
        )
        .sink { isLike, count in
            statusView.toolbar.setupLike(count: count, isLike: isLike)
        }
        .store(in: &disposeBag)
        Publishers.CombineLatest(
            $sharePlaintextContent,
            $shareStatusURL
        )
        .sink { sharePlaintextContent, shareStatusURL in
            statusView.toolbar.setupMenu(menuContext: .init(
                shareText: sharePlaintextContent,
                shareLink: shareStatusURL,
                displayDeleteAction: false
            ))
        }
        .store(in: &disposeBag)
    }
}

extension StatusView {
    public struct ConfigurationContext {
        public let dateTimeProvider: DateTimeProvider
        public let twitterTextProvider: TwitterTextProvider
        public let activeAuthenticationContext: AnyPublisher<AuthenticationContext?, Never>
        
        public init(
            dateTimeProvider: DateTimeProvider,
            twitterTextProvider: TwitterTextProvider,
            activeAuthenticationContext: AnyPublisher<AuthenticationContext?, Never>
        ) {
            self.dateTimeProvider = dateTimeProvider
            self.twitterTextProvider = twitterTextProvider
            self.activeAuthenticationContext = activeAuthenticationContext
        }
    }
}

extension StatusView {
    public func configure(feed: Feed, configurationContext: ConfigurationContext) {
        switch feed.content {
        case .none:
            assertionFailure()
        case .twitter(let status):
            configure(
                twitterStatus: status,
                configurationContext: configurationContext
            )
        case .mastodon(let status):
            configure(
                mastodonStatus: status,
                notification: nil,
                configurationContext: configurationContext
            )
        case .mastodonNotification(let notification):
            guard let status = notification.status else {
                assertionFailure()
                return
            }
            configure(
                mastodonStatus: status,
                notification: notification,
                configurationContext: configurationContext
            )
        }
    }
    
    public func configure(
        statusObject object: StatusObject,
        configurationContext: ConfigurationContext
    ) {
        switch object {
        case .twitter(let status):
            configure(
                twitterStatus: status,
                configurationContext: configurationContext
            )
        case .mastodon(let status):
            configure(
                mastodonStatus: status,
                notification: nil,
                configurationContext: configurationContext
            )
        }
    }
    
}

// MARK: - Twitter

extension StatusView {
    public func configure(
        twitterStatus status: TwitterStatus,
        configurationContext: ConfigurationContext
    ) {
        viewModel.objects.insert(status)
        
        configureHeader(twitterStatus: status)
        configureAuthor(
            twitterStatus: status,
            dateTimeProvider: configurationContext.dateTimeProvider
        )
        configureContent(
            twitterStatus: status,
            twitterTextProvider: configurationContext.twitterTextProvider
        )
        configureMedia(twitterStatus: status)
        configureLocation(twitterStatus: status)
        configureToolbar(
            twitterStatus: status,
            activeAuthenticationContext: configurationContext.activeAuthenticationContext
        )
        
        if let quote = status.quote {
            quoteStatusView?.configure(
                twitterStatus: quote,
                configurationContext: configurationContext
            )
            setQuoteDisplay()
        }
    }
    
    private func configureHeader(twitterStatus status: TwitterStatus) {
        if let _ = status.repost {
            status.author.publisher(for: \.name)
                .map { name -> StatusView.ViewModel.Header in
                    let userRepostText = L10n.Common.Controls.Status.userRetweeted(name)
                    let metaContent = PlaintextMetaContent(string: userRepostText)
                    let info = ViewModel.Header.RepostInfo(authorNameMetaContent: metaContent)
                    return .repost(info: info)
                }
                .assign(to: \.header, on: viewModel)
                .store(in: &disposeBag)
        } else {
            viewModel.header = .none
        }
    }
    
    private func configureAuthor(
        twitterStatus status: TwitterStatus,
        dateTimeProvider: DateTimeProvider
    ) {
        let author = (status.repost ?? status).author
        // author avatar
        author.publisher(for: \.profileImageURL)
            .map { _ in author.avatarImageURL() }
            .assign(to: \.authorAvatarImageURL, on: viewModel)
            .store(in: &disposeBag)
        // lock
        author.publisher(for: \.protected)
            .assign(to: \.protected, on: viewModel)
            .store(in: &disposeBag)
        // author name
        author.publisher(for: \.name)
            .map { PlaintextMetaContent(string: $0) }
            .assign(to: \.authorName, on: viewModel)
            .store(in: &disposeBag)
        // author username
        author.publisher(for: \.username)
            .map { $0 as String? }
            .assign(to: \.authorUsername, on: viewModel)
            .store(in: &disposeBag)
        // timestamp
        viewModel.dateTimeProvider = dateTimeProvider
        (status.repost ?? status).publisher(for: \.createdAt)
            .map { $0 as Date? }
            .assign(to: \.timestamp, on: viewModel)
            .store(in: &disposeBag)
    }
    
    private func configureContent(
        twitterStatus status: TwitterStatus,
        twitterTextProvider: TwitterTextProvider
    ) {
        let status = status.repost ?? status
        let content = TwitterContent(content: status.displayText)
        let metaContent = TwitterMetaContent.convert(
            content: content,
            urlMaximumLength: 20,
            twitterTextProvider: twitterTextProvider
        )
        viewModel.content = metaContent
        viewModel.sharePlaintextContent = status.displayText
    }
    
    private func configureMedia(twitterStatus status: TwitterStatus) {
        MediaView.configuration(twitterStatus: status)
            .assign(to: \.mediaViewConfigurations, on: viewModel)
            .store(in: &disposeBag)
    }
    
    private func configureLocation(twitterStatus status: TwitterStatus) {
        let status = status.repost ?? status
        status.publisher(for: \.location)
            .map { $0?.fullName }
            .assign(to: \.location, on: viewModel)
            .store(in: &disposeBag)
    }
    
    private func configureToolbar(
        twitterStatus status: TwitterStatus,
        activeAuthenticationContext: AnyPublisher<AuthenticationContext?, Never>
    ) {
        let status = status.repost ?? status
        status.publisher(for: \.replyCount)
            .map(Int.init)
            .assign(to: \.replyCount, on: viewModel)
            .store(in: &disposeBag)
        status.publisher(for: \.repostCount)
            .map(Int.init)
            .assign(to: \.repostCount, on: viewModel)
            .store(in: &disposeBag)
        status.publisher(for: \.likeCount)
            .map(Int.init)
            .assign(to: \.likeCount, on: viewModel)
            .store(in: &disposeBag)
        viewModel.shareStatusURL = status.statusURL.absoluteString
        
        // relationship
        Publishers.CombineLatest(
            activeAuthenticationContext,
            status.publisher(for: \.repostBy)
        )
        .map { authenticationContext, repostBy in
            guard let authenticationContext = authenticationContext?.twitterAuthenticationContext else {
                return false
            }
            let userID = authenticationContext.userID
            return repostBy.contains(where: { $0.id == userID })
        }
        .assign(to: \.isRepost, on: viewModel)
        .store(in: &disposeBag)
        
        Publishers.CombineLatest(
            activeAuthenticationContext,
            status.publisher(for: \.likeBy)
        )
        .map { authenticationContext, likeBy in
            guard let authenticationContext = authenticationContext?.twitterAuthenticationContext else {
                return false
            }
            let userID = authenticationContext.userID
            return likeBy.contains(where: { $0.id == userID })
        }
        .assign(to: \.isLike, on: viewModel)
        .store(in: &disposeBag)
    }
}

// MARK: - Mastodon
extension StatusView {
    public func configure(
        mastodonStatus status: MastodonStatus,
        notification: MastodonNotification?,
        configurationContext: ConfigurationContext
    ) {
        viewModel.objects.insert(status)
        
        configureHeader(mastodonStatus: status, mastodonNotification: notification)
        configureAuthor(mastodonStatus: status, dateTimeProvider: configurationContext.dateTimeProvider)
        configureContent(mastodonStatus: status)
        configureMedia(mastodonStatus: status)
        configurePoll(mastodonStatus: status, activeAuthenticationContext: configurationContext.activeAuthenticationContext)
        configureToolbar(mastodonStatus: status, activeAuthenticationContext: configurationContext.activeAuthenticationContext)
    }
    
    private func configureHeader(
        mastodonStatus status: MastodonStatus,
        mastodonNotification notification: MastodonNotification?
    ) {
        if let notification = notification {
            let user = notification.account
            let type = notification.notificationType
            Publishers.CombineLatest(
                user.publisher(for: \.displayName),
                user.publisher(for: \.emojis)
            )
            .map { _ in
                guard let info = NotificationHeaderInfo(type: type, user: user) else { return .none }
                return ViewModel.Header.notification(info: info)
            }
            .assign(to: \.header, on: viewModel)
            .store(in: &disposeBag)
        } else if let _ = status.repost {
            Publishers.CombineLatest(
                status.author.publisher(for: \.displayName),
                status.author.publisher(for: \.emojis)
            )
            .map { _, emojis -> StatusView.ViewModel.Header in
                let name = status.author.name
                let userRepostText = L10n.Common.Controls.Status.userBoosted(name)
                let content = MastodonContent(content: userRepostText, emojis: emojis.asDictionary)
                do {
                    let metaContent = try MastodonMetaContent.convert(document: content)
                    let info = ViewModel.Header.RepostInfo(authorNameMetaContent: metaContent)
                    return .repost(info: info)
                } catch {
                    assertionFailure(error.localizedDescription)
                    let metaContent = PlaintextMetaContent(string: userRepostText)
                    let info = ViewModel.Header.RepostInfo(authorNameMetaContent: metaContent)
                    return .repost(info: info)
                }
            }
            .assign(to: \.header, on: viewModel)
            .store(in: &disposeBag)
        } else {
            viewModel.header = .none
        }
    }
    
    private func configureAuthor(
        mastodonStatus status: MastodonStatus,
        dateTimeProvider: DateTimeProvider
    ) {
        let author = (status.repost ?? status).author
        // author avatar
        author.publisher(for: \.avatar)
            .map { url in url.flatMap { URL(string: $0) } }
            .assign(to: \.authorAvatarImageURL, on: viewModel)
            .store(in: &disposeBag)
        // author name
        Publishers.CombineLatest(
            author.publisher(for: \.displayName),
            author.publisher(for: \.emojis)
        )
        .map { _, emojis in
            let content = MastodonContent(content: author.name, emojis: emojis.asDictionary)
            do {
                let metaContent = try MastodonMetaContent.convert(document: content)
                return metaContent
            } catch {
                assertionFailure(error.localizedDescription)
                return PlaintextMetaContent(string: author.name)
            }
        }
        .assign(to: \.authorName, on: viewModel)
        .store(in: &disposeBag)
        // author username
        author.publisher(for: \.acct)
            .map { $0 as String? }
            .assign(to: \.authorUsername, on: viewModel)
            .store(in: &disposeBag)
        // protected
        author.publisher(for: \.locked)
            .assign(to: \.protected, on: viewModel)
            .store(in: &disposeBag)
        // visibility
        viewModel.visibility = status.visibility.asStatusVisibility
        // timestamp
        viewModel.dateTimeProvider = dateTimeProvider
        (status.repost ?? status).publisher(for: \.createdAt)
            .map { $0 as Date? }
            .assign(to: \.timestamp, on: viewModel)
            .store(in: &disposeBag)
    }
    
    private func configureContent(mastodonStatus status: MastodonStatus) {
        let status = status.repost ?? status
        let content = MastodonContent(content: status.content, emojis: status.emojis.asDictionary)
        do {
            let metaContent = try MastodonMetaContent.convert(document: content)
            viewModel.content = metaContent
            viewModel.sharePlaintextContent = metaContent.original
        } catch {
            assertionFailure(error.localizedDescription)
            viewModel.content = PlaintextMetaContent(string: "")
        }
    }
    
    private func configureMedia(mastodonStatus status: MastodonStatus) {
        MediaView.configuration(mastodonStatus: status)
            .assign(to: \.mediaViewConfigurations, on: viewModel)
            .store(in: &disposeBag)
    }
    
    private func configurePoll(
        mastodonStatus status: MastodonStatus,
        activeAuthenticationContext: AnyPublisher<AuthenticationContext?, Never>
    ) {
        status.publisher(for: \.poll)
            .sink { poll in
                guard let poll = poll else {
                    self.viewModel.pollItems = []
                    return
                }
                
                let options = poll.options.sorted(by: { $0.index < $1.index })
                let items: [PollItem] = options.map { .option(record: .init(objectID: $0.objectID)) }
                self.viewModel.pollItems = items
            }
            .store(in: &disposeBag)
        
        Publishers.CombineLatest(
            status.publisher(for: \.poll),
            activeAuthenticationContext
        )
        .map { poll, authenticationContext in
            guard let poll = poll else { return false }
            guard case let .mastodon(authenticationContext) = authenticationContext else { return false }
            let domain = authenticationContext.domain
            let userID = authenticationContext.userID
            let isVoted = poll.voteBy.contains(where: { $0.domain == domain && $0.id == userID })
            return !isVoted && !poll.expired
        }
        .assign(to: &viewModel.$isVotable)
    }
    
    private func configureToolbar(
        mastodonStatus status: MastodonStatus,
        activeAuthenticationContext: AnyPublisher<AuthenticationContext?, Never>
    ) {
        let status = status.repost ?? status
        status.publisher(for: \.replyCount)
            .map(Int.init)
            .assign(to: \.replyCount, on: viewModel)
            .store(in: &disposeBag)
        status.publisher(for: \.repostCount)
            .map(Int.init)
            .assign(to: \.repostCount, on: viewModel)
            .store(in: &disposeBag)
        status.publisher(for: \.likeCount)
            .map(Int.init)
            .assign(to: \.likeCount, on: viewModel)
            .store(in: &disposeBag)
        viewModel.shareStatusURL = status.url ?? status.uri
        
        // relationship
        Publishers.CombineLatest(
            activeAuthenticationContext,
            status.publisher(for: \.repostBy)
        )
            .map { authenticationContext, repostBy in
                guard let authenticationContext = authenticationContext?.mastodonAuthenticationContext else {
                    return false
                }
                let domain = authenticationContext.domain
                let userID = authenticationContext.userID
                return repostBy.contains(where: { $0.id == userID && $0.domain == domain })
            }
            .assign(to: \.isRepost, on: viewModel)
            .store(in: &disposeBag)
        
        Publishers.CombineLatest(
            activeAuthenticationContext,
            status.publisher(for: \.likeBy)
        )
        .map { authenticationContext, likeBy in
            guard let authenticationContext = authenticationContext?.mastodonAuthenticationContext else {
                return false
            }
            let domain = authenticationContext.domain
            let userID = authenticationContext.userID
            return likeBy.contains(where: { $0.id == userID && $0.domain == domain })
        }
        .assign(to: \.isLike, on: viewModel)
        .store(in: &disposeBag)
    }
        
}
