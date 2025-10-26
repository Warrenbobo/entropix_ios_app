//
//  ObjectExtensions.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import Foundation
import UIKit

extension UIColor {
    
    
    /// 字符串格式化颜色
    static func hexColor(_ hex: String,
                         alpha: CGFloat = 1) -> UIColor {
        var colorString = hex
        if let splitString = hex.split(separator: "#").last {
            colorString = String(splitString)
        }
        var value: Int64 = 0
        let scanner = Scanner(string: colorString)
        scanner.scanHexInt64(&value)
        let redHex = CGFloat(value >> 16 & 0x000000FF) / 255
        let greenHex = CGFloat(value >> 8 & 0x000000FF) / 255
        let blueHex = CGFloat(value & 0x000000FF) / 255
        return UIColor(red: redHex,
                       green: greenHex,
                       blue: blueHex,
                       alpha: alpha)
    }
}


extension UIView {
    
    /// 设置View的渐变色
    func setGradient(colors: [UIColor],
                  locations: [NSNumber] = [0, 1],
                  startPoint: CGPoint = CGPoint.zero,
                  endPoint: CGPoint = CGPoint(x: 0, y: 1)) {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = colors.map({ $0.cgColor })
        gradientLayer.frame = bounds
        gradientLayer.locations = locations
        gradientLayer.startPoint = startPoint
        gradientLayer.endPoint = endPoint
        layer.insertSublayer(gradientLayer, at: 0)
    }
    
    /// 设置View的部分圆角
    func setCorners(_ corners: UIRectCorner,
                    with radii: CGFloat) {
        let radiiSize = CGSize(width: radii, height: radii)
        let maskPath = UIBezierPath(roundedRect: bounds,
                                    byRoundingCorners: corners,
                                    cornerRadii: radiiSize)
        let maskLayer = CAShapeLayer()
        maskLayer.frame = bounds
        maskLayer.path = maskPath.cgPath
        layer.mask = maskLayer
    }
    
    /// 截图view中的内容
    func snapshot() -> UIImage? {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { context in
            layer.render(in: context.cgContext)
        }
    }
}

extension Int {
    
    /// 屏幕宽度自适应
    var fit: CGFloat {
        return CGFloat(self) * (UIScreen.main.bounds.width / 375)
    }
}

extension CGFloat {
    
    /// 屏幕宽度自适应
    var fit: CGFloat {
        return self * (UIScreen.main.bounds.width / 375)
    }
}

extension Date {
    
    /// 时间对象转为字符串格式
    func text(_ formatter: String = "HH:mm:ss.S") -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.locale = customLocal
        timeFormatter.dateFormat = formatter
        return timeFormatter.string(from: self)
    }
    
    /// 是否是同一天的日期
    func samelyDay(_ date: Date) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = NSTimeZone.local
        calendar.locale = Locale(identifier: "zh_CN")
        let unitFlags: Set<Calendar.Component> = [.year, .month, .day,]
        let component1 = calendar.dateComponents(unitFlags, from: self)
        let component2 = calendar.dateComponents(unitFlags, from: date)
        return component1.year == component2.year &&
        component1.month == component2.month &&
        component1.day == component2.day
    }
    
    /// 获取时间加减后的目标时间，单位Hour
    func offset(_ hour: Int, round: Bool = true) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = NSTimeZone.local
        calendar.locale = customLocal
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: self)
        let currentHour = components.hour ?? 0
        let currentMinute = components.minute ?? 0
        let currentSecond = components.second ?? 0
        var nextHour = currentHour
        if currentMinute > 0 || currentSecond > 0 {
            nextHour += hour
        }
        let nextFullHourDateComponents = DateComponents(year: components.year,
                                                        month: components.month,
                                                        day: components.day,
                                                        hour: nextHour,
                                                        minute: round ? 0 : components.minute ?? 0,
                                                        second: round ? 0 : components.second ?? 0)
        return calendar.date(from: nextFullHourDateComponents) ?? self
    }
    
    /// 获取两个时间中间相差的时分秒毫秒数
    func offsetText(to date: Date, _ format: String = "HH:mm:ss.S") -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = NSTimeZone.local
        calendar.locale = customLocal
        let components = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: self, to: date)
        return calendar.date(from: components)?.text(format) ?? ""
    }
    
    /// 获取两个日期对象的差值
    func offset(to date: Date, _ components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second, .nanosecond]) -> DateComponents {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = NSTimeZone.local
        calendar.locale = customLocal
        return calendar.dateComponents(components,
                                       from: self,
                                       to: date)
    }
    
    /// 获取当前日期的组合对象
    func toComponents() -> DateComponents {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = NSTimeZone.local
        calendar.locale = customLocal
        return calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .weekday], from: self)
    }
    
    /// 根据日期文本将时间转为Date格式
    static func dateFrom(text: String,
                       formatter: String = "HH:mm:ss") -> Date? {
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "zh_Hans_CN")
        timeFormatter.dateFormat = formatter
        return timeFormatter.date(from: text)
    }
    
    /// Date对象转为时间戳
    func toValue() -> TimeInterval {
        return timeIntervalSince1970
    }
    
    /// 获取某个时间偏移后的目标时间
    func offsetWithComponents(_ components: DateComponents) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = NSTimeZone.local
        calendar.locale = customLocal
        return calendar.date(byAdding: components, to: self)
    }
    
    /// 获取某个日期凌晨的时间，即某天的开始时间
    func startDate() -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = NSTimeZone.local
        calendar.locale = customLocal
        let components = calendar.dateComponents([.year,.month,.day], from: self)
        return calendar.date(from: components)
    }
    
    /// 判断某个时间对象是否应该显示为一天，一周，一月，一年前的样式
    func chineseFormatText() -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = NSTimeZone.local
        calendar.locale = customLocal
        let currentDate = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second],
                                                 from: currentDate,
                                                 to: self)
        let yearMargin = components.year ?? 0
        let monthMargin = components.month ?? 0
        let dayMargin = components.day ?? 0
        if yearMargin > 0 {
            return "\(yearMargin)年后"
        } else if monthMargin > 0 {
            return "\(monthMargin)月后"
        } else if dayMargin > 0 {
            return "\(dayMargin)天后"
        } else {
            return currentDate.offsetText(to: self, "HH:mm:ss")
        }
    }
    
    /// 当前是星期几
    func chineseWeekday() -> Int {
        var calendar = Calendar(identifier: .gregorian)
        let timeZone = TimeZone(identifier: "Asia/Shanghai")
        calendar.timeZone = timeZone!
        let weekdayValue = calendar.dateComponents([.weekday], from: self).weekday ?? 1
        return weekdayValue - 1
    }
    
    /// 将时间戳转为格式化时间
    static func toDateText(with timestamp: Int,
                           _ formatter: String = "yyyy.MM.dd") -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = formatter
        dateFormatter.timeZone = TimeZone.current
        return dateFormatter.string(from: date)
    }
    
    private var customLocal: Locale { return Locale(identifier: "zh_Hans_CN") }
}

