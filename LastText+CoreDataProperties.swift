//
//  LastText+CoreDataProperties.swift
//  EasyReading
//
//  Created by Andrea on 10/02/24.
//
//

import Foundation
import CoreData


extension LastText {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<LastText> {
        return NSFetchRequest<LastText>(entityName: "LastText")
    }
    
    @NSManaged public var lastPosition: Int64   //the position of the last word pronounced
    @NSManaged public var lastText: String?     //the last text to read
    @NSManaged public var fromLastPoint: Bool   //the position of the switch indicating if to read from the beginning or the last interruption

}

extension LastText : Identifiable {

}
