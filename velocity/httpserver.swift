//
//  httpserver.swift
//  velocity
//
//  Created by zimsneexh on 27.05.23.
//

import Foundation
import Vapor

internal struct VelocityWebError: Error, LocalizedError {
    let errorDescription: String?

    init(_ description: String) {
        errorDescription = description
    }
}

struct Message: Codable {
    var message: String
    
    init(_ message: String) {
        self.message = message
    }
}

public func start_web_server(velocity_config: VelocityConfig) throws {
    let app: Application?
    do {
        app = try Application(.detect())
    } catch {
        throw VelocityWebError("Could not setup WS: \(error.localizedDescription)")
    }
    app?.logger.logLevel = Logger.Level.error;

    // CORS headers
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin]
    )
    let cors = CORSMiddleware(configuration: corsConfiguration)
    app!.middleware.use(cors, at: .beginning)
    
    defer { app!.shutdown() }
    let encoder = JSONEncoder()
    
    //
    // Get host info (CPUName, ModelName, Uptime and Disk space)
    //
    app!.get("hostInfo") { req in
        let jsonData: Data
        do {
            jsonData = try encoder.encode(HostInfo())
        } catch {
            throw VelocityVMMError("Could not decode as JSON")
        }
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")
        return Response(status: .ok, headers: headers, body: .init(data: jsonData))
    }
    
    //
    // Get a list of all currently running VMs
    //
    app!.get("listRunningVMs") { req -> Response in
        let jsonData: Data
        do {
            var vms: Array<VirtualMachine> = [ ]
            
            for vme in Manager.running_vms {
                vms.append(vme.get_vm())
            }
            
            jsonData = try encoder.encode(vms)
        } catch {
            throw VelocityWebError("Could not decode as JSON")
        }
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")
        return Response(status: .ok, headers: headers, body: .init(data: jsonData))
    }
    
    //
    // Get a list of all available VMs
    //
    app!.get("listAvailableVMs") { req -> Response in
        let jsonData: Data
        do {
            jsonData = try encoder.encode(Manager.available_vms)
        } catch {
            throw VelocityWebError("Could not decode as JSON")
        }
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")
        return Response(status: .ok, headers: headers, body: .init(data: jsonData))
    }
    
    //
    // Create a new virtual machine
    //
    app!.post("createVM") { req -> Response in
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")
        
        do {
            let vm_properties = try req.content.decode(VMProperties.self)
            try Manager.create_vm(velocity_config: velocity_config, vm_properties: vm_properties)
        } catch {
            return try! Response(status: .ok, headers: headers, body: .init(data: encoder.encode(Message(error.localizedDescription))))
        }
        return try! Response(status: .ok, headers: headers, body: .init(data: encoder.encode(Message("Virtual machine created."))))
    }
    
    //
    // Start a virtual machine by name
    //
    app!.get("startVM") { req -> Response in
        // badRequest if name query param is missing
        guard let vm_name = req.query[String.self, at: "name"] else {
            throw Abort(.badRequest)
        }
        
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")
        
        do {
            try Manager.start_vm(velocity_config: velocity_config, name: vm_name)
        } catch {
            return try! Response(status: .ok, headers: headers, body: .init(data: encoder.encode(Message(error.localizedDescription))))
        }
        
        return try! Response(status: .ok, headers: headers, body: .init(data: encoder.encode(Message("Virtual Machine started."))))
    }
    
    //
    // Stop a virtual machine by name
    //
    app!.get("stopVM") { req in
        // badRequest if name query param is missing
        guard let vm_name = req.query[String.self, at: "name"] else {
            throw Abort(.badRequest)
        }
        
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")
        
        do {
            try Manager.stop_vm(name: vm_name)
            return try! Response(status: .ok, headers: headers, body: .init(data: encoder.encode(Message("Virtual Machine stopped."))))
        } catch {
            return try! Response(status: .ok, headers: headers, body: .init(data: encoder.encode(Message("Error: \(error.localizedDescription)"))))
        }
    }
    
    //
    // Take a snapshot of the virtualmachine
    //
    app!.get("snapshot") { req in
        // badRequest if name query param is missing
        guard let vm_name = req.query[String.self, at: "name"] else {
            throw Abort(.badRequest)
        }
        
        var headers = HTTPHeaders()
                
        if let vm = Manager.get_running_vm_by_name(name: vm_name) {
            VDebug("Capturing snapshot for \(vm.vm_info.name)..")
            if let png_data = vm.get_cur_screen_contents() {
                headers.add(name: .contentType, value: "image/png")
                VDebug("PNG Size is \(png_data.count)")
                return Response(status: .ok, headers: headers, body: .init(data: png_data))
            }
            
            headers.add(name: .contentType, value: "application/json")
            return try! Response(status: .ok, headers: headers, body: .init(data: encoder.encode(Message("Could not capture snapshot."))))
            
        }
        headers.add(name: .contentType, value: "application/json")
        return try! Response(status: .ok, headers: headers, body: .init(data: encoder.encode(Message("No such VM."))))
    }
    
    //
    // Send a keycode to the vm
    //
    app!.get("sendKeycode") { req in
        guard let vm_name = req.query[String.self, at: "name"] else {
            throw Abort(.badRequest)
        }
        guard let keycode = req.query[String.self, at: "keycode"] else {
            throw Abort(.badRequest)
        }
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")
        
        if let vm = Manager.get_running_vm_by_name(name: vm_name) {
            VDebug("Sending keycode '\(keycode)' to VM '\(vm_name)'")
            vm.send_key_event(key_code: UInt16(keycode) ?? 0)
            return try! Response(status: .ok, headers: headers, body: .init(data: encoder.encode(Message("Keycode sent to VM."))))
        }
                
        return try! Response(status: .ok, headers: headers, body: .init(data: encoder.encode(Message("No such VM."))))
    }
    
    //
    // Upload an ISO file to the server.
    // Content-Type: octet-stream / File-Name: file-name-on-srv.iso
    app!.on(.POST, "uploadISO", body: .stream) { req -> EventLoopFuture<String> in
        guard let file_name = req.headers["File-Name"].first else {
            throw Abort(.badRequest)
        }
        
        VLog("Receiving ISO file named '\(file_name)'..")
        let file_path = velocity_config.velocity_iso_dir.appendingPathComponent(file_name).absoluteString
        FileManager.default.createFile(atPath: file_path, contents: nil, attributes: nil)
        
        let io = req.application.fileio
        return io.openFile(path: file_path, mode: .write, eventLoop: req.eventLoop).flatMap { handle -> EventLoopFuture<String> in
            
            func handleChunks(promise: EventLoopPromise<Void>) {
                req.body.drain { drainResult -> EventLoopFuture<Void> in
                    switch drainResult {
                    case .buffer(let chunk):
                        return io.write(fileHandle: handle, buffer: chunk, eventLoop: req.eventLoop).flatMap { _ in
                            return req.eventLoop.future()
                        }
                    case .error(let error):
                        promise.fail(error)
                        return req.eventLoop.future(error: error) 
                    case .end:
                        promise.succeed(())
                        return req.eventLoop.future()
                    }
                }
            }
            
            let promise = req.eventLoop.makePromise(of: Void.self)
            handleChunks(promise: promise)
            
            return promise.futureResult.always { result in
                _ = try? handle.close()
            }.map {
                return "File upload completed."
            }
        }
    }
    
    app?.http.server.configuration.hostname = "0.0.0.0"

    do {
        try app!.run()
    } catch {
        throw VelocityWebError("Could not start WS: \(error.localizedDescription)")
    }
    try! app!.run()
}
