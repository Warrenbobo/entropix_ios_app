//
//  LMNavigationWrapper.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit

class LMNavigationWrapper: UINavigationController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        if children.count > 0 {
            viewController.hidesBottomBarWhenPushed = true
        }
        super.pushViewController(viewController, animated: animated)
    }
}


