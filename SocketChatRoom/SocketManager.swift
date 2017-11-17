//
//  SocketManager.swift
//  SocketChatRoom
//
//  Created by 何家瑋 on 2017/10/26.
//  Copyright © 2017年 何家瑋. All rights reserved.
//

import UIKit
import SocketIO

class SocketManager: NSObject {
        static let Manager = SocketManager()
        private var socket : SocketIOClient?
        
        private var statusObserver : NSKeyValueObservation?
        @objc dynamic var currentStatus : Int = 0
        
        private var didReceiveUserList : (([UserInfo]) -> Void)?
        private var didReceiveRoomList : (([RoomInfo]) -> Void)?
        private var didReceiveRoomResponse : ((Bool, [String : AnyObject]) -> Void)?
        private var didReceiveUserChange : ((Bool, String) -> Void)?
        private var didReceiveMessage : ((MessageInfo) -> Void)?
        private var didReceiveChatRoomInfoChange : ((RoomInfo) -> Void)?
        
        override init() {
                super.init()
        }
        
        func connect(to address: String) {
                // address format like "http://192.168.XXX.XXX:portNumber"
                guard let url =  URL(string: address) else {
                        return
                }
                
                socket = SocketIOClient(socketURL: url)
                handleListenEvent()
                socket?.connect()
        }
        
        func closeConnect() {
                socket?.disconnect()
        }
        
        private func handleListenEvent() {
                listenConnectStatus()
                
                // userList
                socket?.on(EventKey.userList, callback: { (datas, ack) in
                        print("userList : \(datas[0])")
                        var users = [UserInfo]()
                        let userList = datas[0] as! [[String : AnyObject]]
                        for user in userList {
                                let info = UserInfo.infoWith(data: user)
                                users.append(info)
                        }
                        
                        if self.didReceiveUserList != nil {
                                self.didReceiveUserList!(users)
                        }
                })
                
                // roomList
                socket?.on(EventKey.roomList, callback: { (datas, ack) in
                        print("roomList : \(datas[0])")
                        var rooms = [RoomInfo]()
                        let roomList = datas[0] as! [[String : AnyObject]]
                        for room in roomList {
                                let info = RoomInfo.infoWith(data: room)
                                rooms.append(info)
                        }

                        if self.didReceiveRoomList != nil {
                                self.didReceiveRoomList!(rooms)
                        }
                })
                
                // action response
                socket?.on(EventKey.roomActionResponse, callback: { (datas, ack) in
                        print("receive roomActionResponse : \(datas)")
                        // call when emit create or join room
                        let result = datas[0] as! Bool
                        let content = datas[1] as! [String : AnyObject]

                        if self.didReceiveRoomResponse != nil {
                                self.didReceiveRoomResponse!(result, content)
                        }
                })
                
                // call when user join or leave the chat room
                socket?.on(EventKey.usersDIdChange, callback: { (datas, ack) in
                        print("receive usersDIdChange : \(datas)")
                        let isJoin = datas[0] as! Bool  // true is join, false is leave
                        let user = datas[1] as! String
                        
                        if self.didReceiveUserChange != nil {
                                self.didReceiveUserChange!(isJoin, user)
                        }
                })
                
                // update chat room info
                socket?.on(EventKey.roomInfoDIdChange, callback: { (datas, ack) in
                        print("receive roomInfoDIdChange : \(datas)")
                        let room = datas[0] as! [String : AnyObject]
                        let info = RoomInfo.infoWith(data: room)
                        if self.didReceiveChatRoomInfoChange != nil {
                                self.didReceiveChatRoomInfoChange!(info)
                        }
                })
                
                // receive chat message
                socket?.on(EventKey.receiveMessage, callback: { (datas, ack) in
                        print("receiveMessage : \(datas[0])")
                        let receiveData = datas[0] as! Dictionary<String , AnyObject>
                        let info = MessageInfo(senderName: receiveData["senderName"] as! String,
                                                          senderID : receiveData["senderID"] as! String,
                                                          message: receiveData["message"]!,
                                                          date: receiveData["date"] as! String)
                        
                        if self.didReceiveMessage != nil {
                                self.didReceiveMessage!(info)
                        }
                })
        }
        
        private func listenConnectStatus() {
                socket?.on(SocketClientEvent.statusChange.rawValue, callback: { (datas, ack) in
                        let status = datas[0] as! SocketIOClientStatus
                        self.currentStatus = status.rawValue
                        switch status {
                        // The client has never been connected. Or the client has been reset.
                        case .notConnected:
                                print("notConnected")
                        // The client was once connected, but not anymore.
                        case .disconnected:
                                print("disconnected")
                        // The client is in the process of connecting.
                        case .connecting:
                                print("connecting")
                        // The client is currently connected.
                        case .connected:
                                print("connected")
                        }
                })
        }
        
