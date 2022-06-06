import Foundation
import SwiftUI
import AuthenticationServices
import StreamChatSwiftUI
import StreamChat

final class LoginViewModel: ObservableObject {
    let apiHostname: String
    @Published var username = ""
    @Published var password = ""
    @Published var oauthSignInWrapper: OAuthSignInViewModel
    @Published var showingLoginErrorAlert = false

    @Injected(\.chatClient) var chatClient

    init(apiHostname: String) {
        self.apiHostname = apiHostname
        self.oauthSignInWrapper = OAuthSignInViewModel(apiHostname: apiHostname)
    }

    @MainActor
    func login() async throws -> LoginResultData {
        let path = "\(apiHostname)/auth/login"
        guard let url = URL(string: path) else {
            fatalError("Failed to convert URL")
        }
        
        guard let loginString = "\(username):\(password)".data(using: .utf8)?.base64EncodedString() else {
            fatalError("Failed to serialize authentication data")
        }
        
        var loginRequest = URLRequest(url: url)
        loginRequest.addValue("basic \(loginString)", forHTTPHeaderField: "Authorization")
        loginRequest.httpMethod = "POST"
        
        do {
            let (data, response) = try await URLSession.shared.data(for: loginRequest)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw LoginError()
            }
            
            let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
            return LoginResultData(apiToken: loginResponse.apiToken.value, streamToken: loginResponse.streamToken)
        } catch {
            self.showingLoginErrorAlert = true
            throw error
        }
    }

    @MainActor
    func handleSIWA(result: Result<ASAuthorization, Error>) async throws -> LoginResultData {
        fatalError()
    }

    @MainActor
    func handleLoginComplete(loginData: LoginResultData) async throws -> String {
        do{
            let path = "\(apiHostname)/account"
            guard let url = URL(string: path) else {
                fatalError("Failed to create login complete URL")
            }
            
            var loginRequest = URLRequest(url: url)
            loginRequest.addValue("Bearer \(loginData.apiToken)", forHTTPHeaderField: "Authorization")
            loginRequest.httpMethod = "GET"
            
            let (data, response) = try await URLSession.shared.data(for: loginRequest)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                self.showingLoginErrorAlert = true
                throw LoginError()
            }
            
            let userData = try JSONDecoder().decode(UserData.self, from: data)
            self.connectUser(token: loginData.streamToken, username: userData.username, name: userData.username)
        } catch {
            self.showingLoginErrorAlert = true
            throw LoginError()
        }
        
        return loginData.apiToken
    }

    func connectUser(token: String, username: String, name: String) {
        let tokenObject = try! Token(rawValue: token)

        // Call `connectUser` on our SDK to get started.
        chatClient.connectUser(
            userInfo: .init(id: username,
                            name: name,
                            imageURL: URL(string: "https://vignette.wikia.nocookie.net/starwars/images/2/20/LukeTLJ.jpg")!),
            token: tokenObject
        ) { error in
            if let error = error {
                // Some very basic error handling only logging the error.
                log.error("connecting the user failed \(error)")
                return
            }
        }
    }
}
