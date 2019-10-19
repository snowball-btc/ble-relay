//
//  Characteristic+Hashable.swift
//  ble-relay
//
//  Created by Robert Baltzer on 10/19/19.
//  Copyright © 2019 Robert Baltzer. All rights reserved.
//

import Foundation
import RxBluetoothKit

extension Characteristic: Hashable {

    // DJB Hashing
    public var hashValue: Int {
        let scalarArray: [UInt32] = []
        return scalarArray.reduce(5381) {
            ($0 << 5) &+ $0 &+ Int($1)
        }
    }
}