        // MARK: - Socket IO Action
        func login(name : String, uuid : String) {
                statusObserver = self.observe(\.currentStatus, options: [.new, .old, .initial]) { (manager, changed) in
                        print(changed)
                        if changed.newValue == SocketIOClientStatus.connected.rawValue {
                                self.socket?.emit(EventKey.connectUser, name, uuid)
                                self.statusObserver?.invalidate()
                                self.statusObserver = nil
                        }
                }
        }
        
        func getUserList(completionHandler : @escaping ([UserInfo]) -> Void) {
                socket?.emit(EventKey.requestUserList)
                didReceiveUserList = completionHandler
        }
        
        func getRoomList(completionHandler : @escaping ([RoomInfo]) -> Void) {
                socket?.emit(EventKey.requestRoomList)
                didReceiveRoomList = completionHandler
        }
        
        func createNewRoom(creator : String ,roomName : String, password : String, completionHandler : @escaping (Bool, [String : AnyObject]) -> Void) {
                socket?.emit(EventKey.createRoom, creator, roomName, password)
                didReceiveRoomResponse = completionHandler
        }
        
        func joinRoom(user : String ,roomID : String, password : String, completionHandler : @escaping (Bool, [String : AnyObject]) -> Void) {
                socket?.emit(EventKey.askForJoinRoom, user, roomID, password)
                didReceiveRoomResponse = completionHandler
        }
        
        func leaveRoom(user : String ,roomID : String) {
                socket?.emit(EventKey.leaveRoom, user, roomID)
        }
        
        func chatUserDIdChange(completionHandler : @escaping (Bool, String) -> Void) {
                didReceiveUserChange = completionHandler
        }
        
        func stopListenChatUserDIdChange() {
                didReceiveUserChange = nil
        }
        
        func chatRoomInfoDidChange(completionHandler : @escaping (RoomInfo) -> Void) {
                didReceiveChatRoomInfoChange = completionHandler
        }
        
        func stopListenChatRoomInfo() {
                didReceiveChatRoomInfoChange = nil
        }
        
        func send(text : String, userID : String, name : String, roomID : String) {
                socket?.emit(EventKey.chatMessage, name, userID, text,  roomID)
        }
        
        // some day will support image
        func send(key : String, image : UIImage, from name : String, to roomID : String) {
                if let imageData = UIImageJPEGRepresentation(image, 0.7) {
                        socket?.emit(key, name, imageData, roomID)
                }
        }
        
        func receiveMessage(completionHandler : @escaping (MessageInfo) -> Void) {
                didReceiveMessage = completionHandler
        }
        
        func stopReceiveMessage() {
                didReceiveMessage = nil
        }
}

// MARK: - Socket key
struct EventKey {
        // user
        static let userList = "userList"
        static let requestUserList = "requestUserList"
        static let connectUser = "connectUser"
        
        // send & receive message
        static let chatMessage = "chatMessage"
        static let receiveMessage = "newChatMessage"
        
        // room request & response
        static let createRoom = "createRoom"
        static let requestRoomList = "requestRoomList"
        static let askForJoinRoom = "askForJoinRoom"
        static let leaveRoom = "leaveRoom"
        static let roomList = "roomList"
        static let roomActionResponse = "roomActionResponse"
        static let usersDIdChange = "usersDIdChange"  // call when someone join or leave the room
        static let roomInfoDIdChange = "roomInfoDIdChange" // call when the chat room info did change
}

// MARK: - Socket content struct
struct MessageInfo {
        let senderName : String
        let senderID : String // user UUID
        let message : AnyObject
        let date : String
}

struct UserInfo {
        let userID : String // user UUID
        let userName : String
        let socketID : String
        let isConnected : Bool
        
        static func infoWith(data : [String : AnyObject]) -> UserInfo {
                return UserInfo(userID: data["userID"] as! String,
                                       userName: data["nickname"] as! String,
                                       socketID: data["socketID"] as! String,
                                       isConnected: data["isConnected"]  as! Bool)
        }
}

struct RoomInfo {
        var roomUser : [[String : AnyObject]] // array with UserInfo dictionary data
        let roomName : String
        let password : String
        let roomID : String // decide by server
        
        static func infoWith(data : [String : AnyObject]) -> RoomInfo {
                return RoomInfo(roomUser: data["roomUser"] as! [[String : AnyObject]],
                                         roomName: data["roomName"] as! String,
                                         password: data["password"] as! String,
                                         roomID: data["roomID"] as! String)
        }
}
