import Fluent
import JWT
import Vapor

struct Payload: JWTPayload, Equatable {
    enum CodingKeys: String, CodingKey {
        case subject = "sub"
        case expiration = "exp"
        case issuedAt = "iat"
    }

    var subject: SubjectClaim
    var expiration: ExpirationClaim
    var issuedAt: IssuedAtClaim

    func verify(using _: JWTSigner) throws {
        try self.expiration.verifyNotExpired()
    }
}

final class Token: Model, @unchecked Sendable {
    static let schema = "tokens"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "token")
    var token: String

    @Parent(key: "userID")
    var user: User

    @Field(key: "expires_at")
    var expiresAt: Date

    init() {}

    init(id: UUID? = nil, token: String, userID: User.IDValue, expiresAt: Date) {
        self.id = id
        self.token = token
        self.$user.id = userID
        self.expiresAt = expiresAt
    }
}

extension Token {
    func toDTO() -> TokenDTO {
        .init(token: self.token, user: self.user.toDTO())
    }
}
