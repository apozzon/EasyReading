//
//  ViewController.swift
//  EasyReading
//
//  Created by Andrea on 29/01/24.
//
/*
 
    This app is reading a text placed in a text view in any language that the system recognize. In case of problems, IT,EN,FR and ES can be chosen overcoming the automatic language recognition.
 
    Text can be inserted in the UITextView by copying and paste or opening files in text format, pdf or HTML.
    
    The last read text is saved in the core data with the pointer where it was interrupted. Reading can be restarted from there if the correspondent switch is on.
 
    It is also possible to select just a piece of the text.
 
 
 */

import UIKit
import AVFoundation
//import MobileCoreServices
import PDFKit
import NaturalLanguage


class ViewController: UIViewController, UIDocumentPickerDelegate, AVSpeechSynthesizerDelegate {
    
    // file manager to open files and store URL
    let fileManager = FileManager.default
    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    // the voice synthetizer
    let synthetizer = AVSpeechSynthesizer()
    
    // it is retaining the full text that was copied in the text view.
    var fullText = ""
    
    // the pointer to the last word read by the synthetizer
    var pointer: Int64 = 0

    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        synthetizer.delegate = self
  
        // add the buttons to the toolbar
        setupToolBar()

        // load into the last saved text into the view
        let txt = CdC.shared.loadText()
        
        fullText = txt.last?.lastText ?? "No text saved"
        textToRead.text = fullText
        pointer = txt.last?.lastPosition ?? 0
        
