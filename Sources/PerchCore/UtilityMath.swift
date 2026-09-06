import Foundation

/// A small arithmetic parser, never an expression evaluator or shell bridge.
public enum Calculator {
    public static func evaluate(_ expression: String) throws -> Double {
        guard expression.count <= 256 else { throw UtilityError.expressionTooLong }
        var parser = ArithmeticParser(expression)
        let result = try parser.sum()
        guard parser.index == parser.input.count else { throw UtilityError.invalidExpression }
        guard result.isFinite else { throw UtilityError.nonFinite }
        return result
    }
    public static func format(_ number: Double) -> String {
        number == 0 ? "0" : String(format: "%.12g", locale: Locale(identifier: "en_US_POSIX"), number)
    }
}

private struct ArithmeticParser {
    var input: [Character]
    var index = 0
    var depth = 0
    init(_ source: String) {
        input = Array(source.replacingOccurrences(of: "×", with: "*").replacingOccurrences(of: "÷", with: "/").replacingOccurrences(of: "−", with: "-").filter { !$0.isWhitespace })
    }
    mutating func take(_ character: Character) -> Bool {
        guard index < input.count, input[index] == character else { return false }; index += 1; return true
    }
    mutating func sum() throws -> Double {
        var value = try product()
        while true {
            if take("+") { value += try product() }
            else if take("-") { value -= try product() }
            else { return value }
        }
    }
    mutating func product() throws -> Double {
        var value = try unary()
        while true {
            if take("*") { value *= try unary() }
            else if take("/") { let divisor = try unary(); guard divisor != 0 else { throw UtilityError.divisionByZero }; value /= divisor }
            else { return value }
        }
    }
    mutating func unary() throws -> Double {
        depth += 1; defer { depth -= 1 }
        guard depth <= 32 else { throw UtilityError.expressionTooLong }
        if take("+") { return try unary() }
        if take("-") { return -(try unary()) }
        var value = try atom()
        while take("%") { value /= 100 }
        if take("^") { value = pow(value, try unary()) }
        return value
    }
    mutating func atom() throws -> Double {
        if take("(") { let value = try sum(); guard take(")") else { throw UtilityError.invalidExpression }; return value }
        let start = index
        while index < input.count && (input[index].isASCII && input[index].isNumber || input[index] == ".") { index += 1 }
        if index < input.count && (input[index] == "e" || input[index] == "E") {
            index += 1
            if index < input.count && (input[index] == "+" || input[index] == "-") { index += 1 }
            while index < input.count && input[index].isASCII && input[index].isNumber { index += 1 }
        }
        guard index > start, let value = Double(String(input[start..<index])) else { throw UtilityError.invalidExpression }
        guard value.isFinite else { throw UtilityError.nonFinite }
        return value
    }
}

public enum UnitCategory: String, CaseIterable, Codable, Sendable { case length = "Length", weight = "Weight", temperature = "Temperature", speed = "Speed", data = "Data", time = "Time" }
public struct ConversionUnit: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var category: UnitCategory
    public var factor: Double
    public var offset: Double = 0
    public static let all: [ConversionUnit] = [
        .init(id: "m", name: "Meters", category: .length, factor: 1), .init(id: "km", name: "Kilometers", category: .length, factor: 1000),
        .init(id: "cm", name: "Centimeters", category: .length, factor: 0.01), .init(id: "in", name: "Inches", category: .length, factor: 0.0254),
        .init(id: "ft", name: "Feet", category: .length, factor: 0.3048), .init(id: "mi", name: "Miles", category: .length, factor: 1609.344),
        .init(id: "kg", name: "Kilograms", category: .weight, factor: 1), .init(id: "g", name: "Grams", category: .weight, factor: 0.001),
        .init(id: "lb", name: "Pounds", category: .weight, factor: 0.45359237), .init(id: "oz", name: "Ounces", category: .weight, factor: 0.028349523125),
        .init(id: "°C", name: "Celsius", category: .temperature, factor: 1), .init(id: "°F", name: "Fahrenheit", category: .temperature, factor: 5 / 9, offset: -32 * 5 / 9),
        .init(id: "K", name: "Kelvin", category: .temperature, factor: 1, offset: -273.15),
        .init(id: "m/s", name: "Meters / second", category: .speed, factor: 1), .init(id: "km/h", name: "Kilometers / hour", category: .speed, factor: 1 / 3.6),
        .init(id: "mph", name: "Miles / hour", category: .speed, factor: 0.44704),
        .init(id: "B", name: "Bytes", category: .data, factor: 1), .init(id: "KB", name: "Kilobytes (1000)", category: .data, factor: 1000),
        .init(id: "MB", name: "Megabytes", category: .data, factor: 1_000_000), .init(id: "GB", name: "Gigabytes", category: .data, factor: 1_000_000_000),
        .init(id: "KiB", name: "Kibibytes (1024)", category: .data, factor: 1024), .init(id: "MiB", name: "Mebibytes", category: .data, factor: 1_048_576),
        .init(id: "s", name: "Seconds", category: .time, factor: 1), .init(id: "min", name: "Minutes", category: .time, factor: 60),
        .init(id: "h", name: "Hours", category: .time, factor: 3600), .init(id: "d", name: "Days (24 hours)", category: .time, factor: 86400)
    ]
    public static func convert(_ value: Double, from: String, to: String) throws -> Double {
        guard let source = all.first(where: { $0.id == from }), let target = all.first(where: { $0.id == to }), source.category == target.category else { throw UtilityError.incompatibleUnits }
        let result = (value * source.factor + source.offset - target.offset) / target.factor
        guard value.isFinite, result.isFinite else { throw UtilityError.nonFinite }; return result
    }
}
