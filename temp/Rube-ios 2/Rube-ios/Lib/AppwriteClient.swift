//
//  AppwriteClient.swift
//  Rube-ios
//
//  Global Appwrite client configuration
//

import Foundation
import Appwrite

let client = Client()
    .setEndpoint("https://nyc.cloud.appwrite.io/v1")
    .setProject("6961fcac000432c6a72a")

let account = Account(client)
