//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
// swift-tools-version:4.0
//
// swift-tools-version:4.0
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
import NIO
import NIOTransportServices
import NIOHTTP1
import Network

final class HTTP1ClientHandler: ChannelInboundHandler {
    typealias OutboundOut = HTTPClientRequestPart
    typealias InboundIn = HTTPClientResponsePart

    func channelActive(ctx: ChannelHandlerContext) {
        var head = HTTPRequestHead(version: .init(major: 1, minor: 1), method: .GET, uri: "/get")
        head.headers.add(name: "Host", value: "httpbin.org")
        head.headers.add(name: "User-Agent", value: "SwiftNIO")
        ctx.write(self.wrapOutboundOut(.head(head)), promise: nil)
        ctx.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)

        print("Connected to \(ctx.channel.remoteAddress!) from \(ctx.channel.localAddress!)")
    }

    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        let part = self.unwrapInboundIn(data)

        switch part {
        case .head(let head):
            self.printResponseHead(head)
        case .body(let b):
            print(b.getString(at: b.readerIndex, length: b.readableBytes)!, separator: "")
        case .end:
            // Print a newline.
            print("")
            ctx.close(promise: nil)
        }
    }

    private func printResponseHead(_ head: HTTPResponseHead) {
        print("HTTP/\(head.version.major).\(head.version.minor) \(head.status.code) \(head.status.reasonPhrase)")
        for (name, value) in head.headers {
            print("\(name): \(value)")
        }
        print("")
    }
}

let group = NIOTSEventLoopGroup()
let channel = try! NIOTSConnectionBootstrap(group: group)
    .connectTimeout(.hours(1))
    .channelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
    .tlsOptions(NWProtocolTLS.Options())
    .channelInitializer { channel in
        channel.pipeline.addHTTPClientHandlers().then {
            channel.pipeline.add(handler: HTTP1ClientHandler())
        }
    }.connect(host: "httpbin.org", port: 443).wait()

// Wait for the request to complete
try! channel.closeFuture.wait()
