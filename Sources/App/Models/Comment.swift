import Fluent
import Vapor

final class Comment: Model, @unchecked Sendable {
    static let schema = "comments"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "content")
    var content: String

    @Parent(key: "article_id")
    var article: Article

    @Parent(key: "user_id")
    var user: User

    @Timestamp(key: "created_at", on: .create, format: .iso8601)
    var createdAt: Date?

    init() {}

    init(id: UUID? = nil, content: String, articleID: Article.IDValue, userID: User.IDValue) {
        self.id = id
        self.content = content
        self.$article.id = articleID
        self.$user.id = userID
    }
}

extension Comment {
    func toDTO() -> CommentDTO {
        .init(id: self.id, content: self.content)
    }
}