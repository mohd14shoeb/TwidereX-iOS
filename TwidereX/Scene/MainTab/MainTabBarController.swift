//
//  MainTabBarController.swift
//  TwidereX
//
//  Created by jk234ert on 8/10/20.
//  Copyright © 2020 Dimension. All rights reserved.
//

import UIKit

class MainTabBarController: UITabBarController {
    
    weak var context: AppContext!
    weak var coordinator: SceneCoordinator!
    
    enum Tab: Int, CaseIterable {
        case timeline
        case me
        
        var title: String {
            switch self {
            case .timeline:     return "Timeline"
            case .me:           return "Me"
            }
        }
        
        var image: UIImage {
            switch self {
            case .timeline:     return UIImage(systemName: "house")!
            case .me:           return UIImage(systemName: "person")!
            }
        }
        
        func viewController(context: AppContext, coordinator: SceneCoordinator) -> UIViewController {
            let navigationController: UINavigationController
            switch self {
            case .timeline:
                #if STUB
                let viewController = StubTimelineViewController()
                #else
                let viewController = HomeTimelineViewController()
                #endif
                viewController.context = context
                viewController.coordinator = coordinator
                navigationController = UINavigationController(rootViewController: viewController)
            case .me:
                let viewController = ProfileViewController()
                viewController.context = context
                viewController.coordinator = coordinator
                viewController.viewModel = MeProfileViewModel(context: context)
                navigationController = UINavigationController(rootViewController: viewController)
            }
            return navigationController
        }
    }
    
    init(context: AppContext, coordinator: SceneCoordinator) {
        self.context = context
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

extension MainTabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        let tabs = Tab.allCases
        
        let viewControllers: [UIViewController] = tabs.map { tab in
            let viewController = tab.viewController(context: context, coordinator: coordinator)
            viewController.tabBarItem.title = tab.title
            viewController.tabBarItem.image = tab.image

            return viewController
        }
        setViewControllers(viewControllers, animated: false)
        selectedIndex = 0
        
        #if DEBUG
        // selectedIndex = 1
        #endif
    }
    
}
