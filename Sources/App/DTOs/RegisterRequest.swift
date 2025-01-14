import Fluent
import Vapor

struct RegisterRequest: Content, Validatable {
    let username: String
    let password: String

    static func validations(_ validations: inout Validations) {
        validations.add("username", as: String.self, is: !.empty && .count(2...))
        validations.add("password", as: String.self, is: .count(8...))
    }
}
