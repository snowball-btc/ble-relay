//
//  PeripheralRxBluetoothkitService.swift
//  ble-relay
//
//  Created by Robert Baltzer on 10/27/19.
//  Copyright © 2019 Robert Baltzer. All rights reserved.
//

import CoreBluetooth
import Foundation
import RxBluetoothKit
import RxSwift

final class PeripheralRxBluetoothKitService {
 
    // MARK: - Public outputs

    var advertisementOutput: Observable<Result<StartAdvertisingResult, Error>> {
        return advertisingSubject.share(replay: 1, scope: .forever).asObservable()
    }
    
    // MARK: Private subjects

    private let peripheralManager = PeripheralManager(queue: .main)
    private let advertisingSubject = PublishSubject<Result<StartAdvertisingResult, Error>>()
    private let scheduler: ConcurrentDispatchQueueScheduler
    private let disposeBag = DisposeBag()
    private var advertisingDisposable: Disposable!
    private var addServiceDisposable: Disposable!
    private let advertisement: [String: Any] = [CBAdvertisementDataLocalNameKey: model.countCharacteristicName,
                                                CBAdvertisementDataServiceUUIDsKey: [model.serviceUUID]]

    // MARK: Initialization
    
    init() {
        let timerQueue = DispatchQueue(label: "com.snowball.peripheralrxbluetoothkit.timer")
        scheduler = ConcurrentDispatchQueueScheduler(queue: timerQueue)
    }
    
    func startAdvertising() {
        advertisingDisposable = peripheralManager.observeState()
        .startWith(peripheralManager.state)
        .filter { $0 == .poweredOn }
        .take(1)
        .subscribeOn(MainScheduler.instance)  // TODO: Could move to background
        .flatMap { [weak self] _ -> Observable<CBService> in
            guard let self = self else { return Observable.empty() }
            
            let service = CBMutableService(type: model.serviceUUID, primary: true)
            let options: CBCharacteristicProperties = [.write, .read, .notify, .writeWithoutResponse]
            let permissions: CBAttributePermissions = [.readable, .writeable]
            let characteristic = CBMutableCharacteristic(type: model.countCharacteristicUUID, properties: options, value: nil, permissions: permissions)
            service.characteristics = [characteristic]
            return self.peripheralManager.add(service).asObservable()
        }
        .flatMap { [weak self] _ -> Observable<StartAdvertisingResult> in
        guard let self = self else { return Observable.empty() }
        
        return self.peripheralManager.startAdvertising(self.advertisement)
        }.subscribe(onNext: {  [weak self] startAdvertisingResult in
            guard let self = self else { return }
            
            self.advertisingSubject.onNext(Result.success(startAdvertisingResult))
            switch startAdvertisingResult {
            case .started:
                model.status = "Advertising as peripheral"
            case .attachedToExternalAdvertising:
                model.status = "attachedToExternalAdvertising (error)"
            }
        }, onError: { [weak self] error in
            self?.advertisingSubject.onNext(Result.error(error))
        })
    }

    // TODO: Maybe call this??
    func stopAdvertising() {
        advertisingDisposable.dispose()
    }
}
