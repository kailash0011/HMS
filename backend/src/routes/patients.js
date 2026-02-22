const express = require("express");
const { getPool, sql } = require("../db");
const auth = require("../middleware/auth");

const router = express.Router();

router.post("/", auth, async (req, res) => {
  try {
    const { full_name, gender, dob, phone, email, address } = req.body;
    if (!full_name) {
      return res.status(400).json({ error: "full_name is required" });
    }

    const pool = await getPool();
    const mrnResult = await pool.request().execute("usp_generate_mrn");
    const mrn = mrnResult.output?.mrn_output || mrnResult.recordset?.[0]?.mrn_output;

    const insert = await pool
      .request()
      .input("mrn", sql.NVarChar(20), mrn)
      .input("full_name", sql.NVarChar(150), full_name)
      .input("gender", sql.NVarChar(10), gender || null)
      .input("dob", sql.Date, dob || null)
      .input("phone", sql.NVarChar(20), phone || null)
      .input("email", sql.NVarChar(150), email || null)
      .input("address", sql.NVarChar(300), address || null)
      .query("INSERT INTO trx_patients (mrn, full_name, gender, dob, phone, email, address) OUTPUT INSERTED.patient_id, INSERTED.mrn VALUES (@mrn, @full_name, @gender, @dob, @phone, @email, @address)");

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
      .query("SELECT TOP 100 patient_id, mrn, full_name, gender, dob, phone, email, address, created_at FROM trx_patients ORDER BY created_at DESC");

    return res.json(result.recordset);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

module.exports = router;