import { useState } from "react";
import './App.css';

const BACKEND_URL = process.env.REACT_APP_BACKEND_URL;

function App() {
  const [employeeId, setEmployeeId] = useState("");
  const [startDate, setStartDate] = useState("");
  const [endDate, setEndDate] = useState("");
  const [reason, setReason] = useState("");
  const [leaveType, setLeaveType] = useState("Vacation");
  const [employeeLeaves, setEmployeeLeaves] = useState([]);
  const [allLeaves, setAllLeaves] = useState([]);
  const [viewMode, setViewMode] = useState("employee");
  const [searchId, setSearchId] = useState("");

  // Apply leave
  const applyLeave = async () => {
    if (!employeeId || !startDate || !endDate || !reason) return alert("Fill all fields!");
    const response = await fetch(`${BACKEND_URL}/leave/apply`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ employeeId, startDate, endDate, reason, leaveType }),
    });
    const data = await response.json();
    alert("Leave Applied!");
    setEmployeeLeaves([...employeeLeaves, data]);
    setReason(""); setStartDate(""); setEndDate("");
  };

  // Fetch leaves of an employee
  const fetchLeaves = async () => {
    if (!employeeId) return alert("Enter Employee ID to fetch leaves");
    try {
      const response = await fetch(`${BACKEND_URL}/leave/${employeeId}`);
      if (!response.ok) throw new Error("Failed to fetch leaves");
      const data = await response.json();
      setEmployeeLeaves(data);
    } catch (error) {
      console.error(error);
      alert("Error fetching leaves. Make sure backend is running.");
    }
  };

  // Fetch all leaves for manager
  // Fetch all leaves for manager (optionally by employee ID)
  const fetchAllLeaves = async (id = "") => {
    try {
      let url = `${BACKEND_URL}/leave`;
      if (id) url += `?employeeId=${id}`; // use query parameter
      const response = await fetch(url);
      if (!response.ok) throw new Error("Failed to fetch leaves");
      const data = await response.json();
      setAllLeaves(data);
    } catch (error) {
      console.error(error);
      alert("Error fetching leaves.");
    }
  };


  // Approve or Reject leave
  const updateLeaveStatus = async (id, action) => {
    const response = await fetch(`${BACKEND_URL}/leave/${id}/${action}`, { method: "PUT" });
    const updated = await response.json();
    setAllLeaves(allLeaves.map(l => (l.id === updated.id ? updated : l)));
    setEmployeeLeaves(employeeLeaves.map(l => (l.id === updated.id ? updated : l)));
  };

  return (
    <div className="container">
      <h1>Info-tech-sys HR portal-Employee Leave Management</h1>

      {/* Tabs */}
      <div className="tabs">
        <div className={`tab ${viewMode === 'employee' ? 'active' : ''}`} onClick={() => setViewMode('employee')}>Employee</div>
        <div className={`tab ${viewMode === 'manager' ? 'active' : ''}`} onClick={() => { setViewMode('manager'); fetchAllLeaves(); }}>Manager</div>
      </div>

      {/* Employee View */}
      {viewMode === "employee" && (
        <div>
          <h2>Apply Leave</h2>
          <div className="form-grid">
            <input placeholder="Employee ID" value={employeeId} onChange={(e) => setEmployeeId(e.target.value)} />
            <select value={leaveType} onChange={(e) => setLeaveType(e.target.value)}>
              <option>Vacation</option>
              <option>Sick</option>
              <option>Work from Home</option>
            </select>
            <input type="date" value={startDate} onChange={(e) => setStartDate(e.target.value)} />
            <input type="date" value={endDate} onChange={(e) => setEndDate(e.target.value)} />
            <input placeholder="Reason" value={reason} onChange={(e) => setReason(e.target.value)} className="reason-input" />
          </div>
          <div className="button-group">
            <button className="apply" onClick={applyLeave}>Apply Leave</button>
            <button className="view" onClick={fetchLeaves}>View My Leaves</button>
          </div>

          {employeeLeaves.length === 0 && <p>No leaves to display.</p>}
          {employeeLeaves.map((l) => (
            <div key={l.id} className="leave-card">
              <div>
                <p><strong>{l.leaveType}</strong> | {l.startDate} - {l.endDate}</p>
                <p>{l.reason}</p>
              </div>
              <span className={`badge ${l.status.toLowerCase()}`}>{l.status}</span>
            </div>
          ))}
        </div>
      )}

      {/* Manager View */}
      {viewMode === "manager" && (
        <div>
          <h2>Manager Panel</h2>
          <div className="manager-search">
            <input placeholder="Search by Employee ID" value={searchId} onChange={(e) => setSearchId(e.target.value)} />
            <button className="view" onClick={() => fetchAllLeaves(searchId)}>Search</button>
          </div>

          {allLeaves.length === 0 && <p>No leaves to display.</p>}
          {allLeaves.map((l) => (
            <div key={l.id} className="leave-card">
              <div>
                <p><strong>{l.leaveType}</strong> | Employee: {l.employeeId}</p>
                <p>{l.startDate} - {l.endDate} | {l.reason}</p>
              </div>
              <div className="button-group">
                <span className={`badge ${l.status.toLowerCase()}`}>{l.status}</span>
                {l.status === "Pending" && (
                  <>
                    <button className="approve" onClick={() => updateLeaveStatus(l.id, "approve")}>Approve</button>
                    <button className="reject" onClick={() => updateLeaveStatus(l.id, "reject")}>Reject</button>
                  </>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

export default App;
