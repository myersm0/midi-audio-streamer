import Foundation

class ModarttRPC {
	private let host: String
	private let port: Int
	private let url: URL
	private var requestID: Int = 0
	
	init(host: String = "127.0.0.1", port: Int = 8081) {
		self.host = host
		self.port = port
		self.url = URL(string: "http://\(host):\(port)/jsonrpc")!
	}
	
	func call(method: String, params: Any? = nil) -> [String: Any]? {
		requestID += 1
		
		var payload: [String: Any] = [
			"method": method,
			"jsonrpc": "2.0",
			"id": requestID
		]
		
		if let params = params {
			payload["params"] = params
		} else {
			payload["params"] = []
		}
		
		guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
			verboseLog("Failed to serialize JSON request")
			return nil
		}
		
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.httpBody = jsonData
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		
		let semaphore = DispatchSemaphore(value: 0)
		var result: [String: Any]?
		
		let task = URLSession.shared.dataTask(with: request) { data, response, error in
			defer { semaphore.signal() }
			
			if let error = error {
				verboseLog("RPC request error: \(error.localizedDescription)")
				return
			}
			
			guard let data = data else {
				verboseLog("No data received from RPC server")
				return
			}
			
			guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
				verboseLog("Failed to parse JSON response")
				return
			}
			
			result = json
		}
		
		task.resume()
		semaphore.wait()
		
		return result
	}
	
	func getInfo() -> [String: Any]? {
		guard let response = call(method: "getInfo"),
			  let result = response["result"] as? [[String: Any]],
			  let info = result.first else {
			return nil
		}
		return info
	}
	
	func getParameters() -> [[String: Any]]? {
		guard let response = call(method: "getParameters"),
			  let params = response["result"] as? [[String: Any]] else {
			return nil
		}
		return params
	}
	
	func compareParameters(old: [[String: Any]], new: [[String: Any]]) -> [[String: Any]] {
		var changed: [[String: Any]] = []
		
		var oldDict: [String: [String: Any]] = [:]
		for param in old {
			if let id = param["id"] as? String {
				oldDict[id] = param
			}
		}
		
		for newParam in new {
			guard let id = newParam["id"] as? String else { continue }
			
			if let oldParam = oldDict[id] {
				let oldValue = oldParam["normalized_value"] as? Double ?? 0.0
				let newValue = newParam["normalized_value"] as? Double ?? 0.0
				
				if abs(oldValue - newValue) > 0.0001 {
					changed.append(newParam)
				}
			}
		}
		
		return changed
	}
}
