//
//  UIColorExtension.swift
//  FacialEmotionDetection
//
//  Created by Joshua Newnham on 09/03/2018.
//  Copyright © 2018 PacktPub. All rights reserved.
//

import UIKit 

/**
 Simple extension of the color
 */
extension UIColor {
    
    public convenience init(red: Int, green: Int, blue: Int, alpha: CGFloat=1.0) {
        
        self.init(red: CGFloat(red)/255,
                  green: CGFloat(green)/255,
                  blue: CGFloat(blue)/255,
                  alpha: alpha)
    }
}
