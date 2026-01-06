//
//  SiteSettingsView.swift
//  Curtain
//
//  Created by Toan Phung on 02/08/2025.
//

import SwiftUI
import SwiftData

// MARK: - SiteSettingsView (Like Android Site Management)

struct SiteSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var siteSettings: [CurtainSiteSettings]
    @State private var showingAddSiteSheet = false
    @State private var showingEditSheet = false
    @State private var selectedSite: CurtainSiteSettings?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header Info
                if !siteSettings.isEmpty {
                    HeaderInfoView(totalSites: siteSettings.count, activeSites: activeSitesCount)
                        .padding()
                        .background(Color(.systemGray6))
                }
                
                // Sites List
                if siteSettings.isEmpty {
                    SitesEmptyStateView()
                } else {
                    SitesList(
                        sites: siteSettings,
                        onToggleActive: toggleSiteActive,
                        onEdit: { site in
                            selectedSite = site
                            showingEditSheet = true
                        },
                        onDelete: deleteSite
                    )
                }
            }
            .navigationTitle("API Sites")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Site") {
                        showingAddSiteSheet = true
                    }
                }
            }
            .sheet(isPresented: $showingAddSiteSheet) {
                AddSiteSheet(modelContext: modelContext)
            }
            .sheet(isPresented: $showingEditSheet) {
                if let site = selectedSite {
                    EditSiteSheet(site: site, modelContext: modelContext)
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var activeSitesCount: Int {
        siteSettings.filter { $0.isActive }.count
    }
    
    // MARK: - Actions
    
    private func toggleSiteActive(_ site: CurtainSiteSettings) {
        site.isActive.toggle()
        try? modelContext.save()
    }
    
    private func deleteSite(_ site: CurtainSiteSettings) {
        modelContext.delete(site)
        try? modelContext.save()
    }
}

// MARK: - Supporting Views

struct HeaderInfoView: View {
    let totalSites: Int
    let activeSites: Int
    
    var body: some View {
        HStack(spacing: 20) {
            InfoCard(title: "Total Sites", value: "\(totalSites)", color: .blue)
            InfoCard(title: "Active Sites", value: "\(activeSites)", color: .green)
            Spacer()
        }
    }
}

struct InfoCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct SitesEmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "server.rack")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No API Sites Configured")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Add your first API site to start downloading proteomics data")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SitesList: View {
    let sites: [CurtainSiteSettings]
    let onToggleActive: (CurtainSiteSettings) -> Void
    let onEdit: (CurtainSiteSettings) -> Void
    let onDelete: (CurtainSiteSettings) -> Void
    
    var body: some View {
        List {
            ForEach(sites, id: \.id) { site in
                SiteRowView(
                    site: site,
                    onToggleActive: { onToggleActive(site) },
                    onEdit: { onEdit(site) },
                    onDelete: { onDelete(site) }
                )
            }
        }
    }
}

struct SiteRowView: View {
    let site: CurtainSiteSettings
    let onToggleActive: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(site.hostname)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if !site.description.isEmpty {
                        Text(site.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    HStack(spacing: 12) {
                        StatusBadge(isActive: site.isActive)
                        
                        if site.requiresAuthentication {
                            Label("Auth Required", systemImage: "key.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        Label("Added \(site.createdAt, format: .dateTime.month().day())", systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { site.isActive },
                    set: { _ in onToggleActive() }
                ))
                .labelsHidden()
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button("Edit", action: onEdit)
            Button("Toggle Active", action: onToggleActive)
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Edit", action: onEdit)
        }
    }
}

struct StatusBadge: View {
    let isActive: Bool
    
    var body: some View {
        Label(isActive ? "Active" : "Inactive", systemImage: isActive ? "checkmark.circle.fill" : "xmark.circle.fill")
            .font(.caption)
            .foregroundColor(isActive ? .green : .red)
    }
}

// MARK: - Sheet Views

struct AddSiteSheet: View {
    @Environment(\.dismiss) private var dismiss
    let modelContext: ModelContext
    
    @State private var hostname = ""
    @State private var description = ""
    @State private var apiKey = ""
    @State private var isActive = true
    @State private var requiresAuth = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Site Information") {
                    HStack {
                        TextField("Hostname (e.g., curtain-web.org)", text: $hostname)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                        
                        Menu("Common") {
                            ForEach(CurtainConstants.commonHostnames, id: \.self) { host in
                                Button(host) {
                                    hostname = host
                                }
                            }
                        }
                        .font(.caption)
                    }
                    
                    TextField("Description (Optional)", text: $description)
                }
                
                Section("Authentication") {
                    Toggle("Requires API Key", isOn: $requiresAuth)
                    
                    if requiresAuth {
                        SecureField("API Key", text: $apiKey)
                    }
                }
                
                Section("Settings") {
                    Toggle("Active", isOn: $isActive)
                }
            }
            .navigationTitle("Add API Site")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addSite()
                        dismiss()
                    }
                    .disabled(hostname.isEmpty)
                }
            }
        }
    }
    
    private func addSite() {
        let newSite = CurtainSiteSettings(
            hostname: hostname.trimmingCharacters(in: .whitespacesAndNewlines),
            active: isActive,
            apiKey: requiresAuth && !apiKey.isEmpty ? apiKey : nil,
            siteDescription: description.isEmpty ? nil : description,
            requiresAuthentication: requiresAuth
        )
        
        modelContext.insert(newSite)
        try? modelContext.save()
    }
}

struct EditSiteSheet: View {
    @Environment(\.dismiss) private var dismiss
    let site: CurtainSiteSettings
    let modelContext: ModelContext
    
    @State private var hostname: String
    @State private var description: String
    @State private var apiKey: String
    @State private var isActive: Bool
    @State private var requiresAuth: Bool
    
    init(site: CurtainSiteSettings, modelContext: ModelContext) {
        self.site = site
        self.modelContext = modelContext
        
        _hostname = State(initialValue: site.hostname)
        _description = State(initialValue: site.description)
        _apiKey = State(initialValue: site.apiKey ?? "")
        _isActive = State(initialValue: site.isActive)
        _requiresAuth = State(initialValue: site.requiresAuthentication)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Site Information") {
                    HStack {
                        TextField("Hostname", text: $hostname)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                        
                        Menu("Common") {
                            ForEach(CurtainConstants.commonHostnames, id: \.self) { host in
                                Button(host) {
                                    hostname = host
                                }
                            }
                        }
                        .font(.caption)
                    }
                    
                    TextField("Description (Optional)", text: $description)
                }
                
                Section("Authentication") {
                    Toggle("Requires API Key", isOn: $requiresAuth)
                    
                    if requiresAuth {
                        SecureField("API Key", text: $apiKey)
                    }
                }
                
                Section("Settings") {
                    Toggle("Active", isOn: $isActive)
                }
            }
            .navigationTitle("Edit Site")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSite()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveSite() {
        site.hostname = hostname.trimmingCharacters(in: .whitespacesAndNewlines)
        site.description = description
        site.apiKey = requiresAuth && !apiKey.isEmpty ? apiKey : nil
        site.isActive = isActive
        site.requiresAuthentication = requiresAuth
        
        try? modelContext.save()
    }
}

#Preview {
    SiteSettingsView()
        .modelContainer(for: CurtainSiteSettings.self, inMemory: true)
}