//
//  Relay.swift
//  ble-relay
//
//  Created by Robert Baltzer on 10/1/19.
//  Copyright © 2019 Robert Baltzer. All rights reserved.
//

import CoreBluetooth
import RxBluetoothKit
import SwiftUI

class CentralRelay: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var centralManager: CBCentralManager!
    var remoteDevice: CBPeripheral?
        
    override init() {
        super.init()
        centralManager = CBCentralManager()
        centralManager.delegate = self
    }

    // MARK: Central manager delegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: [model.serviceUUID], options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        centralManager.stopScan()

        centralManager.connect(peripheral, options: nil)
        debugPrint("didDiscover")
        dump(advertisementData)
        dump(peripheral.services)
        print(peripheral.identifier)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([model.serviceUUID])
    }

    // MARK: Peripheral delegate
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let service = peripheral.services?.first(where: { $0.uuid == model.serviceUUID }) {
            peripheral.discoverCharacteristics([model.countCharacteristicUUID], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristic = service.characteristics?.first(where: { $0.uuid == model.countCharacteristicUUID }) {
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // TODO: React accordingly
        debugPrint("didUpdateValueFor")
    }
    
    // MARK: Remove later
    
    func debug() {
        model.status = "Central controller start"
    }
}
