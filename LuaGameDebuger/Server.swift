//
//  Server.swift
//  LuaGameDebuger
//
//  Created by 袁超 on 2019/5/11.
//  Copyright © 2019年 yuanchao. All rights reserved.
//

import Cocoa
import CocoaAsyncSocket

enum Command: Int {
    case startGame = 100
    case closeGame = 101
    case log = 102
    case requestResource = 103
    case responseResource = 104
    case requestAllJson = 105
    case responseAllJson = 106
}

class Server: NSObject, GCDAsyncSocketDelegate {
    
    var ip = ""
    let defaultPort: UInt16 = 8091
    
    var clientSocketArr = [GCDAsyncSocket]()
    var rwQueue = DispatchQueue(label: "com.server.rw")
    var socket: GCDAsyncSocket!
    
    var receivedMsgCallback:((IMMsgModel) -> Void)?
    
    var hasClientConnected: Bool {
        return !clientSocketArr.isEmpty
    }
    
    var needStart = false
    
    var receivedData: Data?
    let receivedDataQueue = DispatchQueue(label: "receivedData")
    var receivedAllJson: String?
    var headDict: Dictionary<String, Int>?
    
    static let shared = Server()
    
    private override init() {
        super.init()
        self.socket = GCDAsyncSocket(delegate: self, delegateQueue: rwQueue)
    }
    
    func start() {
        do {
            self.socket.disconnect()
            try self.socket.accept(onPort: defaultPort)
        } catch {
            print("开启失败：\(error.localizedDescription)")
        }
    }
    
    func sendMsg(_ msgModel:IMMsgModel) {
        guard let msg = msgModel.encode(), let bodyData = msg.data(using: String.Encoding.utf8) else {
            return
        }
        
        if msgModel.eventId == Command.requestAllJson.rawValue {
            self.receivedData = nil
            self.receivedAllJson = nil
        }
        
        var data = Data()
        let headDict = ["contentLength": bodyData.count]
        let headData = try! JSONSerialization.data(withJSONObject: headDict, options: JSONSerialization.WritingOptions.prettyPrinted)
        data.append(headData)
        data.append(GCDAsyncSocket.crlfData())
        data.append(bodyData)
        
        self.clientSocketArr.forEach({ $0.write(data, withTimeout: -1, tag: msgModel.eventId) })
    }
    
    // GCDAsyncSocketDelegate
    func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        print("didAcceptNewSocket")
        Dispatcher.postLog("已连接")
        self.clientSocketArr.append(newSocket)
        newSocket.readData(to: GCDAsyncSocket.crlfData(), withTimeout: -1, tag: 0)
    }
    
    func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        print("did write")
    }
    
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        print("did read:\n", String.init(data: data, encoding: String.Encoding.utf8) ?? "")
        guard let headDict = self.headDict else {
            guard let dict = (try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers)) as? Dictionary<String, Int> else {
                print("获取当前数据包head失败")
                return
            }
           
            let length = dict["contentLength"] ?? 0
            sock.readData(toLength: UInt(length), withTimeout: -1, tag: 0)
            self.headDict = dict
            print("获取当前数据包head成功")
            return
        }
        
        let length = headDict["contentLength"] ?? 0
        if length <= 0 || data.count != length {
            print("tcp recieve message err:当前数据包大小不正确")
            return
        }
        
        self.headDict = nil
        self.receivedData(data)
        
        sock.readData(to: GCDAsyncSocket.crlfData(), withTimeout: -1, tag: 0)
    }
    
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        Dispatcher.postLog("连接断开")
        if let index = self.clientSocketArr.firstIndex(of: sock) {
            self.clientSocketArr.remove(at: index)
        }
    }
    
}

extension Server {
   
    func receivedData(_ data:Data) {
        guard let msgModel = IMMsgModel.decode(json: data) else {
            print("解析成IMMsgModel失败")
            return
        }
        
        receivedMsgCallback?(msgModel)
    
    }
}

extension Server {
    
}

class IMMsgModel: BaseCodable {
    typealias E = IMMsgModel
    
    var eventId: Int = 0
    var data: String = ""
}
