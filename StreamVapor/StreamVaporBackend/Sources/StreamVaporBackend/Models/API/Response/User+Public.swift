import Vapor

extension User {
    struct Public: Content {
        let id: UUID?
        let name: String
        let email: String
        let username: String
    }
    
    func toPublic() -> User.Public {
        User.Public(id: self.id, name: self.name, email: self.email, username: self.username)
    }
}
