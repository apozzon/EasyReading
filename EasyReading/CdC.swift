//
//  CoreDataController.swift
//  EasyReading
//
//  Created by Andrea on 29/01/24.
//

import Foundation
import CoreData
import UIKit

// CdC = CoreDataController used as singleton through shared property
class CdC {
    static let shared = CdC()
    
    private var context: NSManagedObjectContext
    
    private init() {
        let application = UIApplication.shared.delegate as! AppDelegate
        self.context = application.persistentContainer.viewContext
    }
    
    func saveText(textToSave: String, pointer: Int64, fromLastPoint: Bool) {
        /*
         Per creare un oggetto da inserire in memoria è necessario creare un riferimento all'Entity (NSEntityDescription) da cui si copierà la struttura di base
         */
        let entity = NSEntityDescription.entity(forEntityName: "LastText", in: self.context)
        
        /*
         creiamo un nuovo oggetto NSManagedObject dello stesso tipo descritto dalla NSEntityDescription
         che andrà inserito nel context dell'applicazione
         */
        let lt = LastText(entity: entity!, insertInto: self.context)
        lt.lastText = textToSave
        lt.lastPosition = pointer
        lt.fromLastPoint = fromLastPoint
        
        do {
            try self.context.save() // la funzione save() rende persistente il nuovo oggetto (newLibro) in memoria
        } catch let error {
            print("[CDC] Problem saving text into memory")
            print("\n \(error) \n")
        }
        
        print("[CDC] text correctly saved")
    }
    
    func loadText() -> [LastText] {
        print("[CDC] Reading the text")
        
        let request: NSFetchRequest<LastText> = NSFetchRequest(entityName: "LastText" ) // l'oggetto rappresenta una richiesta da inviare al context per la ricerca di oggetti di tipo entityName (nome dell'entity da cercare)
        request.returnsObjectsAsFaults = false
        
        let texts = self.loadTextFromFetchRequest(request: request)
        
        return texts
    }
    
    
    private func loadTextFromFetchRequest(request: NSFetchRequest<LastText>) -> [LastText] {
        var array = [LastText]()
        do {
            array = try self.context.fetch(request)
            
            guard array.count > 0 else {
                print("[CDC] No text to read ")
                return []
            }
            
           /* for x in array {
                print("[CDC] Text \(x.lastText!) - Pointer \(x.lastPosition)")
            }*/
            
        } catch let error {
            print("[CDC] Problem executing FetchRequest")
            print("\n \(error) \n")
        }
        
        return array
    }
    
    func deleteAllData() {
        let ReqVar = NSFetchRequest<NSFetchRequestResult>(entityName: "LastText")
        let DelAllReqVar = NSBatchDeleteRequest(fetchRequest: ReqVar)
        do {
            try self.context.execute(DelAllReqVar) // la funzione save() rende persistente il nuovo oggetto (newLibro) in memoria
        } catch let error {
            print("[CDC] Problem deleting memory")
            print("\n \(error) \n")
        }
    }
    
 }

