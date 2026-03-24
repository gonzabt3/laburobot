import React, { useState } from "react";

const AdminDashboard = ({ stats, providers, reports }) => {
  const [activeTab, setActiveTab] = useState("dashboard");
  const [providerList, setProviderList] = useState(providers || []);
  const [message, setMessage] = useState(null);

  const toggleProvider = async (id) => {
    try {
      const response = await fetch(`/admin/provider_profiles/${id}/toggle_active`, {
        method: "PATCH",
        headers: {
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
          "Content-Type": "application/json",
        },
      });
      if (response.ok) {
        setProviderList((prev) =>
          prev.map((p) => (p.id === id ? { ...p, active: !p.active } : p))
        );
        setMessage("Provider updated successfully.");
        setTimeout(() => setMessage(null), 3000);
      }
    } catch (err) {
      setMessage("Error updating provider.");
    }
  };

  const updateReport = async (id, status) => {
    try {
      await fetch(`/admin/reports/${id}`, {
        method: "PATCH",
        headers: {
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ status }),
      });
      setMessage("Report updated.");
      setTimeout(() => setMessage(null), 3000);
    } catch (err) {
      setMessage("Error updating report.");
    }
  };

  return (
    <div style={{ fontFamily: "sans-serif", maxWidth: 1100, margin: "0 auto", padding: 24 }}>
      <h1 style={{ borderBottom: "2px solid #333", paddingBottom: 8 }}>
        🤖 LaburoBot Admin
      </h1>

      {message && (
        <div style={{ background: "#d4edda", border: "1px solid #c3e6cb", padding: 12, borderRadius: 4, marginBottom: 16 }}>
          {message}
        </div>
      )}

      <nav style={{ marginBottom: 24 }}>
        {["dashboard", "providers", "reports"].map((tab) => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            style={{
              marginRight: 8,
              padding: "8px 16px",
              background: activeTab === tab ? "#333" : "#eee",
              color: activeTab === tab ? "#fff" : "#333",
              border: "none",
              borderRadius: 4,
              cursor: "pointer",
              textTransform: "capitalize",
            }}
          >
            {tab}
          </button>
        ))}
      </nav>

      {activeTab === "dashboard" && <StatsDashboard stats={stats} />}
      {activeTab === "providers" && (
        <ProviderTable providers={providerList} onToggle={toggleProvider} />
      )}
      {activeTab === "reports" && (
        <ReportsTable reports={reports || []} onUpdate={updateReport} />
      )}
    </div>
  );
};

const StatsDashboard = ({ stats = {} }) => (
  <div>
    <h2>Overview</h2>
    <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 16 }}>
      {[
        { label: "Total Users", value: stats.total_users ?? 0 },
        { label: "Providers", value: stats.total_providers ?? 0 },
        { label: "Clients", value: stats.total_clients ?? 0 },
        { label: "Service Requests", value: stats.total_service_requests ?? 0 },
        { label: "Total Leads", value: stats.total_leads ?? 0 },
        { label: "Leads Today", value: stats.leads_today ?? 0 },
        { label: "Open Reports", value: stats.open_reports ?? 0, warn: (stats.open_reports ?? 0) > 0 },
      ].map(({ label, value, warn }) => (
        <div
          key={label}
          style={{
            background: warn ? "#fff3cd" : "#f8f9fa",
            border: "1px solid " + (warn ? "#ffc107" : "#dee2e6"),
            borderRadius: 8,
            padding: 16,
            textAlign: "center",
          }}
        >
          <div style={{ fontSize: 32, fontWeight: "bold" }}>{value}</div>
          <div style={{ fontSize: 13, color: "#666" }}>{label}</div>
        </div>
      ))}
    </div>
  </div>
);

const ProviderTable = ({ providers, onToggle }) => (
  <div>
    <h2>Provider Profiles ({providers.length})</h2>
    {providers.length === 0 ? (
      <p style={{ color: "#666" }}>No providers registered yet.</p>
    ) : (
      <table style={{ width: "100%", borderCollapse: "collapse" }}>
        <thead>
          <tr style={{ background: "#f8f9fa" }}>
            <th style={thStyle}>Phone</th>
            <th style={thStyle}>Categories</th>
            <th style={thStyle}>Service Area</th>
            <th style={thStyle}>Status</th>
            <th style={thStyle}>Actions</th>
          </tr>
        </thead>
        <tbody>
          {providers.map((p) => (
            <tr key={p.id} style={{ borderBottom: "1px solid #dee2e6" }}>
              <td style={tdStyle}>{p.user_phone || "—"}</td>
              <td style={tdStyle}>{p.categories || "—"}</td>
              <td style={tdStyle}>{p.service_area_type || "—"}</td>
              <td style={tdStyle}>
                <span
                  style={{
                    padding: "2px 8px",
                    borderRadius: 4,
                    background: p.active ? "#d4edda" : "#f8d7da",
                    color: p.active ? "#155724" : "#721c24",
                    fontSize: 12,
                  }}
                >
                  {p.active ? "Active" : "Inactive"}
                </span>
              </td>
              <td style={tdStyle}>
                <button
                  onClick={() => onToggle(p.id)}
                  style={{
                    padding: "4px 10px",
                    background: p.active ? "#dc3545" : "#28a745",
                    color: "#fff",
                    border: "none",
                    borderRadius: 4,
                    cursor: "pointer",
                    fontSize: 12,
                  }}
                >
                  {p.active ? "Deactivate" : "Activate"}
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    )}
  </div>
);

const ReportsTable = ({ reports, onUpdate }) => (
  <div>
    <h2>Reports ({reports.length})</h2>
    {reports.length === 0 ? (
      <p style={{ color: "#666" }}>No reports yet.</p>
    ) : (
      <table style={{ width: "100%", borderCollapse: "collapse" }}>
        <thead>
          <tr style={{ background: "#f8f9fa" }}>
            <th style={thStyle}>Reporter</th>
            <th style={thStyle}>Target</th>
            <th style={thStyle}>Reason</th>
            <th style={thStyle}>Status</th>
            <th style={thStyle}>Actions</th>
          </tr>
        </thead>
        <tbody>
          {reports.map((r) => (
            <tr key={r.id} style={{ borderBottom: "1px solid #dee2e6" }}>
              <td style={tdStyle}>{r.reporter_phone || "—"}</td>
              <td style={tdStyle}>{r.target_phone || "—"}</td>
              <td style={tdStyle}>{r.reason}</td>
              <td style={tdStyle}>{r.status}</td>
              <td style={tdStyle}>
                {r.status === "pending" && (
                  <>
                    <button onClick={() => onUpdate(r.id, "reviewed")} style={smallBtnStyle("#007bff")}>
                      Review
                    </button>
                    <button onClick={() => onUpdate(r.id, "dismissed")} style={smallBtnStyle("#6c757d")}>
                      Dismiss
                    </button>
                  </>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    )}
  </div>
);

const thStyle = { padding: "10px 12px", textAlign: "left", borderBottom: "2px solid #dee2e6", fontSize: 13 };
const tdStyle = { padding: "8px 12px", fontSize: 13 };
const smallBtnStyle = (bg) => ({
  marginRight: 4,
  padding: "3px 8px",
  background: bg,
  color: "#fff",
  border: "none",
  borderRadius: 4,
  cursor: "pointer",
  fontSize: 11,
});

export default AdminDashboard;