extension Notification.Name {
    
    /// 用户数据发生变化通知
    static let userModelValueChanged = Notification.Name("UserModelValueChanged")
    
    /// 设备资源使用情况刷新
    static let resourceUsageChanged = Notification.Name("DeviceResourceUsageValueChanged")
}

extension String {
    
    /// 更改placeholder的样式
    var placeholder: NSAttributedString {
        return NSAttributedString(string: self,
                                  attributes: [.foregroundColor: AppTheme.ThemeColor.placeholder,
                                               .font: UIFont.systemFont(ofSize: 14)])
    }
    
    /// 生成事件的唯一id
    static func eventId() -> NSNumber {
        let timestamp = String(format: "%.f", Date().timeIntervalSince1970)
        let idString = timestamp[timestamp.index(timestamp.startIndex, offsetBy: 5)..<timestamp.endIndex]
        let idValue = Int(idString)!
        let random = Int.random(in: 100..<999)
        return NSNumber(value: idValue + random)
    }
    
    /// 获取随机长度的数字字符串
    static func randomChar(_ length: Int) -> String {
        guard length > 0 else { return "" }
        let base = "0123456789"
        var randomString = ""
        for _ in 0..<length {
            guard let randomCharacter = base.randomElement() else { continue }
            randomString.append(randomCharacter)
        }
        return randomString
    }
}

extension UIFont {
    
    /// 输出系统字体
    static func printSystemFonts() {
        let fontFamilies = UIFont.familyNames
        for familyName in fontFamilies {
            let fontNames = UIFont.fontNames(forFamilyName: familyName)
            print("Font Family: \(familyName)")
            for fontName in fontNames {
                print(" ---- \(fontName)")
            }
        }
    }
}

extension UIButton {
    
    /// 修改Button的图片和文字位置
    /// 以文字作为参照物
    /// #一定要在设置完button的字体属性后再使用本方法，否则会导致文字的宽度计算不正确
    func adjust(image: UIImage?,
                title: String?,
                titlePosition: UIView.ContentMode,
                additionalSpacing: CGFloat = 0,
                state: UIControl.State) {
        self.setImage(image, for: state)
        self.setTitle(title, for: state)
        guard let titleText = title else {
            return
        }
        adjustContentViews(title: titleText,
                           position: titlePosition,
                           spacing: additionalSpacing)
    }
    
    private func adjustContentViews(title: String,
                                    position: UIView.ContentMode,
                                    spacing: CGFloat) {
        
        let imageSize = imageView?.intrinsicContentSize ?? CGSize.zero
        let textSize = titleLabel?.intrinsicContentSize ?? CGSize.zero

        var titleInsets: UIEdgeInsets
        var imageInsets: UIEdgeInsets
        
        switch position {
        case .top:       //文字在上 图片在下
            titleInsets = UIEdgeInsets(top: 0,
                                       left: -imageSize.width,
                                       bottom: imageSize.height + spacing,
                                       right: 0)
            imageInsets = UIEdgeInsets(top: textSize.height + spacing,
                                       left: 0,
                                       bottom: 0,
                                       right: -textSize.width)
        case .bottom:     //文字在下 图片在上
            titleInsets = UIEdgeInsets(top: imageSize.height + spacing,
                                       left: -imageSize.width,
                                       bottom: 0,
                                       right: 0)
            imageInsets = UIEdgeInsets(top: 0,
                                       left: 0,
                                       bottom: textSize.height + spacing,
                                       right: -textSize.width)
        case .left:       //文字在左 图片在右
            titleInsets = UIEdgeInsets(top: 0,
                                       left: -imageSize.width - spacing / 2,
                                       bottom: 0,
                                       right: imageSize.width + spacing / 2)
            imageInsets = UIEdgeInsets(top: 0,
                                       left: textSize.width + spacing / 2,
                                       bottom: 0,
                                       right: -textSize.width - spacing / 2)
        case .right:      //文字在右 图片在左
            titleInsets = UIEdgeInsets(top: 0,
                                       left: spacing / 2,
                                       bottom: 0,
                                       right: -spacing / 2)
            imageInsets = UIEdgeInsets(top: 0,
                                       left: -spacing / 2,
                                       bottom: 0,
                                       right: spacing / 2)
        default:
            titleInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            imageInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        }
        self.titleEdgeInsets = titleInsets
        self.imageEdgeInsets = imageInsets
    }
}
