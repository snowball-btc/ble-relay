//
//  RxBluetoothKitService.swift
//  ble-relay
//
//  Created by Robert Baltzer on 10/19/19.
//  Copyright © 2019 Robert Baltzer. All rights reserved.
//

import CoreBluetooth
import Foundation
import RxBluetoothKit
import RxSwift

final class CentralRxBluetoothKitService {
    enum State {
        case idle                       // Do nothing
        case createRSAKeys
        case writeCentralPublicKey
        case readPeripheralPublicKey
        case incrementCounter           // Central increments count
        case writeCounter               // Central writes count to peripheral
        case waitForPeripheral          // Central allows time to pass for peripheral to rx and inc count
        case readCounter                // Central reads count from peripheral
        case awaitReadComplete          // Wait for the read to complete
        case error                      // Something went wrong
    }
    
    typealias Disconnection = (Peripheral, DisconnectionReason?)

    // MARK: - Public outputs

    var scanningOutput: Observable<Result<ScannedPeripheral, Error>> {
        return scanningSubject.share(replay: 1, scope: .forever).asObservable()
    }
    var discoveredServicesOutput: Observable<Result<[Service], Error>> {
        return discoveredServicesSubject.asObservable()
    }
    var discoveredCharacteristicsOutput: Observable<Result<[Characteristic], Error>> {
        return discoveredCharacteristicsSubject.asObservable()
    }
    var disconnectionReasonOutput: Observable<Result<Disconnection, Error>> {
        return disconnectionSubject.asObservable()
    }
    var readValueOutput: Observable<Result<Characteristic, Error>> {
        return readValueSubject.asObservable()
    }
    var writeValueOutput: Observable<Result<Characteristic, Error>> {
        return writeValueSubject.asObservable()
    }
    var updatedValueAndNotificationOutput: Observable<Result<Characteristic, Error>> {
        return updatedValueAndNotificationSubject.asObservable()
    }

    // MARK: - Private subjects

    private let discoveredCharacteristicsSubject = PublishSubject<Result<[Characteristic], Error>>()
    private let scanningSubject = PublishSubject<Result<ScannedPeripheral, Error>>()
    private let discoveredServicesSubject = PublishSubject<Result<[Service], Error>>()
    private let disconnectionSubject = PublishSubject<Result<Disconnection, Error>>()
    private let readValueSubject = PublishSubject<Result<Characteristic, Error>>()
    private let writeValueSubject = PublishSubject<Result<Characteristic, Error>>()
    private let updatedValueAndNotificationSubject = PublishSubject<Result<Characteristic, Error>>()

    // MARK: - Private fields

    private let centralManager = CentralManager(queue: .main)
    private var state: State = .idle
    private let scheduler: ConcurrentDispatchQueueScheduler
    private let disposeBag = DisposeBag()
    private var peripheralConnections: [Peripheral: Disposable] = [:]
    private var scanningDisposable: Disposable!
    private var connectionDisposable: Disposable!
    private var notificationDisposables: [Characteristic: Disposable] = [:]
    private var countCharacteristic: Characteristic!
    private var centralPubKeyCharacteristic: Characteristic!
    private var peripheralPubKeyCharacteristic: Characteristic!
    private var time: Int = 0

    // MARK: - Initialization
    
    init() {
        let timerQueue = DispatchQueue(label: "com.snowball.centralrxbluetoothkit.timer")
        scheduler = ConcurrentDispatchQueueScheduler(queue: timerQueue)
    }
    
