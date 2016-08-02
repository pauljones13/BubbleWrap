//
//  NSNumber+CGFloat.swift
//  BubbleWrap
//
//  Created by Paul Jones on 16/05/2016.
//  Copyright © 2016 Fluid Pixel Limited. All rights reserved.
//

import Foundation
import UIKit


public extension NSNumber {
    var CGFloatValue: CGFloat {
        return CGFloat(self.doubleValue)
    }
    convenience init(CGFloatValue value: CGFloat) {
        self.init(double: Double(value))
    }
}
