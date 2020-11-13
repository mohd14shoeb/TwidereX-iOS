//
//  SidebarItem.swift
//  TwidereX
//
//  Created by Cirno MainasuK on 2020-11-9.
//  Copyright © 2020 Twidere. All rights reserved.
//

import UIKit

enum SidebarItem: Equatable, Hashable {
    case messages
    case likes
    case lists
    case trends
    case drafts
    case settings
}

extension SidebarItem {
    
    var title: String {
        switch self {
        case .messages:     return "Messages"
        case .likes:        return "Likes"
        case .lists:        return "Lists"
        case .trends:       return "Trends"
        case .drafts:       return "Drafts"
        case .settings:     return "Settings"
        }
    }
    
    var image: UIImage {
        switch self {
        case .messages:     return Asset.Communication.mail.image.withRenderingMode(.alwaysTemplate)
        case .likes:        return Asset.Health.heart.image.withRenderingMode(.alwaysTemplate)
        case .lists:        return Asset.ObjectTools.bookmarks.image.withRenderingMode(.alwaysTemplate)
        case .trends:       return Asset.Arrows.trendingUp.image.withRenderingMode(.alwaysTemplate)
        case .drafts:       return Asset.ObjectTools.note.image.withRenderingMode(.alwaysTemplate)
        case .settings:     return Asset.Editing.sliderHorizontal3.image.withRenderingMode(.alwaysTemplate)
        }
    }
    
}
