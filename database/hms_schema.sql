/* ============================================================
   HMS SQL Server Schema (Single Hospital, MRN Per Year)
   MRN format: HN-YYYY-00001
   No VAT
   Bill master only for inpatients
   ============================================================ */

CREATE TABLE sec_users (
    user_id           BIGINT IDENTITY(1,1) PRIMARY KEY,
    username          NVARCHAR(100) UNIQUE NOT NULL,
    password_hash     NVARCHAR(255) NOT NULL,
    full_name         NVARCHAR(150) NOT NULL,
    phone             NVARCHAR(20),
    email             NVARCHAR(150),
    is_active         BIT NOT NULL DEFAULT 1,
    created_at        DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE sec_roles (
    role_id           INT IDENTITY(1,1) PRIMARY KEY,
    role_name         NVARCHAR(100) UNIQUE NOT NULL
);

CREATE TABLE sec_permissions (
    permission_id     INT IDENTITY(1,1) PRIMARY KEY,
    permission_name   NVARCHAR(150) UNIQUE NOT NULL
);

CREATE TABLE sec_user_roles (
    user_id           BIGINT NOT NULL,
    role_id           INT NOT NULL,
    PRIMARY KEY (user_id, role_id),
    FOREIGN KEY (user_id) REFERENCES sec_users(user_id),
    FOREIGN KEY (role_id) REFERENCES sec_roles(role_id)
);

CREATE TABLE sec_role_permissions (
    role_id           INT NOT NULL,
    permission_id     INT NOT NULL,
    PRIMARY KEY (role_id, permission_id),
    FOREIGN KEY (role_id) REFERENCES sec_roles(role_id),
    FOREIGN KEY (permission_id) REFERENCES sec_permissions(permission_id)
);

CREATE TABLE sec_digital_certificates (
    cert_id           BIGINT IDENTITY(1,1) PRIMARY KEY,
    user_id           BIGINT NOT NULL,
    certificate_ref   NVARCHAR(255) NOT NULL,
    issued_at         DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    expires_at        DATETIME2 NULL,
    FOREIGN KEY (user_id) REFERENCES sec_users(user_id)
);

CREATE TABLE mst_departments (
    department_id     INT IDENTITY(1,1) PRIMARY KEY,
    department_name   NVARCHAR(150) UNIQUE NOT NULL
);

CREATE TABLE mst_doctors (
    doctor_id         BIGINT IDENTITY(1,1) PRIMARY KEY,
    user_id           BIGINT NOT NULL,
    department_id     INT NOT NULL,
    registration_no   NVARCHAR(50),
    FOREIGN KEY (user_id) REFERENCES sec_users(user_id),
    FOREIGN KEY (department_id) REFERENCES mst_departments(department_id)
);

CREATE TABLE mst_wards (
    ward_id           INT IDENTITY(1,1) PRIMARY KEY,
    ward_name         NVARCHAR(150) NOT NULL,
    ward_type         NVARCHAR(50) NOT NULL
);

CREATE TABLE mst_beds (
    bed_id            INT IDENTITY(1,1) PRIMARY KEY,
    ward_id           INT NOT NULL,
    bed_no            NVARCHAR(30) NOT NULL,
    is_active         BIT NOT NULL DEFAULT 1,
    FOREIGN KEY (ward_id) REFERENCES mst_wards(ward_id)
);

CREATE TABLE mst_services (
    service_id        INT IDENTITY(1,1) PRIMARY KEY,
    service_name      NVARCHAR(200) NOT NULL,
    service_type      NVARCHAR(50) NOT NULL
);

CREATE TABLE mst_price_list (
    price_id          INT IDENTITY(1,1) PRIMARY KEY,
    service_id        INT NOT NULL,
    price             DECIMAL(18,2) NOT NULL,
    is_active         BIT NOT NULL DEFAULT 1,
    FOREIGN KEY (service_id) REFERENCES mst_services(service_id)
);

CREATE TABLE trx_patients (
    patient_id        BIGINT IDENTITY(1,1) PRIMARY KEY,
    mrn               NVARCHAR(20) UNIQUE NOT NULL,
    full_name         NVARCHAR(150) NOT NULL,
    gender            NVARCHAR(10),
    dob               DATE,
    phone             NVARCHAR(20),
    email             NVARCHAR(150),
    address           NVARCHAR(300),
    created_at        DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE trx_mrn_counter (
    mrn_year          INT PRIMARY KEY,
    last_number       INT NOT NULL DEFAULT 0
);

GO
CREATE PROCEDURE usp_generate_mrn
    @mrn_output NVARCHAR(20) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @year INT = YEAR(GETDATE());
    DECLARE @next INT;

    IF NOT EXISTS (SELECT 1 FROM trx_mrn_counter WHERE mrn_year = @year)
        INSERT INTO trx_mrn_counter (mrn_year, last_number) VALUES (@year, 0);

    UPDATE trx_mrn_counter
       SET last_number = last_number + 1
     WHERE mrn_year = @year;

    SELECT @next = last_number
      FROM trx_mrn_counter
     WHERE mrn_year = @year;

    SET @mrn_output = CONCAT('HN-', @year, '-', RIGHT('00000' + CAST(@next AS NVARCHAR(5)), 5));
END
GO

CREATE TABLE trx_appointments (
    appointment_id    BIGINT IDENTITY(1,1) PRIMARY KEY,
    patient_id        BIGINT NOT NULL,
    doctor_id         BIGINT NOT NULL,
    department_id     INT NOT NULL,
    appointment_time  DATETIME2 NOT NULL,
    status            NVARCHAR(20) NOT NULL,
    payment_status    NVARCHAR(20) NOT NULL,
    created_at        DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    FOREIGN KEY (patient_id) REFERENCES trx_patients(patient_id),
    FOREIGN KEY (doctor_id) REFERENCES mst_doctors(doctor_id),
    FOREIGN KEY (department_id) REFERENCES mst_departments(department_id),
    CHECK (status IN ('BOOKED','ARRIVED','COMPLETED','CANCELLED')),
    CHECK (payment_status IN ('PAID','PENDING','FAILED'))
);

CREATE TABLE doc_opd_vitals (
    vitals_id         BIGINT IDENTITY(1,1) PRIMARY KEY,
    appointment_id    BIGINT NOT NULL,
    bp                NVARCHAR(20),
    temperature       DECIMAL(5,2),
    weight            DECIMAL(6,2),
    pulse             INT,
    created_by        BIGINT NOT NULL,
    created_at        DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    FOREIGN KEY (appointment_id) REFERENCES trx_appointments(appointment_id),
    FOREIGN KEY (created_by) REFERENCES sec_users(user_id)
);

CREATE TABLE doc_opd_consultations (
    consultation_id   BIGINT IDENTITY(1,1) PRIMARY KEY,
    appointment_id    BIGINT NOT NULL,
    symptoms          NVARCHAR(MAX),
    diagnosis         NVARCHAR(MAX),
    treatment_plan    NVARCHAR(MAX),
    created_by        BIGINT NOT NULL,
    signed_by         BIGINT NULL,
    signed_at         DATETIME2 NULL,
    FOREIGN KEY (appointment_id) REFERENCES trx_appointments(appointment_id),
    FOREIGN KEY (created_by) REFERENCES sec_users(user_id),
    FOREIGN KEY (signed_by) REFERENCES sec_users(user_id)
);

CREATE TABLE doc_prescriptions (
    prescription_id   BIGINT IDENTITY(1,1) PRIMARY KEY,
    consultation_id   BIGINT NOT NULL,
    created_by        BIGINT NOT NULL,
    signed_by         BIGINT NULL,
    signed_at         DATETIME2 NULL,
    status            NVARCHAR(20) NOT NULL DEFAULT 'PENDING',
    FOREIGN KEY (consultation_id) REFERENCES doc_opd_consultations(consultation_id),
    FOREIGN KEY (created_by) REFERENCES sec_users(user_id),
    FOREIGN KEY (signed_by) REFERENCES sec_users(user_id),
    CHECK (status IN ('PENDING','DISPENSED','CANCELLED'))
);

CREATE TABLE doc_prescription_items (
    item_id           BIGINT IDENTITY(1,1) PRIMARY KEY,
    prescription_id   BIGINT NOT NULL,
    medicine_name     NVARCHAR(200) NOT NULL,
    dosage            NVARCHAR(100),
    duration_days     INT,
    frequency         NVARCHAR(50),
    FOREIGN KEY (prescription_id) REFERENCES doc_prescriptions(prescription_id)
);

CREATE TABLE doc_investigation_orders (
    order_id          BIGINT IDENTITY(1,1) PRIMARY KEY,
    consultation_id   BIGINT NOT NULL,
    created_by        BIGINT NOT NULL,
    status            NVARCHAR(20) NOT NULL DEFAULT 'ORDERED',
    FOREIGN KEY (consultation_id) REFERENCES doc_opd_consultations(consultation_id),
    FOREIGN KEY (created_by) REFERENCES sec_users(user_id),
    CHECK (status IN ('ORDERED','PAID','SENT_TO_LAB','COMPLETED'))
);

CREATE TABLE doc_investigation_order_items (
    order_item_id     BIGINT IDENTITY(1,1) PRIMARY KEY,
    order_id          BIGINT NOT NULL,
    test_name         NVARCHAR(200) NOT NULL,
    sample_type       NVARCHAR(100),
    FOREIGN KEY (order_id) REFERENCES doc_investigation_orders(order_id)
);

CREATE TABLE doc_emergency_cards (
    emergency_id      BIGINT IDENTITY(1,1) PRIMARY KEY,
    patient_id        BIGINT NULL,
    complaint         NVARCHAR(MAX),
    triage_notes      NVARCHAR(MAX),
    vitals            NVARCHAR(MAX),
    provisional_diag  NVARCHAR(MAX),
    created_by        BIGINT NOT NULL,
    signed_by         BIGINT NULL,
    signed_at         DATETIME2 NULL,
    created_at        DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    FOREIGN KEY (patient_id) REFERENCES trx_patients(patient_id),
    FOREIGN KEY (created_by) REFERENCES sec_users(user_id),
    FOREIGN KEY (signed_by) REFERENCES sec_users(user_id)
);

CREATE TABLE trx_admissions (
    admission_id      BIGINT IDENTITY(1,1) PRIMARY KEY,
    patient_id        BIGINT NOT NULL,
    admission_date    DATETIME2 NOT NULL,
    admission_source  NVARCHAR(20) NOT NULL,
    attending_doctor  BIGINT NOT NULL,
    status            NVARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    FOREIGN KEY (patient_id) REFERENCES trx_patients(patient_id),
    FOREIGN KEY (attending_doctor) REFERENCES mst_doctors(doctor_id),
    CHECK (admission_source IN ('EMERGENCY','OPD')),
    CHECK (status IN ('ACTIVE','DISCHARGED','TRANSFERRED'))
);

CREATE TABLE trx_bed_allocations (
    allocation_id     BIGINT IDENTITY(1,1) PRIMARY KEY,
    admission_id      BIGINT NOT NULL,
    bed_id            INT NOT NULL,
    allocated_at      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    released_at       DATETIME2 NULL,
    FOREIGN KEY (admission_id) REFERENCES trx_admissions(admission_id),
    FOREIGN KEY (bed_id) REFERENCES mst_beds(bed_id)
);

CREATE TABLE doc_nursing_notes (
    note_id           BIGINT IDENTITY(1,1) PRIMARY KEY,
    admission_id      BIGINT NOT NULL,
    note_text         NVARCHAR(MAX),
    created_by        BIGINT NOT NULL,
    created_at        DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    FOREIGN KEY (admission_id) REFERENCES trx_admissions(admission_id),
    FOREIGN KEY (created_by) REFERENCES sec_users(user_id)
);

CREATE TABLE lab_requests (
    lab_request_id    BIGINT IDENTITY(1,1) PRIMARY KEY,
    order_id          BIGINT NOT NULL,
    status            NVARCHAR(20) NOT NULL DEFAULT 'RECEIVED',
    FOREIGN KEY (order_id) REFERENCES doc_investigation_orders(order_id),
    CHECK (status IN ('RECEIVED','SAMPLE_COLLECTED','RESULT_ENTERED','APPROVED'))
);

CREATE TABLE lab_samples (
    sample_id         BIGINT IDENTITY(1,1) PRIMARY KEY,
    lab_request_id    BIGINT NOT NULL,
    collected_at      DATETIME2 NOT NULL,
    collected_by      BIGINT NOT NULL,
    FOREIGN KEY (lab_request_id) REFERENCES lab_requests(lab_request_id),
    FOREIGN KEY (collected_by) REFERENCES sec_users(user_id)
);

CREATE TABLE lab_results (
    result_id         BIGINT IDENTITY(1,1) PRIMARY KEY,
    lab_request_id    BIGINT NOT NULL,
    result_data       NVARCHAR(MAX),
    entered_by        BIGINT NOT NULL,
    entered_at        DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    FOREIGN KEY (lab_request_id) REFERENCES lab_requests(lab_request_id),
    FOREIGN KEY (entered_by) REFERENCES sec_users(user_id)
);

CREATE TABLE lab_reports (
    report_id         BIGINT IDENTITY(1,1) PRIMARY KEY,
    lab_request_id    BIGINT NOT NULL,
    report_path       NVARCHAR(300) NOT NULL,
    approved_by       BIGINT NOT NULL,
    approved_at       DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    FOREIGN KEY (lab_request_id) REFERENCES lab_requests(lab_request_id),
    FOREIGN KEY (approved_by) REFERENCES sec_users(user_id)
);

CREATE TABLE inv_items (
    item_id           BIGINT IDENTITY(1,1) PRIMARY KEY,
    item_name         NVARCHAR(200) NOT NULL,
    is_narcotic       BIT NOT NULL DEFAULT 0,
    reorder_level     INT NOT NULL DEFAULT 0
);

CREATE TABLE inv_batches (
    batch_id          BIGINT IDENTITY(1,1) PRIMARY KEY,
    item_id           BIGINT NOT NULL,
    batch_no          NVARCHAR(100) NOT NULL,
    expiry_date       DATE NOT NULL,
    qty_available     INT NOT NULL,
    FOREIGN KEY (item_id) REFERENCES inv_items(item_id)
);

CREATE TABLE pharm_dispenses (
    dispense_id       BIGINT IDENTITY(1,1) PRIMARY KEY,
    prescription_id   BIGINT NOT NULL,
    dispensed_by      BIGINT NOT NULL,
    dispensed_at      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    FOREIGN KEY (prescription_id) REFERENCES doc_prescriptions(prescription_id),
    FOREIGN KEY (dispensed_by) REFERENCES sec_users(user_id)
);

CREATE TABLE pharm_dispense_items (
    dispense_item_id  BIGINT IDENTITY(1,1) PRIMARY KEY,
    dispense_id       BIGINT NOT NULL,
    batch_id          BIGINT NOT NULL,
    quantity          INT NOT NULL,
    FOREIGN KEY (dispense_id) REFERENCES pharm_dispenses(dispense_id),
    FOREIGN KEY (batch_id) REFERENCES inv_batches(batch_id)
);

CREATE TABLE pharm_narcotics_log (
    narc_log_id       BIGINT IDENTITY(1,1) PRIMARY KEY,
    dispense_id       BIGINT NOT NULL,
    approved_by       BIGINT NOT NULL,
    approved_at       DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    FOREIGN KEY (dispense_id) REFERENCES pharm_dispenses(dispense_id),
    FOREIGN KEY (approved_by) REFERENCES sec_users(user_id)
);

CREATE TABLE ot_schedules (
    ot_schedule_id    BIGINT IDENTITY(1,1) PRIMARY KEY,
    admission_id      BIGINT NOT NULL,
    scheduled_at      DATETIME2 NOT NULL,
    surgeon_id        BIGINT NOT NULL,
    anesthetist_id    BIGINT NOT NULL,
    status            NVARCHAR(20) NOT NULL DEFAULT 'SCHEDULED',
    FOREIGN KEY (admission_id) REFERENCES trx_admissions(admission_id),
    FOREIGN KEY (surgeon_id) REFERENCES mst_doctors(doctor_id),
    FOREIGN KEY (anesthetist_id) REFERENCES mst_doctors(doctor_id),
    CHECK (status IN ('SCHEDULED','IN_PROGRESS','COMPLETED','CANCELLED'))
);

CREATE TABLE ot_intraop_notes (
    ot_note_id        BIGINT IDENTITY(1,1) PRIMARY KEY,
    ot_schedule_id    BIGINT NOT NULL,
    note_text         NVARCHAR(MAX),
    created_by        BIGINT NOT NULL,
    created_at        DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    FOREIGN KEY (ot_schedule_id) REFERENCES ot_schedules(ot_schedule_id),
    FOREIGN KEY (created_by) REFERENCES sec_users(user_id)
);

CREATE TABLE cath_schedules (
    cath_schedule_id  BIGINT IDENTITY(1,1) PRIMARY KEY,
    admission_id      BIGINT NOT NULL,
    scheduled_at      DATETIME2 NOT NULL,
    cardiologist_id   BIGINT NOT NULL,
    status            NVARCHAR(20) NOT NULL DEFAULT 'SCHEDULED',
    FOREIGN KEY (admission_id) REFERENCES trx_admissions(admission_id),
    FOREIGN KEY (cardiologist_id) REFERENCES mst_doctors(doctor_id),
    CHECK (status IN ('SCHEDULED','IN_PROGRESS','COMPLETED','CANCELLED'))
);

CREATE TABLE fin_bill_master (
    bill_id           BIGINT IDENTITY(1,1) PRIMARY KEY,
    admission_id      BIGINT NOT NULL UNIQUE,
    total_amount      DECIMAL(18,2) NOT NULL DEFAULT 0,
    paid_amount       DECIMAL(18,2) NOT NULL DEFAULT 0,
    status            NVARCHAR(20) NOT NULL DEFAULT 'OPEN',
    created_at        DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    FOREIGN KEY (admission_id) REFERENCES trx_admissions(admission_id),
    CHECK (status IN ('OPEN','CLOSED','CANCELLED'))
);

CREATE TABLE fin_bill_items (
    bill_item_id      BIGINT IDENTITY(1,1) PRIMARY KEY,
    bill_id           BIGINT NOT NULL,
    service_name      NVARCHAR(200) NOT NULL,
    amount            DECIMAL(18,2) NOT NULL,
    created_at        DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    FOREIGN KEY (bill_id) REFERENCES fin_bill_master(bill_id)
);

CREATE TABLE fin_payments (
    payment_id        BIGINT IDENTITY(1,1) PRIMARY KEY,
    bill_id           BIGINT NOT NULL,
    payment_mode      NVARCHAR(20) NOT NULL,
    amount            DECIMAL(18,2) NOT NULL,
    paid_at           DATETIME2 NOT NULL DEFAULT SYSUTCDATCDATE(),
    FOREIGN KEY (bill_id) REFERENCES fin_bill_master(bill_id),
    CHECK (payment_mode IN ('CASH','CARD','ONLINE','INSURANCE'))
);

CREATE TABLE sec_audit_log (
    audit_id          BIGINT IDENTITY(1,1) PRIMARY KEY,
    user_id           BIGINT NOT NULL,
    action_type       NVARCHAR(50) NOT NULL,
    table_name        NVARCHAR(100) NOT NULL,
    record_id         NVARCHAR(100) NOT NULL,
    old_value         NVARCHAR(MAX),
    new_value         NVARCHAR(MAX),
    created_at        DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    FOREIGN KEY (user_id) REFERENCES sec_users(user_id)
);