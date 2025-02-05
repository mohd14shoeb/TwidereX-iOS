//
//  TimelineViewController.swift
//  TwidereX
//
//  Created by MainasuK on 2022-6-14.
//  Copyright © 2022 Twidere. All rights reserved.
//

import os.log
import UIKit
import Combine
import Floaty
import AppShared
import TwidereCore
import TwidereUI
import TabBarPager

class TimelineViewController: UIViewController, NeedsDependency, DrawerSidebarTransitionHostViewController, MediaPreviewableViewController {
 
    let logger = Logger(subsystem: "TimelineViewController", category: "ViewController")

    // MARK: NeedsDependency
    weak var context: AppContext! { willSet { precondition(!isViewLoaded) } }
    weak var coordinator: SceneCoordinator! { willSet { precondition(!isViewLoaded) } }
    
    // MARK: DrawerSidebarTransitionHostViewController
    private(set) var drawerSidebarTransitionController: DrawerSidebarTransitionController!
    let avatarBarButtonItem = AvatarBarButtonItem()
    
    // MARK: MediaPreviewTransitionHostViewController
    let mediaPreviewTransitionController = MediaPreviewTransitionController()
    
    var disposeBag = Set<AnyCancellable>()
    var observations = Set<NSKeyValueObservation>()
    
    var _viewModel: TimelineViewModel!
    
    private(set) lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(TimelineViewController.refreshControlValueChanged(_:)), for: .valueChanged)
        return refreshControl
    }()
    
    let publishProgressView: UIProgressView = {
        let progressView = UIProgressView()
        progressView.progressViewStyle = .bar
        progressView.tintColor = Asset.Colors.hightLight.color
        return progressView
    }()
    
    private lazy var floatyButton: Floaty = {
        let button = Floaty()
        button.plusColor = .white
        button.buttonColor = ThemeService.shared.theme.value.accentColor
        button.buttonImage = Asset.Editing.featherPen.image
        button.handleFirstItemDirectly = true
        
        let composeItem: FloatyItem = {
            let item = FloatyItem()
            item.title = L10n.Scene.Compose.Title.compose
            item.handler = { [weak self] item in
                guard let self = self else { return }
                self.floatyButtonPressed(item)
            }
            return item
        }()
        button.addItem(item: composeItem)
        
        return button
    }()
    
    deinit {
        os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s:", ((#file as NSString).lastPathComponent), #line, #function)
    }
    
}

extension TimelineViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        drawerSidebarTransitionController = DrawerSidebarTransitionController(hostViewController: self)

        view.backgroundColor = .systemBackground

        // setup avatarBarButtonItem
        if navigationController?.viewControllers.first == self {
            coordinator.$needsSetupAvatarBarButtonItem
                .receive(on: DispatchQueue.main)
                .sink { [weak self] needsSetupAvatarBarButtonItem in
                    guard let self = self else { return }
                    self.navigationItem.leftBarButtonItem = needsSetupAvatarBarButtonItem ? self.avatarBarButtonItem : nil
                }
                .store(in: &disposeBag)
        }
        avatarBarButtonItem.avatarButton.addTarget(self, action: #selector(TimelineViewController.avatarButtonPressed(_:)), for: .touchUpInside)
        avatarBarButtonItem.delegate = self
        
        // bind avatarBarButtonItem data
        Publishers.CombineLatest(
            context.authenticationService.$activeAuthenticationContext,
            _viewModel.viewDidAppear.eraseToAnyPublisher()
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] authenticationContext, _ in
            guard let self = self else { return }
            let user = authenticationContext?.user(in: self.context.managedObjectContext)
            self.avatarBarButtonItem.configure(user: user)
        }
        .store(in: &disposeBag)
        
        // layout publish progress
        publishProgressView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(publishProgressView)
        NSLayoutConstraint.activate([
            publishProgressView.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
            publishProgressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            publishProgressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        
        context.publisherService.$currentPublishProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                guard let self = self else { return }
                let progress = Float(progress)
                let withAnimation = progress > self.publishProgressView.progress
                self.publishProgressView.setProgress(progress, animated: withAnimation)
                
                if progress == 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                        guard let self = self else { return }
                        self.publishProgressView.setProgress(0, animated: false)
                    }
                }
            }
            .store(in: &disposeBag)

        view.addSubview(floatyButton)
        _viewModel.$isFloatyButtonDisplay
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isFloatyButtonDisplay in
                guard let self = self else { return }
                self.floatyButton.isHidden = !isFloatyButtonDisplay
            }
            .store(in: &disposeBag)
        
        _viewModel.didLoadLatest
            .receive(on: DispatchQueue.main, options: nil)
            .sink { [weak self] in
                guard let self = self else { return }
                UIView.animate(withDuration: 0.5) { [weak self] in
                    guard let self = self else { return }
                    self.refreshControl.endRefreshing()
                }
            }
            .store(in: &disposeBag)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        view.bringSubviewToFront(floatyButton)

        refreshControl.endRefreshing()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        _viewModel.viewDidAppear.send()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.floatyButton.paddingY = self.view.safeAreaInsets.bottom + UIView.floatyButtonBottomMargin
        }
    }

}

