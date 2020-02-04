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
    private let didReadSubject = PublishSubject<CBATTRequest>()
    private let scheduler: ConcurrentDispatchQueueScheduler
    private let disposeBag = DisposeBag()
    private var advertisingDisposable: Disposable!
    private var readDisposable: Disposable!
    private var writeDisposable: Disposable!
    
    // MARK: Initialization
    
    init() {
        let timerQueue = DispatchQueue(label: "com.snowball.peripheralrxbluetoothkit.timer")
        scheduler = ConcurrentDispatchQueueScheduler(queue: timerQueue)
    }
    
    func startAdvertising() {
        startHandlingReads()
        starthandlingWrites()
        
        advertisingDisposable = peripheralManager.observeState()
        .startWith(peripheralManager.state)
        .filter { $0 == .poweredOn }
        .take(1)
        .subscribeOn(MainScheduler.instance)
        .flatMap { [weak self] _ -> Observable<CBService> in
            guard let self = self else { return Observable.empty() }
            
            let service = CBMutableService(type: model.serviceUUID, primary: true)
            let options: CBCharacteristicProperties = [.write, .read, .notify, .writeWithoutResponse]
            let permissions: CBAttributePermissions = [.readEncryptionRequired, .writeEncryptionRequired]
            var characteristic = CBMutableCharacteristic(type: model.count.UUID, properties: options, value: nil, permissions: permissions)
            service.characteristics = [characteristic]
            characteristic = CBMutableCharacteristic(type: model.peripheral.UUID, properties: options, value: nil, permissions: permissions)
            service.characteristics?.append(characteristic)
            characteristic = CBMutableCharacteristic(type: model.central.UUID, properties: options, value: nil, permissions: permissions)
            service.characteristics?.append(characteristic)
            return self.peripheralManager.add(service).asObservable()
        }
        .flatMap { [weak self] _ -> Observable<StartAdvertisingResult> in
            guard let self = self else { return Observable.empty() }

            let advertisement: [String: Any] = [CBAdvertisementDataLocalNameKey: model.count.name,
                                                CBAdvertisementDataServiceUUIDsKey: [model.serviceUUID]]
            return self.peripheralManager.startAdvertising(advertisement)
        }.subscribe(onNext: { [weak self] startAdvertisingResult in
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

    func startHandlingReads() {
        readDisposable = peripheralManager.observeDidReceiveRead()
        .subscribe(onNext: { [weak self] in
            guard let self = self,
                $0.characteristic.uuid == model.count.UUID else { return }
            
            if $0.offset > 1 {
                self.peripheralManager.respond(to: $0, withResult: CBATTError.invalidOffset)
                return
            }
            $0.value = Data(String(model.countValue).utf8)
            self.peripheralManager.respond(to: $0, withResult: CBATTError.success)
        })
    }
    
    // Make sure incoming write is +1 before incrementing our model
    func starthandlingWrites() {
        writeDisposable = peripheralManager.observeDidReceiveWrite()
        .debug()
        .subscribe(onNext: {
            guard let uuid = $0.first?.characteristic.uuid,
                  let data = $0.first?.value,
                uuid == model.count.UUID else { return }

            let incomingCount = Int(String(decoding: data, as: UTF8.self)) ?? -1
            if incomingCount - model.countValue == 1 {
                model.countValue = incomingCount + 1
            }
        })
    }
    
    // TODO: Maybe call this at some point
    func stopAdvertising() {
        advertisingDisposable.dispose()
        readDisposable.dispose()
        writeDisposable.dispose()
    }
}
