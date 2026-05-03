import Foundation

class HistoryManager {

    private let baseURL: String
    private let session: URLSession

    var records: [HistoryRecord] = []

    init(baseURL: String = "http://localhost:5000") {
        self.baseURL = baseURL

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    func loadHistory(limit: Int = 50, offset: Int = 0, completion: @escaping ([HistoryRecord]) -> Void) {
        guard let url = URL(string: "\(baseURL)/history?limit=\(limit)&offset=\(offset)") else {
            completion([])
            return
        }

        let task = session.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  error == nil else {
                completion([])
                return
            }

            do {
                struct HistoryResponse: Codable {
                    let success: Bool
                    let records: [HistoryRecord]
                }
                let historyResponse = try JSONDecoder().decode(HistoryResponse.self, from: data)
                self?.records = historyResponse.records
                completion(historyResponse.records)
            } catch {
                completion([])
            }
        }

        task.resume()
    }

    func deleteRecord(id: Int, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/history/\(id)") else {
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let task = session.dataTask(with: request) { _, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                completion(httpResponse.statusCode == 200)
            } else {
                completion(false)
            }
        }

        task.resume()
    }

    func exportToFile(url: URL, completion: @escaping (Bool) -> Void) {
        guard let exportURL = URL(string: "\(baseURL)/export") else {
            completion(false)
            return
        }

        let task = session.dataTask(with: exportURL) { data, response, error in
            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  error == nil else {
                completion(false)
                return
            }

            do {
                struct ExportResponse: Codable {
                    let success: Bool
                    let content: String
                }
                let exportResponse = try JSONDecoder().decode(ExportResponse.self, from: data)

                do {
                    try exportResponse.content.write(to: url, atomically: true, encoding: .utf8)
                    completion(true)
                } catch {
                    completion(false)
                }
            } catch {
                completion(false)
            }
        }

        task.resume()
    }

    func clearHistory(completion: @escaping () -> Void) {
        loadHistory(limit: 1000, offset: 0) { [weak self] records in
            let group = DispatchGroup()

            for record in records {
                group.enter()
                self?.deleteRecord(id: record.id) { _ in
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                self?.records = []
                completion()
            }
        }
    }
}
