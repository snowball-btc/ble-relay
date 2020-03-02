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
        var error: Unmanaged<CFError>?
        
        let attributes: [String: Any] =
            [kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
             kSecAttrKeySizeInBits as String: 2048,
             kSecPrivateKeyAttrs as String:
                [kSecAttrIsPermanent as String: false,
                 kSecAttrApplicationTag as String: "com.snowball-btc.ble-relay".data(using: .utf8)!]
        ]
        
        do {
            guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
                throw error!.takeRetainedValue() as Error
            }
            guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
                throw error!.takeRetainedValue() as Error
            }
            model.privKey = privateKey
            model.pubKey = publicKey
            if let cfdata = SecKeyCopyExternalRepresentation(privateKey, &error) {
                let data: Data = cfdata as Data
                model.privKeyString = data.base64EncodedString()
            }
            if let cfdata = SecKeyCopyExternalRepresentation(publicKey, &error) {
                let data: Data = cfdata as Data
                model.pubKeyString = data.base64EncodedString()
            }
        } catch {
            print(error)
        }
    }
    
    func encrypt(stringToEncrypt: String) -> String? {
        let buffer = [UInt8](stringToEncrypt.utf8)

        var keySize = SecKeyGetBlockSize(model.pubKey)
        var keyBuffer = [UInt8](repeating: 0, count: keySize)

        // Encrypt  should less than key length
        let err = SecKeyEncrypt(model.pubKey, SecPadding.PKCS1, buffer, buffer.count, &keyBuffer, &keySize)
        if err != errSecSuccess {
            print(NSError(domain: NSOSStatusErrorDomain, code: Int(err), userInfo: [NSLocalizedDescriptionKey: SecCopyErrorMessageString(err, nil) ?? "Undefined error"]))
            return nil
        }
        return Data(bytes: keyBuffer, count: keySize).base64EncodedString()
    }
    
    func decrypt(stringToDecrypt: String) -> String? {
        let buffer = [UInt8](stringToDecrypt.utf8)
        var keySize = SecKeyGetBlockSize(model.privKey)
        var keyBuffer = [UInt8](repeating: 0, count: keySize)
        
        let err = SecKeyDecrypt(model.privKey, SecPadding.PKCS1, buffer, buffer.count, &keyBuffer, &keySize)
        if err != errSecSuccess {
            print(NSError(domain: NSOSStatusErrorDomain, code: Int(err), userInfo: [NSLocalizedDescriptionKey: SecCopyErrorMessageString(err, nil) ?? "Undefined error"]))
            return nil
        }
        return Data(bytes: keyBuffer, count: keySize).base64EncodedString()
    }
}
