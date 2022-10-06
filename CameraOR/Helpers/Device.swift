//
//  Device.swift
//  CameraOR
//
//  Created by Andrew Mokryj on 29.09.2022.
//

import Foundation
import UIKit

struct Device {
    
    static var isPhone: Bool {
        return UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.phone
    }
    
}
