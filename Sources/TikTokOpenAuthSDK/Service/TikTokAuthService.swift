/*
 * Copyright 2022 TikTok Pte. Ltd.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation
import UIKit
import TikTokOpenSDKCore

@objc (TTKSDKAuthService)
class TikTokAuthService: NSObject, TikTokRequestResponseHandling {
    private(set) var completion: ((TikTokBaseResponse) -> Void)?
    private(set) var redirectURI: String?
    private let urlOpener: TikTokURLOpener

    init(urlOpener: TikTokURLOpener = UIApplication.shared) {
        self.urlOpener = urlOpener
    }
    
    //MARK: - TikTokRequestHandling
    func handleRequest(
        _ request: TikTokBaseRequest,
        completion: ((TikTokBaseResponse) -> Void)?
    ) -> Bool
    {
        guard let authReq = request as? TikTokAuthRequest else { return false }
        self.completion = completion
        self.redirectURI = authReq.redirectURI
        guard let url = buildOpenURL(from: authReq) else { return false }
        urlOpener.open(url, options: [:]) { [weak self] success in
            guard let self = self else { return }
            if !success, let cancelURL = self.constructCancelURL() {
                self.handleResponseURL(url: cancelURL)
            }
        }
        return true
    }
    
    func buildOpenURL(from request: TikTokBaseRequest) -> URL? {
        guard let authReq = request as? TikTokAuthRequest else { return nil }
        guard let webBaseURL = URL(string: TikTokInfo.webAuthIndexURL) else { return nil }
        guard let nativeBaseURL = URL(string: "\(TikTokInfo.universalLink)\(TikTokInfo.universalLinkAuthPath)") else { return nil }
        let isWebAuth = authReq.isWebAuth || !urlOpener.isTikTokInstalled()
        let baseURL = isWebAuth ? webBaseURL : nativeBaseURL
        guard var urlComps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { return nil }
        urlComps.queryItems = isWebAuth ? authReq.convertToWebQueryParams() : authReq.convertToQueryParams()
        return urlComps.url
    }
    
    //MARK: - TikTokResponseHandling
    @discardableResult
    func handleResponseURL(url: URL) -> Bool {
        guard let res = try? TikTokAuthResponse(fromURL: url, redirectURI: redirectURI ?? "") else { return false }
        return handleResponse(res)
    }
    
    @discardableResult
    func handleResponse(_ response: TikTokAuthResponse) -> Bool {
        guard let closure = completion else { return false }
        closure(response)
        return true
    }
    
    //MARK: - Construct cancel URL
    private func constructCancelURL() -> URL? {
        guard let redirectURI = redirectURI else { return nil }
        guard let url = URL(string: redirectURI) else { return nil }
        guard var urlComps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        urlComps.queryItems = [
            URLQueryItem(name: "error_code", value: "-2"),
            URLQueryItem(name: "error", value: "access_denied"),
            URLQueryItem(name: "error_string", value: "User cancelled authorization"),
        ]
        return urlComps.url
    }
}
