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
    
    override init() {
        super.init()
        peripheralManager = CBPeripheralManager()
        peripheralManager.delegate = self
    }
    
    func start() {
        if peripheralManager.state == .poweredOn {
            let options: CBCharacteristicProperties = [.write, .read, .notify, .writeWithoutResponse]
            let permissions: CBAttributePermissions = [.readable, .writeable]
            let characteristic = CBMutableCharacteristic(type: model.countCharacteristicUUID, properties: options, value: nil, permissions: permissions)
            let service = CBMutableService(type: model.serviceUUID, primary: true)
            service.characteristics = [characteristic]
            peripheralManager.add(service)
            let advertisement: [String: Any] = [CBAdvertisementDataServiceUUIDsKey: model.serviceUUID,
                                                CBAdvertisementDataLocalNameKey: model.countCharacteristicName,
                                                CBAdvertisementDataSolicitedServiceUUIDsKey: model.serviceUUID]
            peripheralManager.startAdvertising(advertisement)
    //        peripheralManager.startAdvertising(advertisement)
            model.status = "Peripheral controller start"
        }
    }
    
    // MARK: CBPeripheralManagerDelegate
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        debugPrint("peripheralManagerDidUpdateState fired")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if error != nil {
            print("error:", String(describing: error))
        } else {
            print("didAdd success:", String(describing: service))
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        debugPrint("didSubscribeTo", characteristic.uuid)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        debugPrint("didUnsubscribeFrom", characteristic.uuid)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        debugPrint("didReceiveRead")
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        debugPrint("didReceiveWrite")
    }
    // TODO: Stop advertising when switched into central mode
}
