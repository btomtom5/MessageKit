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

import UIKit

open class MessageLabel: UILabel {

    // MARK: - Private Properties

    private lazy var layoutManager: NSLayoutManager = {
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(self.textContainer)
        return layoutManager
    }()

    private lazy var textContainer: NSTextContainer = {
        let textContainer = NSTextContainer()
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = self.numberOfLines
        textContainer.lineBreakMode = self.lineBreakMode
        textContainer.size = self.bounds.size
        return textContainer
    }()

    private lazy var textStorage: NSTextStorage = {
        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(self.layoutManager)
        return textStorage
    }()

    private lazy var rangesForDetectors: [DetectorType: [(NSRange, MessageTextCheckingType)]] = [:]
    
    private var isConfiguring: Bool = false

    // MARK: - Public Properties

    open weak var delegate: MessageLabelDelegate?

    open var enabledDetectors: [DetectorType] = [] {
        didSet {
            setTextStorage(attributedText, shouldParse: true)
        }
    }

    open override var attributedText: NSAttributedString? {
        didSet {
            setTextStorage(attributedText, shouldParse: true)
        }
    }

    open override var text: String? {
        didSet {
            setTextStorage(attributedText, shouldParse: true)
        }
    }

    open override var font: UIFont! {
        didSet {
            setTextStorage(attributedText, shouldParse: false)
        }
    }

    open override var textColor: UIColor! {
        didSet {
            setTextStorage(attributedText, shouldParse: false)
        }
    }

    open override var lineBreakMode: NSLineBreakMode {
        didSet {
            textContainer.lineBreakMode = lineBreakMode
            if !isConfiguring { setNeedsDisplay() }
        }
    }

    open override var numberOfLines: Int {
        didSet {
            textContainer.maximumNumberOfLines = numberOfLines
            if !isConfiguring { setNeedsDisplay() }
        }
    }

    open override var textAlignment: NSTextAlignment {
        didSet {
            setTextStorage(attributedText, shouldParse: false)
        }
    }

    open var textInsets: UIEdgeInsets = .zero {
        didSet {
            if !isConfiguring { setNeedsDisplay() }
        }
    }

    open override var intrinsicContentSize: CGSize {
        var size = super.intrinsicContentSize
        size.width += textInsets.horizontal
        size.height += textInsets.vertical
        return size
    }
    
    internal var messageLabelFont: UIFont?

    private var attributesNeedUpdate = false

    public static var defaultAttributes: [NSAttributedString.Key: Any] = {
        return [
            NSAttributedString.Key.foregroundColor: UIColor.darkText,
            NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue,
            NSAttributedString.Key.underlineColor: UIColor.darkText
        ]
    }()

    open internal(set) var addressAttributes: [NSAttributedString.Key: Any] = defaultAttributes

    open internal(set) var dateAttributes: [NSAttributedString.Key: Any] = defaultAttributes

    open internal(set) var phoneNumberAttributes: [NSAttributedString.Key: Any] = defaultAttributes

    open internal(set) var urlAttributes: [NSAttributedString.Key: Any] = defaultAttributes
    
    open internal(set) var transitInformationAttributes: [NSAttributedString.Key: Any] = defaultAttributes
    
    open internal(set) var tagAttributes: [NSAttributedString.Key: Any] = defaultAttributes

    public func setAttributes(_ attributes: [NSAttributedString.Key: Any], detector: DetectorType) {
        switch detector {
        case .phoneNumber:
            phoneNumberAttributes = attributes
        case .address:
            addressAttributes = attributes
        case .date:
            dateAttributes = attributes
        case .url:
            urlAttributes = attributes
        case .transitInformation:
            transitInformationAttributes = attributes
        case .tag:
            tagAttributes = attributes
        }
        if isConfiguring {
            attributesNeedUpdate = true
        } else {
            updateAttributes(for: [detector])
        }
    }

