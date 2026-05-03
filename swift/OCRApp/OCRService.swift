import AppKit
import Foundation

struct OCRResponse: Codable {
    let success: Bool
    let text: String
    let confidence: Double
    let recordId: Int?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success
        case text
        case confidence
        case recordId = "record_id"
        case error
    }
}

struct HistoryRecord: Codable {
    let id: Int
    let imagePath: String?
    let recognizedText: String
    let confidence: Double
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case imagePath = "image_path"
        case recognizedText = "recognized_text"
        case confidence
        case createdAt = "created_at"
    }

    var text: String {
        return recognizedText
    }

    var dateString: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: createdAt) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return createdAt
    }
}

enum OCRError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}

class OCRService {

    private let baseURL: String
    private let session: URLSession

    init(baseURL: String = "http://localhost:5000") {
        self.baseURL = baseURL

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }

    func recognizeText(from image: NSImage, completion: @escaping (Result<OCRResponse, OCRError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/ocr") else {
            completion(.failure(.invalidURL))
            return
        }

        guard let imageData = image.tiffRepresentation else {
            completion(.failure(.invalidResponse))
            return
        }

        let base64String = imageData.base64EncodedString()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "base64": base64String,
            "threshold": 128,
            "kernel_size": 3
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.networkError(error)))
            return
        }

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }

            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }

            do {
                let response = try JSONDecoder().decode(OCRResponse.self, from: data)
                if response.success {
                    completion(.success(response))
                } else {
                    completion(.failure(.serverError(response.error ?? "Unknown error")))
                }
            } catch {
                completion(.failure(.invalidResponse))
            }
        }

        task.resume()
    }

    func recognizeText(imagePath: String, completion: @escaping (Result<OCRResponse, OCRError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/ocr") else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "image_path": imagePath,
            "threshold": 128,
            "kernel_size": 3
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.networkError(error)))
            return
        }

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }

            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }

            do {
                let response = try JSONDecoder().decode(OCRResponse.self, from: data)
                if response.success {
                    completion(.success(response))
                } else {
                    completion(.failure(.serverError(response.error ?? "Unknown error")))
                }
            } catch {
                completion(.failure(.invalidResponse))
            }
        }

        task.resume()
    }

    func checkHealth(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/health") else {
            completion(false)
            return
        }

        let task = session.dataTask(with: url) { _, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                completion(httpResponse.statusCode == 200)
            } else {
                completion(false)
            }
        }

        task.resume()
    }
}

extension NSImage {
    var tiffRepresentation: Data? {
        guard let tiffData = tiffRepresentation(using: .compressionLZW, factor: 1.0) else {
            return nil
        }
        return tiffData
    }
}
