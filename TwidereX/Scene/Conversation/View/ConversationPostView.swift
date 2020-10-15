//
//  ConversationPostView.swift
//  TwidereX
//
//  Created by Cirno MainasuK on 2020-9-17.
//

import UIKit
import ActiveLabel

final class ConversationPostView: UIView {
    
    static let avatarImageViewSize = CGSize(width: 44, height: 44)

    let avatarImageView: UIImageView = {
        let imageView = UIImageView()
        return imageView
    }()
    
    let lockImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = .white
        imageView.contentMode = .center
        imageView.image = Asset.ObjectTools.lock.image.withRenderingMode(.alwaysTemplate)
        imageView.backgroundColor = .black
        imageView.layer.masksToBounds = true
        imageView.layer.cornerRadius = TimelinePostView.lockImageViewSize.width * 0.5
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = UIColor.white.cgColor
        return imageView
    }()
    
    let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .label
        label.text = "Alice"
        return label
    }()
    
    let usernameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.text = "@alice"
        return label
    }()
    
    let moreMenuButton: UIButton = {
        let button = UIButton()
        button.setImage(Asset.Arrows.tablerChevronDown.image.withRenderingMode(.alwaysTemplate), for: .normal)
        button.imageView?.tintColor = .secondaryLabel
        return button
    }()
    
    let geoIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = .secondaryLabel
        imageView.image = Asset.ObjectTools.icRoundLocationOn.image.withRenderingMode(.alwaysTemplate)
        return imageView
    }()
    
    let geoLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.text = "Earth, Galaxy"
        return label
        
    }()
    
    let dateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.text = "2020/01/01 00:00 PM"
        return label
    }()
    
    let sourceLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textAlignment = .right
        label.textColor = Asset.Colors.hightLight.color
        label.text = "Twidere for iOS"
        return label
    }()
    
    let activeTextLabel: ActiveLabel = {
        let label = ActiveLabel()
        label.numberOfLines = 0
        label.enabledTypes = [.mention, .hashtag, .url]
        label.textColor = .label
        label.font = .systemFont(ofSize: 14)
        label.text = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
        return label
    }()
    let mosaicImageView = MosaicImageView()
    let quotePostView = QuotePostView()
    let geoMetaContainerStackView = UIStackView()
    let retweetPostStatusView = ConversationPostStatusView()
    let quotePostStatusView = ConversationPostStatusView()
    let likePostStatusView = ConversationPostStatusView()
    let actionToolbar = ConversationPostActionToolbar()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        _init()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        _init()
    }
    
}

extension ConversationPostView {
    private func _init() {        
        // container: [user meta | main | meta | action toolbar]
        let containerStackView = UIStackView()
        containerStackView.axis = .vertical
        containerStackView.spacing = 2
        //containerStackView.alignment = .top
        containerStackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerStackView)
        NSLayoutConstraint.activate([
            containerStackView.topAnchor.constraint(equalTo: topAnchor),
            containerStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            trailingAnchor.constraint(equalTo: containerStackView.trailingAnchor),
            bottomAnchor.constraint(equalTo: containerStackView.bottomAnchor),
        ])
        
        // user meta container: [user avatar | author]
        let userMetaContainerStackView = UIStackView()
        containerStackView.addArrangedSubview(userMetaContainerStackView)
        userMetaContainerStackView.axis = .horizontal
        userMetaContainerStackView.spacing = 10
        userMetaContainerStackView.alignment = .top // should name and username fill all space or not
        
        // user avatar
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        userMetaContainerStackView.addArrangedSubview(avatarImageView)
        NSLayoutConstraint.activate([
            avatarImageView.widthAnchor.constraint(equalToConstant: ConversationPostView.avatarImageViewSize.width).priority(.required - 1),
            avatarImageView.heightAnchor.constraint(equalToConstant: ConversationPostView.avatarImageViewSize.height).priority(.required - 1),
        ])
        lockImageView.translatesAutoresizingMaskIntoConstraints = false
        avatarImageView.addSubview(lockImageView)
        NSLayoutConstraint.activate([
            lockImageView.leadingAnchor.constraint(equalTo: avatarImageView.leadingAnchor),
            lockImageView.topAnchor.constraint(equalTo: avatarImageView.topAnchor),
            lockImageView.widthAnchor.constraint(equalToConstant: 16),
            lockImageView.heightAnchor.constraint(equalToConstant: 16),
        ])
        
        // author container: [name | username]
        let authorContainerStackView = UIStackView()
        userMetaContainerStackView.addArrangedSubview(authorContainerStackView)
        authorContainerStackView.axis = .vertical
        authorContainerStackView.spacing = 0

        // name container: [name | more menu]
        let nameContainerStackView = UIStackView()
        authorContainerStackView.addArrangedSubview(nameContainerStackView)
        nameContainerStackView.axis = .horizontal
        nameContainerStackView.addArrangedSubview(nameLabel)
        moreMenuButton.translatesAutoresizingMaskIntoConstraints = false
        nameContainerStackView.addArrangedSubview(moreMenuButton)
        NSLayoutConstraint.activate([
            moreMenuButton.widthAnchor.constraint(equalToConstant: 16),
            moreMenuButton.heightAnchor.constraint(equalToConstant: 16).priority(.defaultHigh),
        ])
        nameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        moreMenuButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        authorContainerStackView.addArrangedSubview(usernameLabel)
    
