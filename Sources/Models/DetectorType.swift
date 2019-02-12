/*
 MIT License

 Copyright (c) 2017-2018 MessageKit

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */

import Foundation

public enum DetectorType {

    case address
    case date
    case phoneNumber
    case url
    case transitInformation
    case tag

    // MARK: - Not supported yet

    //case mention
    //case custom
    init(textCheckingResult: NSTextCheckingResult) {
        switch textCheckingResult.resultType {
        case .address: self = .address
        case .date: self = .date
        case .phoneNumber: self = .phoneNumber
        case .link: self = .url
        case .transitInformation: self = .transitInformation
        case .regularExpression:
            if textCheckingResult.regularExpression?.pattern == DetectorType.tag.dataDetector.pattern {
                self = .tag
            } else {
                fatalError("unsupported NSTextCheckingResult.CheckingType provided to DetectorType initializer")
            }
        default:
            fatalError("unsupported NSTextCheckingResult.CheckingType provided to DetectorType initializer")
        }
    }
    
    internal var textCheckingType: NSTextCheckingResult.CheckingType {
        switch self {
        case .address: return .address
        case .date: return .date
        case .phoneNumber: return .phoneNumber
        case .url: return .link
        case .transitInformation: return .transitInformation
        case .tag: return .regularExpression
        }
    }
    
    private var isSupportedByNSDataDetector: Bool {
        switch self {
        case .address,
             .date,
             .phoneNumber,
             .url,
             .transitInformation:
            return true
        default:
            return false
        }
    }
    
    internal var dataDetector: NSDataDetector {
        switch self {
        case .address,
             .date,
             .phoneNumber,
             .url,
             .transitInformation:
            return try! NSDataDetector(types: self.textCheckingType.rawValue)
        case .tag:
            return try! NSRegularExpression(pattern: "\\B#\\w*[a-zA-Z]+\\w*", options: [])
        default:
            fatalError("unsupported DetectorType was used")
        }
    }
    
    static func getDataDetectors(detectorTypes: [DetectorType]) -> [NSDataDetector] {
        let detectors: [NSDataDetector] = []
        let nativeDetectorTypes = detectorTypes.filter({$0.isSupportedByNSDataDetector})
        let checkingTypes = nativeDetectorTypes.reduce(0) { $0 | $1.textCheckingType.rawValue }
        
        if let detector = try? NSDataDetector(types: checkingTypes) {
            detectors.append(detector)
        }
        
        let nonNativeDetectorTypes = detectorTypes.filter({!$0.isSupportedByNSDataDetector})
        
        for detectorType in nonNativeDetectorTypes {
            detectors.append(detectorType.dataDetector)
        }
        return detectors
    }
    

}