    // MARK: - Initializers

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }

    // MARK: - Open Methods

    open override func drawText(in rect: CGRect) {

        let insetRect = rect.inset(by: textInsets)
        textContainer.size = CGSize(width: insetRect.width, height: rect.height)

        let origin = insetRect.origin
        let range = layoutManager.glyphRange(for: textContainer)

        layoutManager.drawBackground(forGlyphRange: range, at: origin)
        layoutManager.drawGlyphs(forGlyphRange: range, at: origin)
    }

    // MARK: - Public Methods
    
    public func configure(block: () -> Void) {
        isConfiguring = true
        block()
        if attributesNeedUpdate {
            updateAttributes(for: enabledDetectors)
        }
        attributesNeedUpdate = false
        isConfiguring = false
        setNeedsDisplay()
    }

    // MARK: - Private Methods

    private func setTextStorage(_ newText: NSAttributedString?, shouldParse: Bool) {

        guard let newText = newText, newText.length > 0 else {
            textStorage.setAttributedString(NSAttributedString())
            setNeedsDisplay()
            return
        }
        
        let style = paragraphStyle(for: newText)
        let range = NSRange(location: 0, length: newText.length)
        
        let mutableText = NSMutableAttributedString(attributedString: newText)
        mutableText.addAttribute(.paragraphStyle, value: style, range: range)
        
        if shouldParse {
            rangesForDetectors.removeAll()
            let results = parse(text: mutableText)
            setRangesForDetectors(in: results)
        }
        
        for (detector, rangeTuples) in rangesForDetectors {
            if enabledDetectors.contains(detector) {
                let attributes = detectorAttributes(for: detector)
                rangeTuples.forEach { (range, _) in
                    mutableText.addAttributes(attributes, range: range)
                }
            }
        }

        let modifiedText = NSAttributedString(attributedString: mutableText)
        textStorage.setAttributedString(modifiedText)

        if !isConfiguring { setNeedsDisplay() }

    }
    
    private func paragraphStyle(for text: NSAttributedString) -> NSParagraphStyle {
        guard text.length > 0 else { return NSParagraphStyle() }
        
        var range = NSRange(location: 0, length: text.length)
        let existingStyle = text.attribute(.paragraphStyle, at: 0, effectiveRange: &range) as? NSMutableParagraphStyle
        let style = existingStyle ?? NSMutableParagraphStyle()
        
        style.lineBreakMode = lineBreakMode
        style.alignment = textAlignment
        
        return style
    }

    private func updateAttributes(for detectors: [DetectorType]) {

        guard let attributedText = attributedText, attributedText.length > 0 else { return }
        let mutableAttributedString = NSMutableAttributedString(attributedString: attributedText)

        for detector in detectors {
            guard let rangeTuples = rangesForDetectors[detector] else { continue }

            for (range, _)  in rangeTuples {
                let attributes = detectorAttributes(for: detector)
                mutableAttributedString.addAttributes(attributes, range: range)
            }

            let updatedString = NSAttributedString(attributedString: mutableAttributedString)
            textStorage.setAttributedString(updatedString)
        }
    }

    private func detectorAttributes(for detectorType: DetectorType) -> [NSAttributedString.Key: Any] {

        switch detectorType {
        case .address:
            return addressAttributes
        case .date:
            return dateAttributes
        case .phoneNumber:
            return phoneNumberAttributes
        case .url:
            return urlAttributes
        case .transitInformation:
            return transitInformationAttributes
        case .tag:
            return tagAttributes
        }

    }

