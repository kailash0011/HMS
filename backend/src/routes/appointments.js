const express = require("express");
const { getPool, sql } = require("../db");
const auth = require("../middleware/auth");

const router = express.Router();

router.post("/", auth, async (req, res) => {
  try {
    const { patient_id, doctor_id, department_id, appointment_time } = req.body;
    if (!patient_id || !doctor_id || !department_id || !appointment_time) {
      return res.status(400).json({ error: "patient_id, doctor_id, department_id, and appointment_time are required" });
    }

    const pool = await getPool();
    const insert = await pool
      .request()
      .input("patient_id", sql.BigInt, patient_id)
      .input("doctor_id", sql.BigInt, doctor_id)
      .input("department_id", sql.Int, department_id)
      .input("appointment_time", sql.DateTime2, appointment_time)
      .query("INSERT INTO trx_appointments (patient_id, doctor_id, department_id, appointment_time, status, payment_status) OUTPUT INSERTED.appointment_id VALUES (@patient_id, @doctor_id, @department_id, @appointment_time, 'BOOKED', 'PENDING')");

    return res.status(201).json(insert.recordset[0]);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

router.get("/", auth, async (_req, res) => {
  try {
    const pool = await getPool();
    const result = await pool
      .request()
      .query("SELECT TOP 100 appointment_id, patient_id, doctor_id, department_id, appointment_time, status, payment_status, created_at FROM trx_appointments ORDER BY created_at DESC");

    return res.json(result.recordset);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

module.exports = router;