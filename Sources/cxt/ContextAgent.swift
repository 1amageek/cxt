//
//  ContextAgent.swift
//  cxt
//
//  Created by Norikazu Muramoto on 2025/03/07.
//


import Foundation
import SwiftAgent
import Agents
import AgentTools

@preconcurrency import GoogleGenerativeAI

struct Context: Codable {
    var paths: [String]
}

struct ContextAgent: Agent {
    public typealias Input = String
    public typealias Output = Context
    public init() { }
    
    /// The processing pipeline for the agent
    public var body: some Step<String, Context> {
        Transform { text in
            [
                ModelContent(role: "user", parts: [.text(text)])
            ]
        }
        GeminiModel<Context>(
            modelName: "gemini-2.0-pro-exp-02-05",
            schema: JSONSchema.object(
                description: "An object containing an array of path strings",
                properties: [
                    "paths": JSONSchema.array(
                        description: "Array of path strings",
                        items: JSONSchema.string()
                    )
                ],
                required: ["paths"]
            )
        ) { tools in
"""
You are an outstanding agent for improving programs.  
You return the file paths related to the information requested by the user.  
• It includes files that are dependencies.  
• It includes files related to the requirements being implemented.  
• It includes files that will be affected when the requirements are implemented.
"""
        }
    }
}