//    private func detectorAttributes(for checkingResultType: NSTextCheckingResult.CheckingType) -> [NSAttributedString.Key: Any] {
//        switch checkingResultType {
//        case .address:
//            return addressAttributes
//        case .date:
//            return dateAttributes
//        case .phoneNumber:
//            return phoneNumberAttributes
//        case .link:
//            return urlAttributes
//        case .transitInformation:
//            return transitInformationAttributes
//        default:
//            fatalError(MessageKitError.unrecognizedCheckingResult)
//        }
//    }
    
    private func setupView() {
        numberOfLines = 0
        lineBreakMode = .byWordWrapping
    }

    // MARK: - Parsing Text

    private func parse(text: NSAttributedString) -> [NSTextCheckingResult] {
        guard enabledDetectors.isEmpty == false else { return [] }

        var matches: [NSTextCheckingResult] = []
        let detectors = DetectorType.getDataDetectors(detectorTypes: enabledDetectors)
        let range = NSRange(location: 0, length: text.length)
        
        for detector in detectors {
            let currMatches: [NSTextCheckingResult] = detector.matches(in: text.string, options: [], range: range)
            matches += currMatches
        }

        guard enabledDetectors.contains(.url) else {
            return matches
        }

        // Enumerate NSAttributedString NSLinks and append ranges
        var results: [NSTextCheckingResult] = matches

        text.enumerateAttribute(NSAttributedString.Key.link, in: range, options: []) { value, range, _ in
            guard let url = value as? URL else { return }
            let result = NSTextCheckingResult.linkCheckingResult(range: range, url: url)
            results.append(result)
        }

        return results
    }

    private func setRangesForDetectors(in checkingResults: [NSTextCheckingResult]) {

        guard checkingResults.isEmpty == false else { return }
        
        for result in checkingResults {
            let detector = DetectorType(textCheckingResult: result)
            var ranges = rangesForDetectors[detector] ?? []
            switch detector {
            case .address:
                let tuple: (NSRange, MessageTextCheckingType) = (result.range, .addressComponents(result.addressComponents))
                ranges.append(tuple)
                rangesForDetectors.updateValue(ranges, forKey: detector)
            case .date:
                let tuple: (NSRange, MessageTextCheckingType) = (result.range, .date(result.date))
                ranges.append(tuple)
                rangesForDetectors.updateValue(ranges, forKey: detector)
            case .phoneNumber:
                let tuple: (NSRange, MessageTextCheckingType) = (result.range, .phoneNumber(result.phoneNumber))
                ranges.append(tuple)
                rangesForDetectors.updateValue(ranges, forKey: detector)
            case .url:
                let tuple: (NSRange, MessageTextCheckingType) = (result.range, .link(result.url))
                ranges.append(tuple)
                rangesForDetectors.updateValue(ranges, forKey: detector)
            case .transitInformation:
                let tuple: (NSRange, MessageTextCheckingType) = (result.range, .transitInfoComponents(result.components))
                ranges.append(tuple)
                rangesForDetectors.updateValue(ranges, forKey: detector)
            case .tag:
//                let tagString = String(attributedText![Range(result.range, in: attributedText)!])
                let tagString = "WombatLove"
                let tuple: (NSRange, MessageTextCheckingType) = (result.range, .tag(tagString))
                ranges.append(tuple)
                rangesForDetectors.updateValue(ranges, forKey: detector)

            default:
                fatalError("Received an unrecognized NSTextCheckingResult.CheckingType")
            }

        }

    }

    // MARK: - Gesture Handling

    private func stringIndex(at location: CGPoint) -> Int? {
        guard textStorage.length > 0 else { return nil }

        var location = location

        location.x -= textInsets.left
        location.y -= textInsets.top

        let index = layoutManager.glyphIndex(for: location, in: textContainer)

        let lineRect = layoutManager.lineFragmentUsedRect(forGlyphAt: index, effectiveRange: nil)
        
        var characterIndex: Int?
        
        if lineRect.contains(location) {
            characterIndex = layoutManager.characterIndexForGlyph(at: index)
        }
        
        return characterIndex

    }

  open func handleGesture(_ touchLocation: CGPoint) -> Bool {

        guard let index = stringIndex(at: touchLocation) else { return false }

        for (detectorType, ranges) in rangesForDetectors {
            for (range, value) in ranges {
                if range.contains(index) {
                    handleGesture(for: detectorType, value: value)
                    return true
                }
            }
        }
        return false
    }

    private func handleGesture(for detectorType: DetectorType, value: MessageTextCheckingType) {
        
        switch value {
        case let .addressComponents(addressComponents):
            var transformedAddressComponents = [String: String]()
            guard let addressComponents = addressComponents else { return }
            addressComponents.forEach { (key, value) in
                transformedAddressComponents[key.rawValue] = value
            }
            handleAddress(transformedAddressComponents)
        case let .phoneNumber(phoneNumber):
            guard let phoneNumber = phoneNumber else { return }
            handlePhoneNumber(phoneNumber)
        case let .date(date):
            guard let date = date else { return }
            handleDate(date)
        case let .link(url):
            guard let url = url else { return }
            handleURL(url)
        case let .transitInfoComponents(transitInformation):
            var transformedTransitInformation = [String: String]()
            guard let transitInformation = transitInformation else { return }
            transitInformation.forEach { (key, value) in
                transformedTransitInformation[key.rawValue] = value
            }
            handleTransitInformation(transformedTransitInformation)
        case let .tag(tag):
            guard let tag = tag else { return }
            handleTag(tag)
        }
    }
    
    private func handleAddress(_ addressComponents: [String: String]) {
        delegate?.didSelectAddress(addressComponents)
    }
    
    private func handleDate(_ date: Date) {
        delegate?.didSelectDate(date)
    }
    
    private func handleURL(_ url: URL) {
        delegate?.didSelectURL(url)
    }
    
    private func handlePhoneNumber(_ phoneNumber: String) {
        delegate?.didSelectPhoneNumber(phoneNumber)
    }
    
    private func handleTransitInformation(_ components: [String: String]) {
        delegate?.didSelectTransitInformation(components)
    }
    
    private func handleTag(_ tag: String) {
        delegate?.didSelectTag(tag)
    }
    
}

private enum MessageTextCheckingType {
    case addressComponents([NSTextCheckingKey: String]?)
    case date(Date?)
    case phoneNumber(String?)
    case link(URL?)
    case transitInfoComponents([NSTextCheckingKey: String]?)
    case tag(String?)
}