extension TimelineViewController {

    @objc private func avatarButtonPressed(_ sender: UIButton) {
        logger.log(level: .debug, "\((#file as NSString).lastPathComponent, privacy: .public)[\(#line, privacy: .public)], \(#function, privacy: .public)")
        let drawerSidebarViewModel = DrawerSidebarViewModel(context: context)
        coordinator.present(scene: .drawerSidebar(viewModel: drawerSidebarViewModel), from: self, transition: .custom(transitioningDelegate: drawerSidebarTransitionController))
    }

    @objc private func refreshControlValueChanged(_ sender: UIRefreshControl) {
        logger.log(level: .debug, "\((#file as NSString).lastPathComponent, privacy: .public)[\(#line, privacy: .public)], \(#function, privacy: .public)")
        
        Task { @MainActor in
            assert(self._viewModel != nil)
            
            await self._viewModel.loadLatest()
            
            if self._viewModel.preferredTimelineResetToTop,
               let scrollViewContainer = self as? ScrollViewContainer
            {
                await _ = try self._viewModel.didLoadLatest.eraseToAnyPublisher().singleOutput()
                scrollViewContainer.scrollToTop(
                    animated: true,
                    option: .init(tryRefreshWhenStayAtTop: false)
                )
            }
        }
    }

    @objc private func floatyButtonPressed(_ sender: FloatyItem) {
        os_log("%{public}s[%{public}ld], %{public}s", ((#file as NSString).lastPathComponent), #line, #function)
        
        let composeViewModel = ComposeViewModel(context: context)
        let composeContentViewModel = ComposeContentViewModel(
            kind: {
                switch _viewModel.kind {
                case .home:
                    return .post
                case .public:
                    return .post
                case .hashtag(let hashtag):
                    return .hashtag(hashtag: hashtag)
                case .list:
                    assertionFailure("do not support post on list status")
                    return .post
                case .search:
                    assertionFailure("do not support post on search status")
                    return .post
                case .user:
                    assertionFailure("prefer use profile floaty button")
                    return .post
                }
            }(),
            settings: {
                var settings = ComposeContentViewModel.Settings()
                switch _viewModel.kind {
                case .public:
                    settings.mastodonVisibility = .public
                default:
                    break
                }
                return settings
            }(),
            configurationContext: ComposeContentViewModel.ConfigurationContext(
                apiService: context.apiService,
                authenticationService: context.authenticationService,
                mastodonEmojiService: context.mastodonEmojiService,
                statusViewConfigureContext: .init(
                    dateTimeProvider: DateTimeSwiftProvider(),
                    twitterTextProvider: OfficialTwitterTextProvider(),
                    authenticationContext: context.authenticationService.$activeAuthenticationContext
                )
            )
        )
        coordinator.present(scene: .compose(viewModel: composeViewModel, contentViewModel: composeContentViewModel), from: self, transition: .modal(animated: true, completion: nil))
    }

}

// MARK: - AvatarBarButtonItemDelegate
extension TimelineViewController: AvatarBarButtonItemDelegate { }
