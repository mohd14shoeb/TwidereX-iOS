//
//  AccountListViewModel+Diffable.swift
//  TwidereX
//
//  Created by Cirno MainasuK on 2020-11-11.
//  Copyright © 2020 Twidere. All rights reserved.
//

import UIKit
import Combine
import CoreDataStack
import AlamofireImage

extension AccountListViewModel {
    
    func setupDiffableDataSource(for tableView: UITableView) {
        diffableDataSource = UITableViewDiffableDataSource(tableView: tableView) { [weak self] tableView, indexPath, item -> UITableViewCell? in
            guard let self = self else { return nil }
            switch item {
            case .twitterUser(let objectID):
                let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: AccountListTableViewCell.self), for: indexPath) as! AccountListTableViewCell
                let managedObjectContext = self.context.managedObjectContext
                managedObjectContext.performAndWait {
                    let twitterUser = managedObjectContext.object(with: objectID) as! TwitterUser
                    AccountListViewModel.configure(cell: cell, twitterUser: twitterUser, accountListViewControllerDelegate: self.accountListViewControllerDelegate)
                }
                cell.delegate = self.accountListTableViewCellDelegate
                return cell
            default:
                return nil
            }
        }
    }
    
    static func configure(cell: AccountListTableViewCell, twitterUser: TwitterUser, accountListViewControllerDelegate: AccountListViewControllerDelegate?) {
        // set avatar
        if let avatarImageURL = twitterUser.avatarImageURL() {
            let placeholderImage = UIImage
                .placeholder(size: UserBriefInfoView.avatarImageViewSize, color: .systemFill)
                .af.imageRoundedIntoCircle()
            let filter = ScaledToSizeCircleFilter(size: TimelinePostView.avatarImageViewSize)
            cell.userBriefInfoView.avatarImageView.af.setImage(
                withURL: avatarImageURL,
                placeholderImage: placeholderImage,
                filter: filter,
                imageTransition: .crossDissolve(0.2)
            )
        } else {
            assertionFailure()
        }
        
        cell.userBriefInfoView.verifiedBadgeImageView.isHidden = !twitterUser.verified
        cell.userBriefInfoView.lockImageView.isHidden = !twitterUser.protected
        
        // set name and username
        cell.userBriefInfoView.nameLabel.text = twitterUser.name
        cell.userBriefInfoView.usernameLabel.text = ""
        
        cell.userBriefInfoView.detailLabel.text = "@" + twitterUser.username
        
        if let accountListViewControllerDelegate = accountListViewControllerDelegate {
            let menuItems = [
                UIMenu(
                    title: L10n.Scene.ManageAccounts.deleteAccount,
                    options: .destructive,
                    children: [
                        UIAction(
                            title: L10n.Common.Controls.Actions.remove,
                            image: nil,
                            attributes: .destructive,
                            state: .off,
                            handler: { _ in
                                accountListViewControllerDelegate.signoutTwitterUser(id: twitterUser.id)
                            }
                        ),
                        UIAction(
                            title: L10n.Common.Controls.Actions.cancel,
                            attributes: [],
                            state: .off,
                            handler: { _ in
                                // do nothing
                            }
                        )
                    ]
                )
            ]
            if #available(iOS 14.0, *) {
                cell.userBriefInfoView.menuButton.menu = UIMenu(title: "", children: menuItems)
                cell.userBriefInfoView.menuButton.showsMenuAsPrimaryAction = true
            } else {
                // do nothing
            }
        }
    }

}
