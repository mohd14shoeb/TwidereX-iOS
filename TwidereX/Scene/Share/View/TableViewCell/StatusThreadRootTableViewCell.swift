//
//  StatusThreadRootTableViewCell.swift
//  StatusThreadRootTableViewCell
//
//  Created by Cirno MainasuK on 2021-8-30.
//  Copyright © 2021 Twidere. All rights reserved.
//

import os.log
import UIKit
import Combine

final class StatusThreadRootTableViewCell: UITableViewCell {
    
    var disposeBag = Set<AnyCancellable>()
    
    let logger = Logger(subsystem: "StatusThreadRootTableViewCell", category: "UI")
    
    weak var delegate: StatusViewTableViewCellDelegate?
    let statusView = StatusView()
    let toolbarSeparator = SeparatorLineView()
    let separator = SeparatorLineView()

    override func prepareForReuse() {
        super.prepareForReuse()
        
        statusView.prepareForReuse()
        disposeBag.removeAll()
    }
    
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        _init()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        _init()
    }
    
}

extension StatusThreadRootTableViewCell {
    
    private func _init() {
        selectionStyle = .none
        
        statusView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statusView)
        NSLayoutConstraint.activate([
            statusView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            statusView.leadingAnchor.constraint(equalTo: contentView.readableContentGuide.leadingAnchor),
            statusView.trailingAnchor.constraint(equalTo: contentView.readableContentGuide.trailingAnchor),
            statusView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
        statusView.setup(style: .plain)
        statusView.toolbar.setup(style: .plain)
        statusView.delegate = self
        
        toolbarSeparator.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(toolbarSeparator)
        NSLayoutConstraint.activate([
            toolbarSeparator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            toolbarSeparator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            toolbarSeparator.bottomAnchor.constraint(equalTo: statusView.toolbar.topAnchor),
        ])
        
        separator.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(separator)
        NSLayoutConstraint.activate([
            separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
        
    }
    
}

// MARK: - StatusViewContainerTableViewCell
extension StatusThreadRootTableViewCell: StatusViewContainerTableViewCell { }

// MARK: - StatusViewDelegate
extension StatusThreadRootTableViewCell: StatusViewDelegate { }
