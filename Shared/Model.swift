import CoreData
import GrailkaufCore

@objc(ShoppingList) final class ShoppingList: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var createdAt: Date?
    @NSManaged var items: Set<Item>?
    @NSManaged var moves: Set<OrderMove>?
}

/// A line of the list. A ticked item stays in the store. The order and the suggestions learn from it.
@objc(Item) final class Item: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var text: String?
    @NSManaged var category: String?
    @NSManaged var createdAt: Date?
    @NSManaged var modifiedAt: Date?
    @NSManaged var tickedAt: Date?
    @NSManaged var deferredAt: Date?
    @NSManaged var archivedAt: Date?
    @NSManaged var list: ShoppingList?

    var entry: Entry? {
        guard let id, let text, let createdAt else { return nil }
        return Entry(
            id: id, text: text, category: category, createdAt: createdAt, modifiedAt: modifiedAt,
            tickedAt: tickedAt, deferredAt: deferredAt, archivedAt: archivedAt)
    }
}

/// A manual drag on the order screen.
@objc(OrderMove) final class OrderMove: NSManagedObject {
    @NSManaged var key: String?
    @NSManaged var after: String?
    @NSManaged var date: Date?
    @NSManaged var list: ShoppingList?

    var move: Move? {
        guard let key, let date else { return nil }
        return Move(date: date, key: key, after: after)
    }
}

/// The model is in code, so the phone and the Watch share one definition.
/// The cloud sync needs optional attributes and an inverse for each relationship.
func makeModel() -> NSManagedObjectModel {
    func entity(_ name: String, _ attributes: [(String, NSAttributeDescription.AttributeType)]) -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = name
        entity.managedObjectClassName = name
        entity.properties = attributes.map { name, type in
            let attribute = NSAttributeDescription()
            attribute.name = name
            attribute.type = type
            attribute.isOptional = true
            return attribute
        }
        return entity
    }
    func own(_ list: NSEntityDescription, _ children: NSEntityDescription, as name: String) {
        let toMany = NSRelationshipDescription()
        toMany.name = name
        toMany.destinationEntity = children
        toMany.deleteRule = .cascadeDeleteRule
        toMany.isOptional = true
        let toOne = NSRelationshipDescription()
        toOne.name = "list"
        toOne.destinationEntity = list
        toOne.maxCount = 1
        toOne.deleteRule = .nullifyDeleteRule
        toOne.isOptional = true
        toMany.inverseRelationship = toOne
        toOne.inverseRelationship = toMany
        list.properties.append(toMany)
        children.properties.append(toOne)
    }
    let list = entity("ShoppingList", [("id", .uuid), ("createdAt", .date)])
    let item = entity("Item", [
        ("id", .uuid), ("text", .string), ("category", .string), ("createdAt", .date), ("modifiedAt", .date),
        ("tickedAt", .date), ("deferredAt", .date), ("archivedAt", .date),
    ])
    let move = entity("OrderMove", [("key", .string), ("after", .string), ("date", .date)])
    own(list, item, as: "items")
    own(list, move, as: "moves")
    let model = NSManagedObjectModel()
    model.entities = [list, item, move]
    return model
}
