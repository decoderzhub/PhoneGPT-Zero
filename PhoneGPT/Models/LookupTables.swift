import Accelerate
import Metal
import Foundation

class LookupTables {
    private var lookupTable: [Float]
    private var sqrtCache: [Float]
    private var logCache: [Float]
    private var factorialCache: [Float]
    
    init() {
        self.lookupTable = Array(repeating: 0, count: 65536)
        self.sqrtCache = (0..<100).map { Float(sqrt(Double($0))) }
        self.logCache = (1..<1000).map { Float(log2(Double($0))) }
        self.factorialCache = [1, 1, 2, 6, 24, 120, 720, 5040, 40320]
        
        buildLookupTable()
    }
    
    private func buildLookupTable() {
        for i in 0..<65536 {
            let packed = UInt16(i)
            let patternType = (packed >> 13) & 0x7
            let data = packed & 0x1FFF
            
            switch patternType {
            case 0: // Logarithmic
                let sign = (data >> 12) & 0x1
                let reciprocal = (data >> 11) & 0x1
                let logValue = Float(data & 0x7FF) / 256.0
                
                var value = exp2(logValue)
                if reciprocal == 1 {
                    value = 1.0 / value
                }
                if sign == 0 {
                    value = -value
                }
                lookupTable[i] = value
                
            case 1: // Square root
                let sign = (data >> 12) & 0x1
                let base = (data >> 5) & 0x7F
                let multiplier = data & 0x1F
                
                if Int(base) < sqrtCache.count {
                    let value = sqrtCache[Int(base)] * Float(multiplier)
                    lookupTable[i] = sign == 1 ? value : -value
                }
                
            case 2: // Factorial
                let sign = (data >> 12) & 0x1
                let n = (data >> 6) & 0x3F
                let m = data & 0x3F
                
                if n < factorialCache.count && m < factorialCache.count && m > 0 {
                    let value = factorialCache[Int(n)] / factorialCache[Int(m)]
                    lookupTable[i] = sign == 1 ? value : -value
                }
                
            default: // Fallback quantization
                let quantized = Float(data & 0xFF) / 127.0
                let scale = Float((data >> 8) & 0x1F)
                lookupTable[i] = quantized * pow(2, scale - 15)
            }
        }
    }
    
    func decompress(packedWeights: [UInt16]) -> [Float] {
        var output = [Float](repeating: 0, count: packedWeights.count)
        
        for i in 0..<packedWeights.count {
            output[i] = lookupTable[Int(packedWeights[i])]
        }
        
        return output
    }
    
    func decompressAsync(packedWeights: [UInt16], completion: @escaping ([Float]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let decompressed = self.decompress(packedWeights: packedWeights)
            DispatchQueue.main.async {
                completion(decompressed)
            }
        }
    }
}
