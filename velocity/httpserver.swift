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
    
    guard let app = app else {
        throw VelocityWebError("Could not unwrap WebServer..")
    }
    
    app.logger.logLevel = Logger.Level.error;

    
    // CORS headers
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin, "File-Name" ]
    )
    let cors = CORSMiddleware(configuration: corsConfiguration)
    app.middleware.use(cors, at: .beginning)
    
    defer { app.shutdown() }
    let encoder = JSONEncoder()
    
    //
    // Get host info (CPUName, ModelName, Uptime and Disk space)
    //
    app.get("hostInfo") { req in
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
    // Get a VM by name
    //
    app.get("getVM") { req -> Response in
        // badRequest if name query param is missing
        guard let vm_name = req.query[String.self, at: "name"] else {
            throw Abort(.badRequest)
        }
        
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")
        let vm = Manager.get_vm_by_name(name: vm_name)?.get_vminfo()
                
        let jsonData: Data?
        do {
            jsonData = try encoder.encode(vm)
        } catch {
            VErr("Could not encode as json")
            throw VelocityWebError("Could not encode as json")
        }
        
        guard let jsonData = jsonData else {
            VErr("Could not unwrap json data.")
            throw VelocityWebError("Could not unwrap json data.")
        }
                
        return Response(status: .ok, headers: headers, body: .init(data: jsonData))
    }

    //
    // Get a list of all currently running VMs
    //
    app.get("listVMs") { req -> Response in
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")
        
        let jsonData: Data
        do {
            var list_vm: Array<vVMInfo> = [ ]
            
            for vm in Manager.virtual_machines {
                list_vm.append(vm.get_vminfo())
            }
            
            jsonData = try encoder.encode(list_vm)
        } catch {
            throw VelocityWebError("Could not encode as JSON")
        }

        return Response(status: .ok, headers: headers, body: .init(data: jsonData))
    }

    //
    // Get all available macOS installers available for Download
    //
    app.get("listMacInstallers") { req in
        let jsonData: Data
        do {
            jsonData = try encoder.encode(MacOSFetcher.Firmwares)
        } catch {
            throw VelocityWebError("Could not decode as JSON")
        }
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")
        return Response(status: .ok, headers: headers, body: .init(data: jsonData))
    }

    //
    // Get a list of ISO images on the server
    //
    app.get("listISOs") { req -> Response in
        let jsonData: Data
        do {
            jsonData = try encoder.encode(Manager.iso_images)
        } catch {
            throw VelocityWebError("Could not decode as JSON")
        }
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")
        return Response(status: .ok, headers: headers, body: .init(data: jsonData))
    }

    //
    // Get a list of ISPW images on the server
    //
    app.get("listIPSWs") { req -> Response in
        let jsonData: Data
        do {
            jsonData = try encoder.encode(Manager.ipsws)
        } catch {
            throw VelocityWebError("Could not decode as JSON")
        }
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")
        return Response(status: .ok, headers: headers, body: .init(data: jsonData))
    }

    //
    // fetch a given macOS Installer from Apple
    //
    app.get("fetchMacOSInstaller") { req -> Response in
        guard let buildid = req.query[String.self, at: "buildid"] else {
            throw Abort(.badRequest)
        }

        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")

        if !MacOSFetcher.download_installer(vc: velocity_config, buildid: buildid) {
            return try! Response(status: .notFound, headers: headers, body: .init(data: encoder.encode(Message("No such build available."))))
        }

        return try! Response(status: .ok, headers: headers, body: .init(data: encoder.encode(Message("Download started."))))
    }

    //
    // View all currently pending downloads
    //
    app.get("listAllOperations") { req -> Response in
        let jsonData: Data
        do {
            jsonData = try encoder.encode(Manager.operations)
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
    app.post("createVM") { req -> Response in
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")

        let res = DispatchQueue.main.sync {
            do {
                let storage_format = try req.content.decode(vVMStorageFormat.self)
                let vm = try vVirtualMachine.from_storage_format(vc: velocity_config, storage_format: storage_format)

                guard let vm = vm else {
                    return try! Response(status: .ok, headers: headers, body: .init(data: encoder.encode(Message("Could not unwrap VirtualMachine"))))
                }

                Manager.virtual_machines.append(vm)
                return try! Response(status: .ok, headers: headers, body: .init(data: encoder.encode(Message("Virtual machine created."))))
            } catch {
                return try! Response(status: .ok, headers: headers, body: .init(data: encoder.encode(Message(error.localizedDescription))))
            }
        }
        return res;
    }


    //
    // Start a virtual machine by name
    //
    app.get("startVM") { req -> Response in
        // badRequest if name query param is missing
        guard let vm_name = req.query[String.self, at: "name"] else {
            throw Abort(.badRequest)
        }
        
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")

        let vm = Manager.get_vm_by_name(name: vm_name)

        guard let vm = vm else {
            return try! Response(status: .notFound, headers: headers, body: .init(data: encoder.encode(Message("No such VM"))))
        }

        DispatchQueue.main.sync {
            vm.start()
        }

        return try! Response(status: .ok, headers: headers, body: .init(data: encoder.encode(Message("Virtual Machine started."))))
    }

    //
    // Stop a virtual machine by name
    //
    app.get("stopVM") { req in
        // badRequest if name query param is missing
        guard let vm_name = req.query[String.self, at: "name"] else {
            throw Abort(.badRequest)
        }
        
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")

        let vm = Manager.get_vm_by_name(name: vm_name)

        guard let vm = vm else {
            return try! Response(status: .notFound, headers: headers, body: .init(data: encoder.encode(Message("No such VM"))))
        }

        DispatchQueue.main.sync {
            vm.stop()
        }
        return try! Response(status: .ok, headers: headers, body: .init(data: encoder.encode(Message("Virtual Machine stopped."))))
    }

    //
    // Take a snapshot of the virtualmachine
    //
    app.get("snapshot") { req in
        // badRequest if name query param is missing
        guard let vm_name = req.query[String.self, at: "name"] else {
            throw Abort(.badRequest)
        }
        
        var headers = HTTPHeaders()

        let vm = Manager.get_vm_by_name(name: vm_name)

        guard let vm = vm else {
            headers.add(name: .contentType, value: "application/json")
            return try! Response(status: .notFound, headers: headers, body: .init(data: encoder.encode(Message("No such VM"))))
        }

        guard let png = vm.get_png_snapshot() else {
            headers.add(name: .contentType, value: "application/json")
            return try! Response(status: .notFound, headers: headers, body: .init(data: encoder.encode(Message("Could not get png Data."))))
        }

        headers.add(name: .contentType, value: "image/png")
        return Response(status: .ok, headers: headers, body: .init(data: png))
    }

    //
    // Upload an ISO file to the server.
    // Content-Type: octet-stream / File-Name: file-name-on-srv.iso
    app.on(.POST, "uploadISO", body: .stream) { req -> EventLoopFuture<String> in
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
            
            let json_data = try! encoder.encode(Message("File upload completed."))

            do {
                try Manager.index_iso_storage(velocity_config: velocity_config)
            } catch {
                VWarn("Could not index iso storage, ignoring.")
            }

            return promise.futureResult.always { result in
                _ = try? handle.close()
            }.map {
                return String(data: json_data, encoding: .utf8)!
            }
        }
    }
    
    app.http.server.configuration.hostname = "0.0.0.0"

    do {
        try app.run()
    } catch {
        throw VelocityWebError("Could not start WebServer: \(error.localizedDescription)")
    }

}