        // if the swithch was set on (read from last point) when finished, it has to be reset to on
        if txt.last?.fromLastPoint == true {
            saveFromLastRead.setOn(true, animated: true)
        }
        
       
        // require to avoid problems at the first start because the pointer is at the end of the file
        textToRead.selectedTextRange = textToRead.textRange(from: textToRead.beginningOfDocument, to: textToRead.endOfDocument)
 
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)

        saveText()
    }
    
    // the language set in the segmented control (can be automatic detection)
    @IBOutlet weak var language: UISegmentedControl!
    
    // the text to be read. It may come from file of copied in
    @IBOutlet weak var textToRead: UITextView!
    
    // shows the detecetd language
    @IBOutlet weak var detectedIdiom: UILabel!
    
    // toggle if to read from the last poin (on) or beginning (off)
    @IBOutlet weak var saveFromLastRead: UISwitch!
    
    /*
     ----------------------------------------------------------------------------
     MARK: Pause the synthetizer
     ----------------------------------------------------------------------------
     */
    
    @IBAction func pause(_ sender: Any) {
        
        if  synthetizer.isPaused{
            synthetizer.continueSpeaking()
            
        } else {
            synthetizer.pauseSpeaking(at: AVSpeechBoundary.immediate)
            
        }
    }
    
    /*
     ----------------------------------------------------------------------------
     MARK: Clean up the text view
     ----------------------------------------------------------------------------
     */
    
    @IBAction func eraseAll(_ sender: Any) {
        // show an alert message
        let ac = UIAlertController(title: "ATTENTION!", message:  "Erasing all text. Are you sure?", preferredStyle: UIAlertController.Style.alert)
        // add the actions (buttons)
        ac.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel, handler: nil))
        ac.addAction(UIAlertAction(title: "Erase", style: UIAlertAction.Style.destructive, handler: { [self] action in
            textToRead.text = ""
            saveText()
        }))
        // show the alert
        self.present(ac, animated: true, completion: nil)
    }
    
    /*
     ----------------------------------------------------------------------------
     MARK: Stop reading the text
     ----------------------------------------------------------------------------
     */
    
    @IBAction func stop(_ sender: Any) {
        // show an alert message
        let ac = UIAlertController(title: "ATTENTION!", message:  "Reading will restart from beginning. Are you sure?", preferredStyle: UIAlertController.Style.alert)
        // add the actions (buttons)
        ac.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel, handler: nil))
        ac.addAction(UIAlertAction(title: "Stop", style: UIAlertAction.Style.destructive, handler: { [self] action in
            synthetizer.stopSpeaking(at: AVSpeechBoundary.immediate)
            textToRead.text = fullText
        }))
        // show the alert
        self.present(ac, animated: true, completion: nil)
    }
    
    /*
     ----------------------------------------------------------------------------
     MARK: Start reading the text
     ----------------------------------------------------------------------------
     */

    @IBAction func startReading(_ sender: Any) {
        // initialize the text to be read depending on the switch (on = from last word read, off = all text)
        calculateRange()
        let range = textToRead.selectedTextRange
        let string = textToRead.text(in: range!)
        
        // this save is redundand but better to be safe
        saveText()
        
        // start reading the text
        speakPlease(string!)
    }
    
    /*
     ----------------------------------------------------------------------------
     MARK: Activate the speach synthetizer
     ----------------------------------------------------------------------------
     */
    
    func speakPlease(_ text: String) {
        // increase the text size just to show that reading i starting (it can take time due to the lenght of the string and the iPhione in use)
        textToRead.font = UIFont(name: "HelveticaNeue", size: 18.0)
        // load the speach into the synthetizer
        let utterance = AVSpeechUtterance(string: text)
        
        // check the language of the text automatically (0) of set the language manually
        let l = language.selectedSegmentIndex
        let lang = switch l {
        case 0 : detectedLanguage(for: text)
        case 1 : "it-IT"
        case 2 : "en-US"
        case 3 : "fr-FR"
        case 4 : "es-ES"
        default: "en-EN"
        }
        
        //use the voice accordingly to the chosen language
        utterance.voice = AVSpeechSynthesisVoice(language: lang)
        
        // SPEAK!!!
        synthetizer.speak(utterance)
    }
    
    /*
     ----------------------------------------------------------------------------
     MARK: open the file manager
     ----------------------------------------------------------------------------
     */
    
    @IBAction func fileRetrieve(_ sender: Any) {
        // show an alert message
        let ac = UIAlertController(title: "ATTENTION!", message:  "The text to be read will be cancelled and replaced. Are you sure?", preferredStyle: UIAlertController.Style.alert)
        // add the actions (buttons)
        ac.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel, handler: nil))
        ac.addAction(UIAlertAction(title: "Proceed", style: UIAlertAction.Style.destructive, handler: { [self] action in
            // stop the synthetizer
            synthetizer.stopSpeaking(at: AVSpeechBoundary.immediate)
            // filter only the file that can be opened
            let supportedTypes: [UTType] = [UTType.text, UTType.pdf, UTType.html]
            let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
            documentPicker.delegate = self
            documentPicker.allowsMultipleSelection = false
            documentPicker.shouldShowFileExtensions = true
            self.present(documentPicker, animated: true, completion: nil)
        }))
        // show the alert
        self.present(ac, animated: true, completion: nil)
    }
    
    /*
     ----------------------------------------------------------------------------
     MARK: Retrive a new file and load it
     ----------------------------------------------------------------------------
     */
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {

        //we get only one file at a time
        guard let url = urls.first else { return } // url of picked file
        
        // extension of the file
        let type: String = url.pathExtension.lowercased()
        
        // different behaviour depending on the type of the file
        switch  type {
            
        case "txt" :
            do {
                let text = try String(contentsOfFile: url.path)
                textToRead.text = text
            } catch  {
                print(error)
            }
            
            
        case "rtf" :
            do {
                let attributed = try NSAttributedString(url: url, options: [.documentType: NSAttributedString.DocumentType.rtf, .characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil)
                textToRead.attributedText = attributed
            } catch  {
                print(error)
            }
            
            
        case "pdf" :
            let documentContent = NSMutableAttributedString()
            if let pdf = PDFDocument(url: url) {
                let pageCount = pdf.pageCount
                for i in 0 ..< pageCount {
                    guard let page = pdf.page(at: i) else { continue }
                    guard let pageContent = page.attributedString else { continue }
                    documentContent.append(pageContent)
                }
            }
            textToRead.attributedText = documentContent
            
            
        case "html" :
            do {
                let attributed = try NSAttributedString(url: url, options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil)
                textToRead.attributedText = attributed
            } catch  {
                print(error)
            }
        
        case "docx":
            textToRead.text = " NO docx converter for the time being. Save it as HTML or PDF and try again"
            
        case "doc":
            textToRead.text = " NO doc converter for the time being. Save it as HTML or PDF and try again"

        default :
            textToRead.text = "this type of file cannot be read"
        }
        
        // point at the beginning of the text if a new file is used
        pointer = 0
        
        // store it in fullText to be saved with saveText() or reused later when loading
        fullText = textToRead.text
        saveText()
    }
    
    /*
     ----------------------------------------------------------------------------
     MARK: Save the text
     ----------------------------------------------------------------------------
     */
    func saveText() {
        // this functions always save the full text and not only what remain to read keeping only the last
        
        // check the status of the swith (read from the beginning or from last stop)
        var readFrom = false
        if saveFromLastRead.isOn {
            readFrom = true
        } else {
            readFrom = false
        }
        
        CdC.shared.deleteAllData()
        CdC.shared.saveText(textToSave: fullText, pointer: pointer, fromLastPoint: readFrom)
    }
    
    /*
     ----------------------------------------------------------------------------
     MARK: go to top of the text to be read (all text, from last finished word
     or starting from selection.
     ----------------------------------------------------------------------------
     */
    
    func calculateRange() {
        
        // if save from last read is on, reading should restart from where it was before.
        if (saveFromLastRead.isOn) {
            textToRead.selectedRange = NSMakeRange(Int(pointer), textToRead.text.count-Int(pointer))
        }
        
        // the range is starting at the end with lenght 0 if the textview is reloaded
        if textToRead.selectedRange.length == 0 {
            let cursorPosition = textToRead.beginningOfDocument
            let endPosition = textToRead.endOfDocument
            textToRead.selectedTextRange = textToRead.textRange(from: cursorPosition, to: endPosition)
        }
        
    }


    /*
     ----------------------------------------------------------------------------
     MARK: Detect the language of the text
     ----------------------------------------------------------------------------
     */

    func detectedLanguage(for string: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(string)
        guard let languageCode = recognizer.dominantLanguage?.rawValue else { return nil }
        let detectedLanguage = Locale.current.localizedString(forIdentifier: languageCode)
        detectedIdiom.text = "\(detectedLanguage ?? "not found")"
        return languageCode
    }

    
    /*
     ----------------------------------------------------------------------------
     MARK: Functions for AVSpeachSynthetizerDelegate
     ----------------------------------------------------------------------------
     */
    
    // this function is called everytime a word is pronounced making the word blue and bold, updating the pointer and scrolling if close to the lower border of the text view
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        
        // increase and bold the spoken word
        let fontSize = 18.0
        let mutableAttributedString = NSMutableAttributedString(string: utterance.speechString)
        mutableAttributedString.addAttribute(.foregroundColor, value: UIColor.blue, range: characterRange)
        mutableAttributedString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: fontSize), range: characterRange)
        textToRead.attributedText = mutableAttributedString
        
        // update the pointer of the last word
        pointer = Int64(characterRange.lowerBound)
        
        // if close to the bottom sroll the range down
        var pt = 0
        if pointer > 400 {
            pt = Int(pointer) + 200
        }
        let reading = NSMakeRange(pt, 1)
        textToRead.scrollRangeToVisible(reading)

    }
    
    // point the word that has been spoken and highlight it
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        textToRead.attributedText = NSAttributedString(string: utterance.speechString)
    }
    
    
    /*
     ----------------------------------------------------------------------------
     MARK: The following functions add the "Done" "Clear" etc. buttons to the keyboard
     ----------------------------------------------------------------------------
     */
    
    @objc func doneButtonTapped() {
        view.endEditing(true)
    }
    
    @objc func clearButtonTapped() {
        // show the message
        let ac = UIAlertController(title: "ATTENTION!", message:  "You are deleting all the text. Are you sure?", preferredStyle: UIAlertController.Style.alert)
        ac.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel, handler: nil))
        ac.addAction(UIAlertAction(title: "Clear all", style: UIAlertAction.Style.destructive, handler: { [self] action in
            textToRead.text = ""
        }))
        // show the alert
        self.present(ac, animated: true, completion: nil)
    }
    
    
    @objc func unselectButtonTapped() {
        textToRead.selectedTextRange = textToRead.textRange(from: textToRead.beginningOfDocument, to: textToRead.beginningOfDocument)
    }
    
    func setupToolBar() {
        // creating a toolbar to be added to the keyboard to perfom some actions thought the correspondent selector @objc func ...
        let toolbar = UIToolbar()
        
        // flexSpace is just a filler that can adapt dimentions to fill the toolbar
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        // close the keyboard
        let doneButton = UIBarButtonItem(title: "Done", style: .done,
                                         target: self, action: #selector(doneButtonTapped))
        // cancel the content of the UITextView
        let clearButton = UIBarButtonItem(title: "Clear", style: .done,
                                          target: self, action: #selector(clearButtonTapped))
        // unselect all
        let unselectButton = UIBarButtonItem(title: "Unselect", style: .done,
                                             target: self, action: #selector(unselectButtonTapped))
        
        // compose the toolbar with buttons and spaces
        toolbar.setItems([clearButton, unselectButton, flexSpace, doneButton], animated: true)
        toolbar.sizeToFit()
        
        // add the toolbar to the keyboard of the text view
        textToRead.inputAccessoryView = toolbar
    }
}



