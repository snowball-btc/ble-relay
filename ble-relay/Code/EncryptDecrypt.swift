//
//  EncryptDecrypt.swift
//  ble-relay
//
//  Created by Robert Baltzer on 1/28/20.
//  Copyright © 2020 Robert Baltzer. All rights reserved.
//

import Foundation

class EncryptDecrypt {
    static let shared = EncryptDecrypt()
    
    func createKeys() {
        let tag = "com.snowball-btc.ble-relay".data(using: .utf8)!
        let attributes: [String: Any] =
            [kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
             kSecAttrKeySizeInBits as String: 2048,
             kSecPrivateKeyAttrs as String:
                [kSecAttrIsPermanent as String: true,
                 kSecAttrApplicationTag as String: tag]
        ]
        
        var error: Unmanaged<CFError>?
        
        do {
            guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
                throw error!.takeRetainedValue() as Error
            }
            guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
                throw error!.takeRetainedValue() as Error
            }
            if let cfdata = SecKeyCopyExternalRepresentation(privateKey, &error) {
                let data: Data = cfdata as Data
                model.privKey = data.base64EncodedString()
            }
            if let cfdata = SecKeyCopyExternalRepresentation(publicKey, &error) {
                let data: Data = cfdata as Data
                model.pubKey = data.base64EncodedString()
            }
        } catch {
            print(error)
        }
    }
}
