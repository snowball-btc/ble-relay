//
//  Peripheral+Hashable.swift
//  ble-relay
//
//  Created by Robert Baltzer on 10/19/19.
//  Copyright © 2019 Robert Baltzer. All rights reserved.
//

import Foundation
import RxBluetoothKit

extension Peripheral: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.peripheral)
    }
}
