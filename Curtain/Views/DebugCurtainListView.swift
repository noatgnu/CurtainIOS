//
//  DebugCurtainListView.swift
//  Curtain
//
//  Created by Toan Phung on 02/08/2025.
//

import SwiftUI

/// Simple debug view to test the + button functionality
struct DebugCurtainListView: View {
    @State private var showingAddSheet = false
    @State private var tapCount = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    Text("Tap Count: \(tapCount)")
                        .font(.title)
                        .padding()
                    
                    Text("Add Sheet Showing: \(showingAddSheet ? "Yes" : "No")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                // Floating Action Button (Same as main view)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            print("Debug: + button tapped")
                            tapCount += 1
                            showingAddSheet = true
                        }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Debug View")
            .sheet(isPresented: $showingAddSheet) {
                NavigationView {
                    VStack {
                        Text("Add Sheet Content")
                            .font(.title2)
                            .padding()
                        
                        Text("This is the add curtain sheet")
                            .foregroundColor(.secondary)
                            .padding()
                        
                        Spacer()
                    }
                    .navigationTitle("Add Debug Item")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                showingAddSheet = false
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Add") {
                                print("Debug: Add button in sheet tapped")
                                showingAddSheet = false
                            }
                        }
                    }
                }
                .onAppear {
                    print("Debug: Sheet appeared")
                }
            }
        }
    }
}

#Preview {
    DebugCurtainListView()
}