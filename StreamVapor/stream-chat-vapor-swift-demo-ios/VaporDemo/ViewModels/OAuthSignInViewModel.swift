import Foundation
import AuthenticationServices

class OAuthSignInViewModel: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    
    let apiHostname: String
    
    init(apiHostname: String){
        self.apiHostname = apiHostname
    }
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
    
    enum OAuthType {
        case google
        case github
    }
    
    func signIn(with oauthType: OAuthType) async throws -> LoginResultData {
        guard let authURL = URL(string: "\(self.apiHostname)/iOS/login-google") else {
            fatalError("Failed to create Google URL")
        }
        
        let scheme = "streamVapor"
        
        return try await withCheckedThrowingContinuation{ continuation in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: scheme) { callbackURL, error in
                guard error == nil, let callbackURL = callbackURL else {
                    return continuation.resume(with: .failure(OAuthFailure()))
                }
                
                let queryItems = URLComponents(string: callbackURL.absoluteString)?.queryItems
                guard let token = queryItems?.first(where: { $0.name == "token"})?.value, let streamToken = queryItems?.first(where: {$0.name == "streamToken"})?.value else {
                    return continuation.resume(with: .failure(OAuthFailure()))
                }
                
                let data = LoginResultData(apiToken: token, streamToken: streamToken)
                return continuation.resume(with: .success(data))
            }
            
            session.presentationContextProvider = self
            session.start()
        }
    }
}
