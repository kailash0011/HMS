# HMS (Hospital Management System)

This repository contains a full-stack starter HMS built with:
- **Backend:** Node.js + Express + SQL Server
- **Auth:** JWT + bcrypt
- **Frontend:** HTML + Bootstrap 5
- **Database:** SQL Server schema for inpatient billing, OPD, lab, pharmacy, OT, emergency, and admin

## Project Structure
```
backend/
  src/
    routes/
    middleware/
    db.js
    server.js
  package.json
  .env.example
frontend/
  index.html
  login.html
  dashboard.html
  opd-vitals.html
  opd-consultation.html
database/
  hms_schema.sql
```

## Setup

### 1) Database
Create a SQL Server database named `hmsdb` and run:
```
/database/hms_schema.sql
```

### 2) Backend
```
cd backend
npm install
cp .env.example .env
npm run dev
```

### 3) Frontend
Open `frontend/index.html` in your browser.

## Notes
- MRN format is **HN-YYYY-00001** and resets per year.
- Billing is only for **inpatients**.
- VAT is not used.