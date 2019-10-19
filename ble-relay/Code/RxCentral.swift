//
//  RxCentral.swift
//  ble-relay
//
//  Created by Robert Baltzer on 10/19/19.
//  Copyright © 2019 Robert Baltzer. All rights reserved.
//

import Foundation
import RxBluetoothKit
import RxSwift

class RxCentral {
    var manager: CentralManager!
    var state: BluetoothState!
    var disposable: Observable<BluetoothState>!
        
    init() {
        manager = CentralManager(queue: .main)
    }
    
    func start() {
        state = manager.state
        disposable = manager.observeState()
            .startWith(state)
            .filter { $0 == .poweredOn }
    }

}