    func startRelaying() {
        model.status = "Searching for snowball peripherals"
        
        let snowballPeripheral = scanningOutput
            .take(1)
            .map { result in
                switch result {
                case .success(let perip):
                    self.discoverServices(for: perip.peripheral)
                    model.status = "Found snowball peripheral"
                case .error(let err):
                    print(err)
                }
            }
        
        let snowballService = discoveredServicesOutput
            .take(1)
            .map { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let services):
                    for service in services where service.uuid == model.serviceUUID {
                        self.discoverCharacteristics(for: service)
                        model.status = "Found snowball service"
                    }
                case .error(let err):
                    print(err)
                }
            }
            
        let snowballCharacteristic = discoveredCharacteristicsOutput
            .take(1)
            .map { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let characteristics):
                    for characteristic in characteristics {
                        if characteristic.uuid == model.countCharacteristic.UUID {
                            self.countCharacteristic = characteristic
                            model.status = "Found count characteristic"
                            print(model.status)
                        } else if characteristic.uuid == model.peripheralCharacteristic.UUID {
                            self.peripheralPubKeyCharacteristic = characteristic
                            model.status = "Found peripheralPubKeyCharacteristic characteristic"
                        } else if characteristic.uuid == model.centralCharacteristic.UUID {
                            self.centralPubKeyCharacteristic = characteristic
                            model.status = "Found centralPubKeyCharacteristic characteristic"
                        }
                        print(model.status)
                    }

                case .error(let err):
                    print(err)
                }
            }
        
        _ = Observable.zip(snowballPeripheral, snowballService, snowballCharacteristic) { _, _, _ in }
            .subscribe(onNext: { [weak self] in
                guard let self = self else { return }

                model.status = "\(self.countCharacteristic.uuid)"
                self.startReadObservable()
                self.stopScanning()
                self.state = .createRSAKeys
                self.startReadWrites()
        }).disposed(by: disposeBag)
        
        startScanning()
    }
    
    func startReadWrites() {
        _ = Observable<Int>.interval(RxTimeInterval.seconds(1), scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                // Churn state machine every second
                self?.centralStateMachine()
            }).disposed(by: disposeBag)
    }
    
    func startReadObservable() {
        _ = readValueOutput.subscribe(onNext: { [weak self] result in
            guard let self = self else { return }
        
            switch result {
            case .success(let characteristic):
                switch characteristic.uuid {
                case model.countCharacteristic.UUID:
                    guard let data = characteristic.value,
                          let text = EncryptDecrypt.shared.decrypt(stringToDecrypt: String(decoding: data, as: UTF8.self)),
                          let value = Int(text) else { return }
                    
                    if value - model.countValue == 1 {
                        // Periperhal incremented by one, now it is Central's turn
                        self.state = .incrementCounter
                        model.countValue = value
                    }
                case model.peripheralCharacteristic.UUID:
                    guard let data = characteristic.value else { return }
                    
                    model.peripheralPubKey = String(decoding: data, as: UTF8.self)
                    print("peripheralPubKey:", model.peripheralPubKey)
                    self.state = .incrementCounter
                default:
                    print("ERROR: unknown UUID", characteristic)
                }
            case .error(let err):
                print(err)
            }
        }).disposed(by: disposeBag)
    }
    
    func centralStateMachine() {
        time += 1
        
        switch state {
        case .idle:
            break
        case .createRSAKeys:
            EncryptDecrypt.shared.createKeys()
            state = .writeCentralPublicKey
        case .writeCentralPublicKey:
            writeValueTo(characteristic: centralPubKeyCharacteristic,
                         data: Data(String(model.pubKeyString).utf8))
            model.status = model.pubKeyString
//            state = .readPeripheralPublicKey
            state = .idle
        case .readPeripheralPublicKey:
            readValueFrom(peripheralPubKeyCharacteristic)
            state = .awaitReadComplete
        case .incrementCounter:
            model.countValue += 1
            state = .writeCounter
        case .writeCounter:
            guard let encryptedString = EncryptDecrypt.shared.encrypt(stringToEncrypt: String(model.countValue)) else { return }
            writeValueTo(characteristic: countCharacteristic, data: Data(String(encryptedString).utf8))
            time = 0
            state = .waitForPeripheral
        case .waitForPeripheral:
            if time > 1 {
                state = .readCounter
            }
        case .readCounter:
            readValueFrom(countCharacteristic)
            state = .awaitReadComplete
        case .awaitReadComplete:
            // Do nothing
            break
        case .error:
            print("error")
        }
    }
    // MARK: - Scanning for peripherals

    // You start from observing state of your CentralManager object. Within RxBluetoothKit v.5.0, it is crucial
    // that you use .startWith(:_) operator, and pass the initial state of your CentralManager with
    // centralManager.state.
    func startScanning() {
        scanningDisposable = centralManager.observeState()
        .startWith(centralManager.state)
        .filter { $0 == .poweredOn }
        .subscribeOn(MainScheduler.instance)
        .flatMap { [weak self] _ -> Observable<ScannedPeripheral> in
            guard let self = self else {
                return Observable.empty()
            }
            return self.centralManager.scanForPeripherals(withServices: [model.serviceUUID])
        }.subscribe(onNext: { [weak self] scannedPeripheral in
            self?.scanningSubject.onNext(Result.success(scannedPeripheral))
        }, onError: { [weak self] error in
            self?.scanningSubject.onNext(Result.error(error))
        })
    }

    // If you wish to stop scanning for peripherals, you need to dispose the Disposable object, created when
    // you either subscribe for events from an observable returned by centralManager.scanForPeripherals(:_), or you bind
    // an observer to it. Check starScanning() above for details.
    func stopScanning() {
        scanningDisposable.dispose()
    }

    // MARK: - Peripheral Connection & Discovering Services

    // When you discover a service, first you need to establish a connection with a peripheral. Then you call
    // discoverServices(:_) for that peripheral object.
    func discoverServices(for peripheral: Peripheral) {
        let isConnected = peripheral.isConnected
        
        let connectedObservableCreator = { peripheral.discoverServices(nil).asObservable() }
        let connectObservableCreator = {
            peripheral.establishConnection()
                .do(onNext: { [weak self] _ in
                    self?.observeDisconnect(for: peripheral)
                })
                .flatMap { $0.discoverServices(nil) }
        }
        let observable = isConnected ? connectedObservableCreator(): connectObservableCreator()
        let disposable = observable.subscribe(onNext: { [weak self] services in
                    self?.discoveredServicesSubject.onNext(Result.success(services))
                }, onError: { [weak self] error in
                    self?.discoveredServicesSubject.onNext(Result.error(error))
                })

        if isConnected {
            disposeBag.insert(disposable)
        } else {
            peripheralConnections[peripheral] = disposable
        }
    }

    // Disposal of a given connection disposable disconnects automatically from a peripheral
    // So firstly, you discconect from a perpiheral and then you remove of disconnected Peripheral
    // from the Peripheral's collection.
    func disconnect(_ peripheral: Peripheral) {
        guard let disposable = peripheralConnections[peripheral] else {
            return
        }
        disposable.dispose()
        peripheralConnections[peripheral] = nil
    }

    // MARK: - Discovering Characteristics
    
    func discoverCharacteristics(for service: Service) {
        service.discoverCharacteristics(nil).subscribe(onSuccess: { [unowned self] characteristics in
            self.discoveredCharacteristicsSubject.onNext(Result.success(characteristics))
        }, onError: { error in
            self.discoveredCharacteristicsSubject.onNext(Result.error(error))
        }).disposed(by: disposeBag)
    }

    // MARK: - Reading from and writing to a characteristic
    
    func readValueFrom(_ characteristic: Characteristic) {
        characteristic.readValue().subscribe(onSuccess: { [unowned self] characteristic in
            self.readValueSubject.onNext(Result.success(characteristic))
        }, onError: { [unowned self] error in
            self.readValueSubject.onNext(Result.error(error))
        }).disposed(by: disposeBag)
    }

    func writeValueTo(characteristic: Characteristic, data: Data) {
        guard let writeType = characteristic.determineWriteType() else {
            return
        }

        characteristic.writeValue(data, type: writeType).subscribe(onSuccess: { [unowned self] characteristic in
            self.writeValueSubject.onNext(Result.success(characteristic))
        }, onError: { [unowned self] error in
            self.writeValueSubject.onNext(Result.error(error))
        }).disposed(by: disposeBag)
    }

    // MARK: - Characteristic notifications

    // observeValueUpdateAndSetNotification(:_) returns a disposable from subscription, which triggers notifying start
    // on a selected characteristic.
    func observeValueUpdateAndSetNotification(for characteristic: Characteristic) {
        if notificationDisposables[characteristic] != nil {
            self.updatedValueAndNotificationSubject.onNext(Result.error(RxBluetoothServiceError.redundantStateChange))
        } else {
            let disposable = characteristic.observeValueUpdateAndSetNotification()
            .subscribe(onNext: { [weak self] characteristic in
                self?.updatedValueAndNotificationSubject.onNext(Result.success(characteristic))
            }, onError: { [weak self] error in
                self?.updatedValueAndNotificationSubject.onNext(Result.error(error))
            })

            notificationDisposables[characteristic] = disposable
        }
    }

    func disposeNotification(for characteristic: Characteristic) {
        if let disposable = notificationDisposables[characteristic] {
            disposable.dispose()
            notificationDisposables[characteristic] = nil
        } else {
            self.updatedValueAndNotificationSubject.onNext(Result.error(RxBluetoothServiceError.redundantStateChange))
        }
    }

    // observeNotifyValue tells us when exactly a characteristic has changed it's state (e.g isNotifying).
    // We need to use this method, because hardware needs an amount of time to switch characteristic's state.
    func observeNotifyValue(peripheral: Peripheral, characteristic: Characteristic) {
        peripheral.observeNotifyValue(for: characteristic)
        .subscribe(onNext: { [unowned self] characteristic in
            self.updatedValueAndNotificationSubject.onNext(Result.success(characteristic))
        }, onError: { [unowned self] error in
            self.updatedValueAndNotificationSubject.onNext(Result.error(error))
        }).disposed(by: disposeBag)
    }

    // MARK: - Private methods

    // When you observe disconnection from a peripheral, you want to be sure that you take an action on both .next and
    // .error events. For instance, when your device enters BluetoothState.poweredOff, you will receive an .error event.
    private func observeDisconnect(for peripheral: Peripheral) {
        centralManager.observeDisconnect(for: peripheral).subscribe(onNext: { [unowned self] peripheral, reason in
            self.disconnectionSubject.onNext(Result.success((peripheral, reason)))
            self.disconnect(peripheral)
        }, onError: { [unowned self] error in
            self.disconnectionSubject.onNext(Result.error(error))
        }).disposed(by: disposeBag)
    }
}

enum RxBluetoothServiceError: Error {

    case redundantStateChange

}
