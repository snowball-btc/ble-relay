//
//  PeripheralRelay.swift
//  ble-relay
//
//  Created by Robert Baltzer on 10/6/19.
//  Copyright © 2019 Robert Baltzer. All rights reserved.
//

import CoreBluetooth

class PeripheralRelay: NSObject, CBPeripheralManagerDelegate {
    var peripheralManager: CBPeripheralManager!
    var central: CBCentral?
    let service = CBMutableService(type: model.serviceUUID, primary: true)
    
    override init() {
        super.init()
        peripheralManager = CBPeripheralManager()
        peripheralManager.delegate = self
    }
    
    func start() {
        peripheralManager.add(service)
        peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey : service.uuid])
        model.status = "Peripheral controller start"
    }
    
    // MARK: CBPeripheralManagerDelegate
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        debugPrint("peripheralManagerDidUpdateState fired")
    }
    
    // TODO: Stop advertising when switched into central mode
}
