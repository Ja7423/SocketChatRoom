//
//  MessageStoreManager.swift
//  SocketChatRoom
//
//  Created by 何家瑋 on 2017/11/3.
//  Copyright © 2017年 何家瑋. All rights reserved.
//

import Foundation

class MessageStoreManager : NSObject {
        static let storeManager = MessageStoreManager()
        private var messages = [String : [MessageInfo]]()
        func saveMessages(info : [MessageInfo] ,for key : String) {
                messages[key] = info
        }
        
        func messagesFor(key : String) -> [MessageInfo]? {
                return messages[key]
        }
}