        // main container: [text | image | quote]
        let mainContainerStackView = UIStackView()
        containerStackView.addArrangedSubview(mainContainerStackView)
        mainContainerStackView.axis = .vertical
        mainContainerStackView.spacing = 8
        activeTextLabel.translatesAutoresizingMaskIntoConstraints = false
        mainContainerStackView.addArrangedSubview(activeTextLabel)
        mosaicImageView.translatesAutoresizingMaskIntoConstraints = false
        mainContainerStackView.addArrangedSubview(mosaicImageView)
        mainContainerStackView.addArrangedSubview(quotePostView)
        activeTextLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)
        activeTextLabel.setContentCompressionResistancePriority(.required - 2, for: .vertical)
        
        // meta container: [geo meta | date meta | status meta]
        let metaContainerStackView = UIStackView()
        containerStackView.addArrangedSubview(metaContainerStackView)
        metaContainerStackView.axis = .vertical
        metaContainerStackView.spacing = 8
        metaContainerStackView.alignment = .center

        // top padding for meta container
        let metaContainerStackViewTopPadding = UIView()
        metaContainerStackViewTopPadding.translatesAutoresizingMaskIntoConstraints = false
        metaContainerStackView.addArrangedSubview(metaContainerStackViewTopPadding)
        NSLayoutConstraint.activate([
            metaContainerStackViewTopPadding.heightAnchor.constraint(equalToConstant: 4).priority(.defaultHigh),
        ])

        // geo meta container: [geo icon | geo]
        metaContainerStackView.addArrangedSubview(geoMetaContainerStackView)
        geoMetaContainerStackView.axis = .horizontal
        geoMetaContainerStackView.spacing = 6
        geoMetaContainerStackView.addArrangedSubview(geoIconImageView)
        geoMetaContainerStackView.addArrangedSubview(geoLabel)

        // date meta container: [date | source]
        let dateMetaContainer = UIStackView()
        metaContainerStackView.addArrangedSubview(dateMetaContainer)
        dateMetaContainer.axis = .horizontal
        dateMetaContainer.spacing = 8
        dateMetaContainer.addArrangedSubview(dateLabel)
        dateMetaContainer.addArrangedSubview(sourceLabel)
        
        // status meta container: [retweet | quote | like]
        let statusMetaContainer = UIStackView()
        metaContainerStackView.addArrangedSubview(statusMetaContainer)
        statusMetaContainer.axis = .horizontal
        statusMetaContainer.distribution = .fillProportionally
        statusMetaContainer.alignment = .center
        statusMetaContainer.spacing = 20
        
        // retweet status
        retweetPostStatusView.statusLabel.text = "Retweet"
        statusMetaContainer.addArrangedSubview(retweetPostStatusView)
        
        // quote status
        quotePostStatusView.statusLabel.text = "Quote Tweet"
        statusMetaContainer.addArrangedSubview(quotePostStatusView)
        
        // like status
        likePostStatusView.statusLabel.text = "Like"
        statusMetaContainer.addArrangedSubview(likePostStatusView)
        
        // action toolbar
        actionToolbar.translatesAutoresizingMaskIntoConstraints = false
        actionToolbar.translatesAutoresizingMaskIntoConstraints = false
        containerStackView.addArrangedSubview(actionToolbar)
        NSLayoutConstraint.activate([
            actionToolbar.heightAnchor.constraint(equalToConstant: 48).priority(.defaultHigh),
        ])
        actionToolbar.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
                
        lockImageView.isHidden = true
        mosaicImageView.isHidden = true
        quotePostView.isHidden = true
    }
}

#if DEBUG
import SwiftUI

struct ConversationPostView_Previews: PreviewProvider {
    static var avatarImage: UIImage {
        UIImage(named: "patrick-perkins")!
            .af.imageRoundedIntoCircle()
    }
    
    static var avatarImage2: UIImage {
        UIImage(named: "dan-maisey")!
            .af.imageRoundedIntoCircle()
    }
    
    static var previews: some View {
        UIViewPreview(width: 375) {
            let view = ConversationPostView()
            view.avatarImageView.image = avatarImage
            let images = MosaicImageView_Previews.images.prefix(3)
            let imageViews = view.mosaicImageView.setupImageViews(count: images.count, maxHeight: 162)
            for (i, imageView) in imageViews.enumerated() {
                imageView.image = images[i]
            }
            view.mosaicImageView.isHidden = false
            view.quotePostView.avatarImageView.image = avatarImage2
            view.quotePostView.nameLabel.text = "Bob"
            view.quotePostView.usernameLabel.text = "@bob"
            view.quotePostView.isHidden = false
            return view
        }
        .previewLayout(.fixed(width: 375, height: 800))
    }
}
#endif
