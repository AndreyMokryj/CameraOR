//
//  Api.swift
//  CameraOR
//
//  Created by Andrew Mokryj on 09.11.2022.
//

import Foundation
import UIKit


private let clientId = "lie6eh75pvj68xs81vs4rdt5kkybac5x"
private let clientSecret = "jtv67z57mqwr1a9zsuebq8l7o8mtiwucpmnf2m12qli1h239bzifyu7a7niycbpp"

private let connectUrl = "https://www.nyckel.com/connect/token"
private let locateUrl = "https://www.nyckel.com/v0.9/functions/4lf52bx37yjbem8e/locate"

private var accessToken:String? = nil

func createAccessToken() -> String? {
    let url = URL(string: connectUrl)!
    var request = URLRequest(url: url)
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.httpMethod = "POST"
    
    let parameters: [String: Any] = [
        "client_id": clientId,
        "client_secret": clientSecret,
        "grant_type": "client_credentials"
    ]
    request.httpBody = parameters.percentEncoded()
    
    var done = false
    let task = URLSession.shared.dataTask(with: url) { data, response, error in
        if let data = data {
            if let data = try? JSONDecoder().decode(ResponseObject<CreateTokenResponse>.self, from: data) {
                print(data.form.access_token)
                accessToken = data.form.access_token
            } else {
                print("Invalid Response")
            }
        } else if let error = error {
            print("HTTP Request Failed \(error)")
        }
        done = true
    }
    task.resume()
    repeat {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
    } while !done
    
    return accessToken
}

func locatePoints(image: UIImage) -> [[String:Float]]? {
    var _points:[[String:Float]]? = []
    
    let boundary = UUID().uuidString
    let paramName = "data"
    let fileName = "frame.png"

    let url = URL(string: locateUrl)!
    var request = URLRequest(url: url)
    request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    request.httpMethod = "POST"
    
    var data = Data()

    // Add the image data to the raw http request data
    data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
    data.append("Content-Disposition: form-data; name=\"\(paramName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
    data.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
    data.append(image.pngData()!)

    data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

    request.httpBody = data
    
    var done = false
    let task = URLSession.shared.dataTask(with: url) { responseData, response, error in
        if error == nil {
//            if let data = try? JSONDecoder().decode(ResponseObject<CreateTokenResponse>.self, from: data) {
//                print(data.form.access_token)
//                accessToken = data.form.access_token
//            } else {
//                print("Invalid Response")
//            }
            
            let jsonData = try? JSONSerialization.jsonObject(with: responseData!, options: .allowFragments)
            if let json = jsonData as? [[String: Any]] {
                print(json)
                
                /// TODO: Extract points
                _points = json[0]["points"] as! [[String:Float]]
            }
        } else if let error = error {
            print("HTTP Request Failed \(error)")
            _points = nil
        }
        done = true
    }
    task.resume()
    repeat {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
    } while !done
    
    print("aaa")
    return _points
}

extension Dictionary {
    func percentEncoded() -> Data? {
        map { key, value in
            let escapedKey = "\(key)".addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
            let escapedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
            return escapedKey + "=" + escapedValue
        }
        .joined(separator: "&")
        .data(using: .utf8)
    }
}

extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        let generalDelimitersToEncode = ":#[]@" // does not include "?" or "/" due to RFC 3986 - Section 3.4
        let subDelimitersToEncode = "!$&'()*+,;="
        
        var allowed: CharacterSet = .urlQueryAllowed
        allowed.remove(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")
        return allowed
    }()
}

struct ResponseObject<T: Decodable>: Decodable {
    let form: T    // often the top level key is `data`, but in the case of https://httpbin.org, it echos the submission under the key `form`
}

struct CreateTokenResponse: Decodable {
    let access_token: String
    let token_type: String
    let expires_in: Int64
}

struct LocatedPoint: Decodable {
    let x: Float
    let y: Float
    let confidence: Float
}
