//
//  FileInfo.swift
//  LuaGameDebuger
//
//  Created by 袁超 on 2019/5/14.
//  Copyright © 2019年 yuanchao. All rights reserved.
//

import Cocoa

protocol BaseCodable: Codable {
    associatedtype E
    
}


class FileInfo: Codable {
    var filePath: String? // 相对路径
    var md5: String?
}

extension BaseCodable {
    static func decode(json: String) -> E? {
        let decoder = JSONDecoder()
        if let data = json.data(using: String.Encoding.utf8) {
            if let o = try? decoder.decode(Self.self, from: data) {
                return o as? E
            }
            return nil
        }
        return nil
    }
    
    func encode() -> String? {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(self) {
            return String.init(data: data, encoding: String.Encoding.utf8)
        }
        
        return nil;
    }
}

extension Array where Element: Codable {
    static func decode(json: String) -> [Element]? {
        let decoder = JSONDecoder()
        if let data = json.data(using: String.Encoding.utf8) {
            return try? decoder.decode([Element].self, from: data);
        }
        return nil
    }
    
    func encode() -> String? {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(self) {
            return String.init(data: data, encoding: String.Encoding.utf8)
        }
        
        return nil;
    }
}
