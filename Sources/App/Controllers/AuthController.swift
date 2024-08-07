import Fluent
import JWT
import Vapor

struct AuthController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let auth = routes.grouped("auth")
        auth.post("login", use: self.login)
        auth.post("register", use: self.register)

        let protected = auth.grouped(JWTMiddleware())
        protected.get("me", use: self.getMe)
        protected.post("logout", use: self.logout)
        protected.delete("delete", use: self.deleteAccount)

        let avatar = protected.grouped("avatar")
        avatar.on(.POST, "upload", body: .collect(maxSize: "10mb"), use: self.uploadAvatar)
    }

    @Sendable
    func register(req: Request) async throws -> UserDTO {
        try RegisterRequest.validate(content: req)
        let request = try req.content.decode(RegisterRequest.self)

        let normalizedUsername = request.username.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedEmail = request.email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if username already exists
        if try await User.query(on: req.db)
            .filter(\.$username == normalizedUsername)
            .first() != nil {
            throw Abort(.conflict, reason: "A user with this username already exists")
        }

        // Check if email already exists
        if try await User.query(on: req.db)
            .filter(\.$email == normalizedEmail)
            .first() != nil {
            throw Abort(.conflict, reason: "A user with this email already exists")
        }

        let user = try User(
            username: request.username,
            email: request.email,
            passwordHash: Bcrypt.hash(request.password)
        )
        try await user.save(on: req.db)
        return user.toDTO()
    }

    @Sendable
    func login(req: Request) async throws -> TokenDTO {
        try LoginRequest.validate(content: req)
        let loginRequest = try req.content.decode(LoginRequest.self)

        guard
            let user = try await User.query(on: req.db)
            .filter(\.$email == loginRequest.email)
            .first()
        else {
            throw Abort(.unauthorized, reason: "Invalid email")
        }

        guard try Bcrypt.verify(loginRequest.password, created: user.passwordHash) else {
            throw Abort(.unauthorized, reason: "Invalid password")
        }

        let bearer = try user.generateToken(using: req.application)
        try await bearer.save(on: req.db)

        return TokenDTO(token: bearer.token, user: user.toDTO())
    }

    @Sendable
    func logout(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        /// Invalidate all tokens for the user or the specific token used for the request
        try await Token.query(on: req.db)
            .filter(\.$user.$id == user.requireID())
            .delete()
        return .ok
    }

    @Sendable
    func deleteAccount(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        try await user.delete(on: req.db)
        return .ok
    }

    @Sendable
    func getMe(req: Request) async throws -> UserDTO {
        let user = try req.auth.require(User.self)
        return user.toDTO()
    }

    @Sendable
    func uploadAvatar(req: Request) async throws -> UserDTO {
        let user = try req.auth.require(User.self)

        let file = try req.content.decode(File.self)

        guard let fileExtension = file.extension else {
            throw Abort(.badRequest, reason: "Mailformed file")
        }

        let fileName = "\(UUID().uuidString).\(fileExtension)"

        let s3UploadService = S3UploadService(req.application, req: req)
        guard let avatarUrl = try await s3UploadService.uploadFile(file, key: "avatars/\(fileName)") else {
            throw Abort(.internalServerError, reason: "Failed to upload file")
        }

        user.avatarUrl = avatarUrl
        try await user.save(on: req.db)

        return user.toDTO()
    }
}
